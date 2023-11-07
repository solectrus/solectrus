describe('Basic', () => {
  it('works', () => {
    cy.visit('/');

    cy.location('pathname').should('equal', `/inverter_power/now`);

    cy.get('footer')
      .should('contain', 'SOLECTRUS.de')
      .should('contain', 'ledermann.dev');

    cy.get('header').should('contain', 'Aktuell, 12:00 Uhr');
  });
});
