describe('Settings', () => {
  beforeEach(() => {
    cy.visit('/settings/prices');
  });

  it('can list prices', () => {
    cy.location('pathname').should('equal', `/settings/prices`);
    cy.location('search').should('equal', '?name=electricity');

    cy.get('#list')
      .should('contain', '27.11.2020')
      .should('contain', '0,2545 €');

    cy.contains('Einspeisevergütung').click();
    cy.location('pathname').should('equal', `/settings/prices`);
    cy.location('search').should('equal', '?name=feed_in');
    cy.get('#list')
      .should('contain', '27.11.2020')
      .should('contain', '0,0832 €');
  });

  context('when no admin user is logged in', () => {
    it('cannot see buttons for add/edit/delete', () => {
      cy.get('button[aria-label="Neu"]').should('not.exist');
      cy.get('button[aria-label="Bearbeiten"]').should('not.exist');
      cy.get('button[aria-label="Löschen"]').should('not.exist');
    });

    it('cannot create price', () => {
      cy.visit('/settings/prices/new');

      cy.location('pathname').should('equal', `/login`);
    });
  });

  context('when admin user is logged in', () => {
    beforeEach(() => {
      cy.login();
      cy.visit('/settings/prices');
    });

    it('can see buttons for add/edit, but not delete', () => {
      cy.get('button[aria-label="Neu"]').should('be.exist');
      cy.get('button[aria-label="Bearbeiten"]').should('be.exist');

      cy.get('button[aria-label="Löschen"]').should('not.exist');
    });

    it('can create and delete a price', () => {
      cy.get('button[aria-label="Neu"]').click();

      // Save without filling out the form
      cy.get('#form_price button').click();
      cy.get('#form_price').should('contain', 'muss ausgefüllt werden');

      // Fill out the form, save and check if the price is listed
      cy.get('#price_starts_at').type('2023-01-01');
      cy.get('#price_value').type('0.1234');
      cy.get('#price_note').type('Das ist ein Test');
      cy.get('#form_price button').click();
      cy.get('#list')
        .should('contain', '01.01.2023')
        .should('contain', '0,1234 €')
        .should('contain', 'Das ist ein Test');

      // Edit the price and try to save with empty price value
      cy.get("button[aria-label='Bearbeiten']").first().click();
      cy.get('#price_value').type('{selectall}{backspace}');
      cy.get('form button').contains('Speichern').click();
      cy.get('form').should('contain', 'muss ausgefüllt werden');

      // Change the price value and check if the price is updated
      cy.get('#price_value').type('0.5678');
      cy.get('form button').contains('Speichern').click();
      cy.get('#list').should('contain', '0,5678 €');

      // Delete the price and check if the price is not listed anymore
      cy.get("button[aria-label='Löschen']").first().click();
      cy.get('#list').should('not.contain', '01.01.2023');
    });
  });
});
