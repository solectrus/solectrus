import { defineConfig } from 'vite';
import ViteRails from 'vite-plugin-rails';
import tailwindcss from '@tailwindcss/vite';
export default defineConfig(({ mode }) => ({
  plugins: [
    tailwindcss(),
    ViteRails({
      fullReload: {
        additionalPaths: [
          'config/routes.rb',
          'app/views/**/*',
          'app/components/**/*',
          'app/**/*.rb',
          'config/locales/**/*.yml',
        ],
      },
    }),
  ],
  build: {
    rolldownOptions: {
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
  server: {
    hmr: {
      host: 'vite.solectrus.localhost',
      clientPort: 443,
    },
  },
}));
