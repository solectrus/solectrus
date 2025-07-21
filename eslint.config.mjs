import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

import pluginPrettierRecommended from 'eslint-plugin-prettier/recommended';

export default [
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  pluginPrettierRecommended,

  {
    ignores: [
      '.ruby-lsp/',
      '.yarn/',
      'config/',
      'coverage/',
      'db/',
      'log/',
      'node_modules/',
      'public/',
      'tmp/',
      'vendor/',
    ],
  },
];
