describe('Essentials', () => {
  it('has tiles with values', () => {
    cy.visit('/essentials');

    cy.get('#tile-total_inverter_power-now').should('contain', '10,0');
    cy.get('#tile-total_inverter_power-day').should('contain', '20,0');
    cy.get('#tile-total_inverter_power-month').should('contain', '20,0');
    cy.get('#tile-total_inverter_power-year').should('contain', '20,0');
    cy.get('#tile-co2_reduction-year a').should('contain', '8');
    cy.get('#tile-savings-year a').should('contain', '3,68');
  });
});
