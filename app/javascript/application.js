// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/packs and only use these pack files to reference
// that code so it'll be compiled.

import Honeybadger from '@honeybadger-io/js';

const honeybadgerApiKey = document.querySelector(
  'meta[name="honeybadger-api-key"]',
)?.content;
if (honeybadgerApiKey) {
  const version = document.querySelector('meta[name="version"]').content;

  Honeybadger.configure({
    apiKey: honeybadgerApiKey,
    environment: 'production',
    revision: version,
  });
}

import '@hotwired/turbo-rails';
import 'channels';
import 'stylesheets/application.css';
import 'controllers';
import 'components';

import 'utils/plausible';

// import all image files in a folder:
require.context('./images', true);
