// vite.config.js
// https://vitejs.dev/config
import { resolve, dirname } from 'path'
import { defineConfig } from 'vite'

const __outputDir = '#{OUTPUT_DIR}#'
const __distDir = '#{DIST_DIR}#'

export default defineConfig({
  css: {
    preprocessorOptions: {
      scss: {
        silenceDeprecations: ['mixed-decls', 'color-functions', 'global-builtin', 'import']
      },
    }
  },
  root: __outputDir,
  build: {
    emptyOutDir: true,
    chunkSizeWarningLimit: 600,
    outDir: __distDir,
    rollupOptions: {
      input: {
        main: resolve(__outputDir, 'index.html'),
      },
    },
  },
})