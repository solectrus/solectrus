const { webpackConfig, merge } = require('@rails/webpacker');

const customConfig = {
  resolve: {
    extensions: ['.css'],
  },
  plugins: [],
};

module.exports = merge(webpackConfig, customConfig);
