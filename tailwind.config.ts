import type { Config } from 'tailwindcss';
const colors = require('tailwindcss/colors');

export default {
  content: ['./app/**/*.{slim,rb}', './app/javascript/**/*.{js,ts}'],

  theme: {
    extend: {
      colors: {
        green: colors.emerald,
        yellow: colors.amber,
        purple: colors.violet,
      },

      typography: {
        DEFAULT: {
          css: {
            a: {
              textUnderlineOffset: 2,
            },
          },
        },
      },
    },
  },

  plugins: [
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/forms'),
  ],
} satisfies Config;
