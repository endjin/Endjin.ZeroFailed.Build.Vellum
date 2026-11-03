// vite.config.js
// https://vite.dev/config
import { createHash } from 'node:crypto'
import { readFileSync, statSync } from 'node:fs'
import { join, resolve, sep } from 'node:path'
import { globSync } from 'glob'
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
 * References that Vite bundles itself, external URLs and URLs that already carry
 * a query string or fragment are left unchanged.
 */
function publicAssetVersioning() {
  let publicDir = null
  const hashes = new Map()

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

  const tagPattern = /<(?:script|link)\b[^>]*>/gi
  const urlAttrPattern = /(\s(?:src|href)\s*=\s*)(["'])(\/(?!\/)[^"'?#]+)\2/i

  return {
    name: 'zf-public-asset-versioning',
    apply: 'build',
    configResolved(config) {
      publicDir = config.publicDir ? resolve(config.publicDir) : null
    },
    transformIndexHtml: {
      order: 'post',
      handler(html) {
        if (!publicDir) return html
        return html.replace(tagPattern, (tag) =>
          tag.replace(urlAttrPattern, (match, attr, quote, urlPath) => {
            const hash = hashFor(urlPath)
            return hash ? `${attr}${quote}${urlPath}?v=${hash}${quote}` : match
          })
        )
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
