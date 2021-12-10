const colors = require('tailwindcss/colors');

module.exports = {
  theme: {
    extend: {
      colors: {
        green: colors.emerald,
        yellow: colors.amber,
        purple: colors.violet,
      },
    },
  },

  content: [
    './app/**/*.html',
    './app/**/*.html.erb',
    './app/**/*.html.slim',
    './app/**/*.rb',
    './app/javascript/**/*.js',
  ],

  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
  ],
};
