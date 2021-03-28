// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/packs and only use these pack files to reference
// that code so it'll be compiled.

import * as Sentry from "@sentry/browser"

const sentry_dns = document.querySelector('meta[name="sentry-dns"]').content
if (sentry_dns) {
  const release = document.querySelector('meta[name="release"]').content

  Sentry.init({
    dsn: sentry_dns,
    release: release,
    autoSessionTracking: false,
  })
}

import { Turbo } from "@hotwired/turbo-rails"
window.Turbo = Turbo

import "channels"
import "stylesheets/application.css"
import "controllers"
import "components"

import "utils/plausible"

// import all image files in a folder:
require.context('../images', true)
