module.exports = {
  root: true,
  env: {
    browser: true,
    node: true,
  },
  plugins: [],
  extends: ['eslint:recommended', 'prettier', 'plugin:prettier/recommended'],
  globals: {},
  rules: {
    'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',
  },
  parser: '@babel/eslint-parser',
  parserOptions: {
    sourceType: 'module', // allow the use of imports statements
    ecmaVersion: 2020, // allow the parsing of modern ecmascript
  },
};
