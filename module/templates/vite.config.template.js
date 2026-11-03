// vite.config.js
// https://vite.dev/config
import { createHash } from 'node:crypto'
import { readFileSync, statSync } from 'node:fs'
import { join, resolve, sep } from 'node:path'
import { globSync } from 'glob'
import { SAXParser } from 'parse5-sax-parser'
import { defineConfig } from 'vite'

const __outputDir = '#{OUTPUT_DIR}#'
const __distDir = '#{DIST_DIR}#'

/**
 * Appends a content-hash query string (?v=<hash>) to <script src> and <link href>
 * references that point at files in Vite's public directory.
 *
 * Vite copies public files verbatim and leaves their URLs unchanged, so a script
 * such as /js/main.js keeps the same URL across deployments. When those URLs are
 * served with a long-lived or immutable Cache-Control header, browsers and CDNs
 * keep the old file after a deployment. A content hash in the query string gives
 * each version of the file its own URL, without renaming the file on disk.
 *
 * The HTML is tokenized with parse5 (the WHATWG-compliant tokenizer), so only
 * real <script src> and <link href> attributes are changed, quoted or unquoted,
 * and the raw-text content of inline scripts, JSON-LD and styles is never
 * touched. References that Vite bundles itself, external and protocol-relative
 * URLs, and URLs that already carry a query string or fragment are left
 * unchanged. A <link rel="preload|modulepreload"> is versioned only when the same
 * document also loads that URL via a <script src>, so that preloads keep matching
 * files that are imported from JavaScript by their plain URL.
 */
function publicAssetVersioning() {
  let publicDir = null
  const hashes = new Map()
  const urlAttrByTag = { script: 'src', link: 'href' }

  const hashFor = (urlPath) => {
    if (hashes.has(urlPath)) return hashes.get(urlPath)
    let hash = null
    try {
      const filePath = join(publicDir, decodeURIComponent(urlPath))
      if (filePath.startsWith(publicDir + sep) && statSync(filePath).isFile()) {
        hash = createHash('sha256').update(readFileSync(filePath)).digest('hex').slice(0, 10)
      }
    } catch {
      // Not a public file: leave the reference unchanged.
    }
    hashes.set(urlPath, hash)
    return hash
  }

  const escapeAttr = (value) => value.replace(/&/g, '&amp;').replace(/"/g, '&quot;')

  const isPreload = (attrs) =>
    (attrs.find((a) => a.name === 'rel')?.value ?? '')
      .toLowerCase()
      .split(/\s+/)
      .some((rel) => rel === 'preload' || rel === 'modulepreload')

  const findEdits = (html) =>
    new Promise((resolvePromise, reject) => {
      const candidates = []
      const scriptUrls = new Set()
      const parser = new SAXParser({ sourceCodeLocationInfo: true })
      parser.on('startTag', ({ tagName, attrs, sourceCodeLocation }) => {
        const attrName = urlAttrByTag[tagName]
        if (!attrName) return
        const url = attrs.find((a) => a.name === attrName)?.value
        const location = sourceCodeLocation?.attrs?.[attrName]
        if (!url || !location || !/^\/(?!\/)[^?#]+$/.test(url)) return
        const hash = hashFor(url)
        if (!hash) return
        if (tagName === 'script') scriptUrls.add(url)
        candidates.push({
          url,
          // A preload only helps if its URL matches the eventual request exactly. When
          // the file is loaded by a <script src> in this document, that tag is versioned
          // too, so the preload must be. Otherwise the file is usually requested from
          // JavaScript (e.g. an import of /js/vendor/lib.mjs) by its plain URL, which
          // this plugin cannot rewrite, so the preload must stay unversioned to match.
          preload: tagName === 'link' && isPreload(attrs),
          start: location.startOffset,
          end: location.endOffset,
          text: `${attrName}="${escapeAttr(`${url}?v=${hash}`)}"`,
        })
      })
      parser.on('error', reject)
      parser.on('finish', () =>
        resolvePromise(candidates.filter((c) => !c.preload || scriptUrls.has(c.url)))
      )
      parser.resume() // discard the pass-through output so the stream never stalls
      parser.end(html)
    })

  return {
    name: 'zf-public-asset-versioning',
    apply: 'build',
    configResolved(config) {
      publicDir = config.publicDir ? resolve(config.publicDir) : null
    },
    transformIndexHtml: {
      order: 'post',
      async handler(html) {
        if (!publicDir) return html
        const edits = await findEdits(html)
        let result = html
        for (const { start, end, text } of edits.sort((a, b) => b.start - a.start)) {
          result = result.slice(0, start) + text + result.slice(end)
        }
        return result
      }
    }
  }
}

export default defineConfig({
  css: {
    preprocessorOptions: {
      scss: {
        silenceDeprecations: ['color-functions', 'global-builtin', 'import']
      },
    }
  },
  plugins: [publicAssetVersioning()],
  root: __outputDir,
  build: {
    emptyOutDir: true,
    chunkSizeWarningLimit: 600,
    outDir: __distDir,
    rolldownOptions: {
      input: globSync([`${resolve(__outputDir)}/**/*.html`])
    }
  }
})
