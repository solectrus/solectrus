import { defineConfig } from 'vite';
import ViteRails from 'vite-plugin-rails';
import tailwindcss from '@tailwindcss/vite';
import { resolve } from 'path';

export default defineConfig(({ mode }) => ({
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
      // Exclude sinon from production builds
      external: mode === 'production' ? ['sinon'] : [],
      output: {
        manualChunks(id: string) {
          if (id.includes('node_modules') && !id.includes('/sinon/')) {
            return 'vendor';
          }
        },
      },
    },
    chunkSizeWarningLimit: 620,
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
}));
