// ***********************************************************
// This example support/index.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import './commands';

// Alternatively you can use CommonJS syntax:
// require('./commands')

// Always request German language
beforeEach(() => {
  cy.intercept({ url: '*', middleware: true }, (req) => {
    req.headers['Accept-Language'] =
      'de-DE,de;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6';
  });
});
