import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

// Formatting belongs to `bun fmt`. This config only turns off the rules that
// conflict with it.
import eslintConfigPrettier from 'eslint-config-prettier/flat';

export default [
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
  eslintConfigPrettier,

  {
    ignores: [
      '.ruby-lsp/',
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
