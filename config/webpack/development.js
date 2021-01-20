process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const webpackConfig = require('./base')

// Fix from https://github.com/rails/webpacker/issues/2832#issuecomment-762433155
if (webpackConfig.devServer) {
  webpackConfig.devServer.injectClient = true
}

module.exports = webpackConfig
