import { defineConfig } from 'vite';
import ViteRails from 'vite-plugin-rails';
import tailwindcss from '@tailwindcss/vite';
import { resolve } from 'path';

export default defineConfig({
  plugins: [
    tailwindcss(),
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
          if (id.includes('node_modules')) {
            return 'vendor';
          }
        },
      },
    },
    chunkSizeWarningLimit: 600,
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
