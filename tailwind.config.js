module.exports = {
  darkMode: false, // or 'media' or 'class'

  mode: 'jit', // https://tailwindcss.com/docs/just-in-time-mode

  theme: {
    extend: {},
  },

  variants: {
    extend: {},
  },

  purge: [
    './app/**/*.html',
    './app/**/*.html.erb',
    './app/**/*.html.slim',
    './app/**/*.rb',
    './app/packs/**/*.js'
  ],

  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio')
  ]
}
