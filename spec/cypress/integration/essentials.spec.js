describe('Essentials', () => {
  it('has tiles with values', () => {
    cy.visit('/essentials');

    cy.get('#tile-inverter_power-now').should('contain', '9,0');
    cy.get('#tile-inverter_power-day').should('contain', '18,0');
    cy.get('#tile-inverter_power-month').should('contain', '18,0');
    cy.get('#tile-inverter_power-year').should('contain', '18,0');
    cy.get('#tile-co2_reduction-year a').should('contain', '7');
    cy.get('#tile-savings-year a').should('contain', '3,68');
  });
});
