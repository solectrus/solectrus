import type { Config } from 'tailwindcss';
import colors from 'tailwindcss/colors';

export default {
  content: ['./app/**/*.{slim,rb}', './app/javascript/**/*.{js,ts}'],

  theme: {
    extend: {
      screens: {
        '3xl': '1920px',
      },

      // TODO: Remove this when Tailwind CSS 3.4 is out
      // https://github.com/tailwindlabs/tailwindcss/pull/11317
      minHeight: {
        dvh: '100dvh',
      },

      aspectRatio: {
        square: '1 / 1',
      },

      containers: {
        c0: '10rem',
        c1: '12rem',
        c2: '15rem',
        c3: '18rem',
        c4: '21rem',
      },

      spacing: {
        '128': '32rem',
      },

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
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/container-queries'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('tailwindcss-displaymodes'),
  ],
} satisfies Config;
