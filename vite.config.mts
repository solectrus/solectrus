import { defineConfig } from 'vite';
import RailsVite from 'rails-vite-plugin';
import tailwindcss from '@tailwindcss/vite';
import manifestSRI from 'vite-plugin-manifest-sri';
export default defineConfig(({ mode }) => ({
  plugins: [
    tailwindcss(),
    RailsVite({
      sourceDir: 'app/frontend',
      refresh: [
        'config/routes.rb',
        'app/views/**/*',
        'app/components/**/*',
        'app/**/*.rb',
        'config/locales/**/*.yml',
      ],
    }),
    manifestSRI(),
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
    port: 3036,
    hmr: {
      host: 'vite.solectrus.localhost',
      clientPort: 443,
      protocol: 'wss',
    },
  },
}));
