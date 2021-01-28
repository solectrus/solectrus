// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/packs and only use these pack files to reference
// that code so it'll be compiled.

import { Turbo } from "@hotwired/turbo-rails"
window.Turbo = Turbo

const images = require.context('../images', true)
const imagePath = (name) => images(name, true)

import "chartkick"
import "chart.js"

import "channels"
import "stylesheets/application.scss"
import "controllers"
import "components"

import "utils/plausible"
