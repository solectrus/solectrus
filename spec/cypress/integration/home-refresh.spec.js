describe('Refresh', () => {
  beforeEach(() => {
    cy.intercept({
      method: 'GET',
      url: 'stats/inverter_power/now?chart=false',
    }).as('getStats');
  });

  it('refreshes the page', () => {
    cy.visit('/inverter_power/now');
    cy.get('#tab-now').should('be.visible');
    cy.get('header').should('contain', 'Heute, 12:00 Uhr');

    cy.window().then((win) => {
      // Fast forward time by 5 seconds, which is the refresh interval
      win.clock.tick(5000);
    });

    cy.wait('@getStats').then((interception) => {
      assert.isNotNull(interception.response.body, 'Stats call has data');
    });
  });
});
