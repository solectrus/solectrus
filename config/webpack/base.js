const { webpackConfig, merge } = require('@rails/webpacker')
const webpack = require('webpack')

const customConfig = {
  resolve: {
    extensions: ['.css']
  },
  plugins: [
    new webpack.IgnorePlugin({
      resourceRegExp: /^\.\/locale$/,
      contextRegExp: /moment$/
    })
  ]
}

module.exports = merge(webpackConfig, customConfig)
