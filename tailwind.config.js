module.exports = {
  purge: [
    './app/**/*.html.erb',
    './app/helpers/**/*.rb',
    './src/**/*.html',
    './src/**/*.js'
  ],

  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {},
  },
  purge: {
    mode: 'all',

    content: [
      './app/**/*.html.erb',
      './app/**/*.html.slim',
      './app/helpers/**/*.rb',
      './app/javascript/**/*.js'
    ],
  },
  plugins: [
    require('@tailwindcss/forms'),
  ]
}
