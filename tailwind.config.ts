import type { Config } from 'tailwindcss';
import colors from 'tailwindcss/colors';
import plugin from 'tailwindcss/plugin';
import svgToDataUri from 'mini-svg-data-uri';

export default {
  content: ['./app/**/*.{slim,rb}', './app/javascript/**/*.{js,ts}'],

  theme: {
    extend: {
      screens: {
        '3xl': '1920px',
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
    require('@tailwindcss/typography'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/forms'),
    plugin(function ({ addComponents, theme }) {
      // Override select's caret color as it can't be customized in @tailwindcss/forms
      // see https://github.com/tailwindlabs/tailwindcss-forms/issues/17
      addComponents({
        select: {
          'background-image': `url("${svgToDataUri(
            `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 20 20"><path stroke="${theme(
              'colors.gray.400',
              colors.gray[400],
            )}" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M6 8l4 4 4-4"/></svg>`,
          )}")`,
        },
      });
    }),
  ],
} satisfies Config;
