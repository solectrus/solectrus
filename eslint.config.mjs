import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

import { FlatCompat } from '@eslint/eslintrc';
const compat = new FlatCompat();

export default [
  ...compat.env({
    browser: true,
    node: true,
  }),

  ...compat.config({
    extends: [
      'prettier',
      'plugin:prettier/recommended',
      'plugin:tailwindcss/recommended',

      // 'plugin:cypress/recommended',
      // Not ready for ESLint 9 yet, see https://github.com/cypress-io/eslint-plugin-cypress/issues/156
    ],
    rules: {
      'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
      'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
      'tailwindcss/no-custom-classname': 'off',
    },
  }),

  ...[eslint.configs.recommended, ...tseslint.configs.recommended].map(
    (conf) => ({
      ...conf,
      files: ['**/*.ts'],
    }),
  ),

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
