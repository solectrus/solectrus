describe('Top 10', () => {
  [
    'inverter_power',
    'house_power',
    'grid_power_plus',
    'grid_power_minus',
    'bat_power_minus',
    'bat_power_plus',
    'wallbox_charge_power',
  ].forEach((path) => {
    it(`${path} is clickable`, () => {
      cy.visit(`/top10/day/${path}`);

      cy.get('#chart-day').should('exist');

      cy.contains('Monat').click();
      cy.location('pathname').should('equal', `/top10/month/${path}`);
      cy.get('#chart-month').should('exist');

      cy.contains('Jahr').click();
      cy.location('pathname').should('equal', `/top10/year/${path}`);
      cy.get('#chart-year').should('exist');

      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${path}/asc`);
      cy.get('#chart-year').should('exist');

      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${path}/desc`);
      cy.get('#chart-year').should('exist');
    });
  });
});
