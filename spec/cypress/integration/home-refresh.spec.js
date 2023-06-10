describe('Auto refresh', () => {
  context('when on "now" view', () => {
    beforeEach(() => {
      cy.intercept('GET', '/stats/inverter_power/now').as('getStats');

      cy.visit('/inverter_power/now');

      cy.get('header').should('contain', 'Heute, 12:00 Uhr');
    });

    it('refreshes the stats after 5 seconds', () => {
      // Fast forward time by 5 seconds, which is the refresh interval
      cy.window().then((win) => win.clock.tick(5 * 1000));

      cy.wait('@getStats').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });
  });

  context('when on "day" view', () => {
    beforeEach(() => {
      cy.intercept('GET', '/stats/inverter_power/2022-06-21').as(
        'getStatsDay1',
      );
      cy.intercept('GET', '/stats/inverter_power/2022-06-21').as(
        'getStatsDay1Refresh',
      );
      cy.intercept('GET', '/inverter_power/2022-06-22').as('getDay2');
      cy.intercept('GET', '/stats/inverter_power/2022-06-22').as(
        'getStatsDay2',
      );

      cy.visit('/inverter_power/2022-06-21');

      // Wait for this days's stats to be loaded
      cy.wait('@getStatsDay1').then((interception) => {
        assert.isNotNull(interception.response.body);
      });

      cy.get('header').should('contain', 'Dienstag, 21. Juni 2022');
    });

    it('refreshes the stats after 5 minutes', () => {
      // Fast forward time by 5 minutes, which is the refresh interval
      cy.window().then((win) => win.clock.tick(5 * 60 * 1000));

      cy.wait('@getStatsDay1Refresh').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });

    it('moves to next day when reaching end', () => {
      // Fast forward time by 12 hours + 5 minutes (= end of day)
      cy.window().then((win) => win.clock.tick((12 * 60 + 5) * 60 * 1000));

      // Wait for the next day (HTML) to be loaded
      cy.wait('@getDay2').then((interception) => {
        assert.isNotNull(interception.response.body);
      });

      cy.get('header').should('contain', 'Mittwoch, 22. Juni 2022');

      // Wait for the next day stats (TurboFrame) to be loaded
      cy.wait('@getStatsDay2').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });
  });

  context('when on "week" view', () => {
    beforeEach(() => {
      cy.intercept('GET', '/stats/inverter_power/2022-W25').as('getStatsWeek1');
      cy.intercept('GET', '/stats/inverter_power/2022-W25').as(
        'getStatsWeek1Refresh',
      );
      cy.intercept('GET', '/inverter_power/2022-W26').as('getWeek2');
      cy.intercept('GET', '/stats/inverter_power/2022-W26').as('getStatsWeek2');

      cy.visit('/inverter_power/2022-W25');
      cy.get('header').should('contain', 'KW 25, 2022');

      // Wait for this weeks's stats to be loaded
      cy.wait('@getStatsWeek1').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });

    it('refreshes the stats after 5 minutes', () => {
      // Fast forward time by 5 minutes, which is the refresh interval
      cy.window().then((win) => win.clock.tick(5 * 60 * 1000));

      cy.wait('@getStatsWeek1Refresh').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });

    it('moves to next week when reaching end', () => {
      // Fast forward time by 5 days + 12 hours + 5 minutes (= end of week)
      cy.window().then((win) =>
        win.clock.tick((5 * 24 * 60 + 12 * 60 + 5) * 60 * 1000),
      );

      // Wait for the next week (HTML) to be loaded
      cy.wait('@getWeek2').then((interception) => {
        assert.isNotNull(interception.response.body);
      });

      cy.get('header').should('contain', 'KW 26, 2022');

      // Wait for the next week stats (TurboFrame) to be loaded
      cy.wait('@getStatsWeek2').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });
  });

  context('when on "month" view', () => {
    beforeEach(() => {
      cy.intercept('GET', '/stats/inverter_power/2022-06').as('getStatsMonth1');
      cy.intercept('GET', '/stats/inverter_power/2022-06').as(
        'getStatsMonth1Refresh',
      );
      cy.intercept('GET', '/inverter_power/2022-07').as('getMonth2');
      cy.intercept('GET', '/stats/inverter_power/2022-07').as('getStatsMonth2');

      cy.visit('/inverter_power/2022-06');
      cy.get('header').should('contain', 'Juni 2022');

      // Wait for this month's stats to be loaded
      cy.wait('@getStatsMonth1').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });

    it('refreshes the stats after 5 minutes', () => {
      // Fast forward time by 5 minutes, which is the refresh interval
      cy.window().then((win) => win.clock.tick(5 * 60 * 1000));

      cy.wait('@getStatsMonth1Refresh').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });

    it('moves to next month when reaching end', () => {
      // Fast forward time by 9 days + 12 hours + 5 minutes (= end of month)
      cy.window().then((win) =>
        win.clock.tick((9 * 24 * 60 + 12 * 60 + 5) * 60 * 1000),
      );

      // Wait for the next month (HTML) to be loaded
      cy.wait('@getMonth2').then((interception) => {
        assert.isNotNull(interception.response.body);
      });

      cy.get('header').should('contain', 'Juli 2022');

      // Wait for the next month stats (TurboFrame) to be loaded
      cy.wait('@getStatsMonth2').then((interception) => {
        assert.isNotNull(interception.response.body);
      });
    });
  });
});
