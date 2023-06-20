import { defineConfig, splitVendorChunkPlugin } from 'vite';
import ViteRails from 'vite-plugin-rails';
import { fileURLToPath, URL } from 'url';

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
      '@': fileURLToPath(new URL('./app/javascript/src', import.meta.url)),
    },
  },
  server: {
    hmr: {
      host: 'vite.solectrus.test',
      clientPort: 443,
    },
  },
});
