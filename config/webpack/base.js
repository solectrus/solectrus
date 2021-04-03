const { webpackConfig, merge } = require('@rails/webpacker')
const webpack = require('webpack')

const customConfig = {
  resolve: {
    extensions: ['.css']
  },
  plugins: [
  ]
}

module.exports = merge(webpackConfig, customConfig)
