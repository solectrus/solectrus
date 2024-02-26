describe('Top 10', () => {
  [
    'inverter_power',
    'house_power',
    'grid_power_import',
    'grid_power_export',
    'battery_discharging_power',
    'battery_charging_power',
    'wallbox_power',
  ].forEach((sensor) => {
    it(`${sensor} is clickable`, () => {
      cy.visit(`/top10/day/${sensor}/sum/desc`);

      cy.get('#chart-day').should('exist');

      cy.contains('Woche').click();
      cy.location('pathname').should('equal', `/top10/week/${sensor}/sum/desc`);
      cy.get('#chart-week').should('exist');

      cy.contains('Monat').click();
      cy.location('pathname').should(
        'equal',
        `/top10/month/${sensor}/sum/desc`,
      );
      cy.get('#chart-month').should('exist');

      cy.contains('Jahr').click();
      cy.location('pathname').should('equal', `/top10/year/${sensor}/sum/desc`);
      cy.get('#chart-year').should('exist');

      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${sensor}/sum/asc`);
      cy.contains('Nicht genügend Daten vorhanden.').should('be.visible');
      cy.get('#chart-year').should('not.exist');

      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${sensor}/sum/desc`);
      cy.get('#chart-year').should('exist');
    });
  });
});
