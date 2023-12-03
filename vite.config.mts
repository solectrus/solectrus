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
