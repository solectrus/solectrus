import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default [
  eslint.configs.recommended,
  ...tseslint.configs.recommended,

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
