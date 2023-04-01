import { defineConfig } from 'cypress';

export default defineConfig({
  projectId: '8oyzrv',
  screenshotsFolder: 'tmp/cypress_screenshots',
  trashAssetsBeforeRuns: false,
  videosFolder: 'tmp/cypress_videos',
  fixturesFolder: 'spec/cypress/fixtures',
  downloadsFolder: 'spec/cypress/downloads',
  e2e: {
    baseUrl: 'https://solectrus.test',
    specPattern: 'spec/cypress/integration/**/*.{js,jsx,ts,tsx}',
    supportFile: 'spec/cypress/support/index.js',
  },
  viewportWidth: 1280,
  viewportHeight: 800,
});
