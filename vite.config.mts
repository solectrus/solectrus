import { defineConfig } from 'vite';
import RailsVite from 'rails-vite-plugin';
import tailwindcss from '@tailwindcss/vite';
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
  ],
  build: {
    rolldownOptions: {
      // Exclude sinon from production builds
      external: mode === 'production' ? ['sinon'] : [],
      output: {
        codeSplitting: {
          groups: [
            {
              name: 'chart',
              test: /node_modules\/(chart|luxon)/,
            },
            {
              name: 'icons',
              test: /node_modules\/@fortawesome/,
            },
            {
              name: 'hotwire',
              test: /node_modules\/(stimulus|@hotwired|@rails)/,
            },
            {
              name: 'other-vendor',
              test: /node_modules/,
            },
          ],
        },
      },
    },
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
