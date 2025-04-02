describe('Top 10', () => {
  [
    'inverter_power',
    'balcony_inverter_power',
    'house_power',
    'grid_import_power',
    'grid_export_power',
    'battery_discharging_power',
    'battery_charging_power',
    'wallbox_power',
    'heatpump_power',
  ].forEach((sensor) => {
    it(`${sensor} is clickable`, () => {
      // Days
      cy.visit(`/top10/day/${sensor}/sum/desc`);
      cy.get('#chart-day').should('exist');

      // Weeks
      cy.contains('Woche').click();
      cy.location('pathname').should('equal', `/top10/week/${sensor}/sum/desc`);
      cy.get('#chart-week').should('exist');

      // Months
      cy.contains('Monat').click();
      cy.location('pathname').should(
        'equal',
        `/top10/month/${sensor}/sum/desc`,
      );
      cy.get('#chart-month').should('exist');

      // Yeary
      cy.contains('Jahr').click();
      cy.location('pathname').should('equal', `/top10/year/${sensor}/sum/desc`);
      cy.get('#chart-year').should('exist');

      // Change sorting to asc
      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${sensor}/sum/asc`);
      cy.contains('Nicht genügend Daten vorhanden.').should('be.visible');
      cy.get('#chart-year').should('not.exist');

      // Change sorting to desc
      cy.get('[aria-label="Sortierung wechseln"]').click();
      cy.location('pathname').should('equal', `/top10/year/${sensor}/sum/desc`);
      cy.get('#chart-year').should('exist');
    });
  });
});
