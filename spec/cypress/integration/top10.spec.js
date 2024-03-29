describe('Top 10', () => {
  [
    'inverter_power',
    'house_power',
    'grid_power_plus',
    'grid_power_minus',
    'bat_power_minus',
    'bat_power_plus',
    'wallbox_charge_power',
  ].forEach((field) => {
    it(`${field} is clickable`, () => {
      cy.visit(`/top10/day/${field}/sum/desc`);

      cy.get('#chart-day').should('exist');

      cy.contains('Woche').click();
      cy.location('pathname').should('equal', `/top10/week/${field}/sum/desc`);
      cy.get('#chart-week').should('exist');

      cy.contains('Monat').click();
      cy.location('pathname').should('equal', `/top10/month/${field}/sum/desc`);
      cy.get('#chart-month').should('exist');

      cy.contains('Jahr').click();
      cy.location('pathname').should('equal', `/top10/year/${field}/sum/desc`);
      cy.get('#chart-year').should('exist');

      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${field}/sum/asc`);
      cy.contains('Nicht genügend Daten vorhanden.').should('be.visible');
      cy.get('#chart-year').should('not.exist');

      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${field}/sum/desc`);
      cy.get('#chart-year').should('exist');
    });
  });
});
