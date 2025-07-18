// vite.config.js
// https://vitejs.dev/config
import multiInput from 'rollup-plugin-multi-input'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const __outputDir = '#{OUTPUT_DIR}#'
const __distDir = '#{DIST_DIR}#'

export default {
  root: resolve(__dirname, __outputDir),
  build: {
    emptyOutDir: true,
    chunkSizeWarningLimit: 600,
    outDir: resolve(__dirname, __distDir),
    rollupOptions: {
      input: resolve(__dirname, __outputDir, '**/*.html'),
      plugins: [multiInput()],
    },
  }
}