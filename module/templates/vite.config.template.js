// vite.config.js
// https://vitejs.dev/config
import { globSync } from "glob"
import { resolve } from 'path'
import { defineConfig } from 'vite'

const __outputDir = '#{OUTPUT_DIR}#'
const __distDir = '#{DIST_DIR}#'

export default defineConfig({
  css: {
    preprocessorOptions: {
      scss: {
        silenceDeprecations: ['color-functions', 'global-builtin', 'import']
      },
    }
  },
  root: __outputDir,
  build: {
    emptyOutDir: true,
    chunkSizeWarningLimit: 600,
    outDir: __distDir,
    rollupOptions: {
      input: globSync([`${resolve(__outputDir)}/**/*.html`])
    }
  }
})