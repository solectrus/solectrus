describe('Administrator', () => {
  context('when not logged in', () => {
    beforeEach(() => {
      cy.visit('/');

      cy.get('header a[href="/login"]').first().click({ force: true });
      cy.get('#new_admin_user').should('be.visible');
    });

    it('cannot login with invalid password', () => {
      cy.get('#admin_user_password').type('wrong');
      cy.get('#new_admin_user button').click();

      cy.get('#new_admin_user').should('contain', 'ist nicht gültig');
      cy.get('a[href="/login"]').should('exist');
      cy.get('a[href="/logout"]').should('not.exist');
    });

    it('can login with valid password', () => {
      cy.get('#admin_user_password').type('secret');
      cy.get('#new_admin_user button').click();

      cy.get('a[href="/login"]').should('not.exist');
      cy.get('a[href="/logout"]').should('exist');
    });
  });

  context('when logged in', () => {
    beforeEach(() => {
      cy.login();
      cy.visit('/');
    });

    it('can logout', () => {
      cy.get('a[href="/logout"]').first().click({ force: true });

      cy.get('a[href="/login"]').should('exist');
      cy.get('a[href="/logout"]').should('not.exist');
    });
  });
});
