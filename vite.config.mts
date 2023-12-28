import { defineConfig, splitVendorChunkPlugin } from 'vite';
import ViteRails from 'vite-plugin-rails';
import { resolve } from 'path';

export default defineConfig({
  plugins: [
    splitVendorChunkPlugin(),
    ViteRails({
      fullReload: {
        additionalPaths: [
          'config/routes.rb',
          'app/views/**/*',
          'app/components/**/*',
          'config/locales/**/*.yml',
        ],
      },
    }),
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id: string) {
          // creating a chunk to chart.js deps. Reducing the vendor chunk size
          if (id.includes('chart') || id.includes('date-fns')) {
            return 'chart';
          }
        },
      },
    },
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, 'app/javascript'),
    },
  },
  server: {
    hmr: {
      host: 'vite.solectrus.test',
      clientPort: 443,
    },
  },
});
