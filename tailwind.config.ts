import type { Config } from 'tailwindcss';
import colors from 'tailwindcss/colors';

export default {
  content: ['./app/**/*.{slim,rb}', './app/javascript/**/*.{js,ts}'],

  theme: {
    extend: {
      transitionProperty: {
        'max-height': 'max-height',
      },

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
