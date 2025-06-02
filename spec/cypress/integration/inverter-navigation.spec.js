describe('Inverter page', () => {
  ['inverter_power'].forEach((path) => {
    it(`${path} is clickable`, () => {
      cy.visit(`/inverter/${path}`);

      navigateNow();
      navigateDay();
      navigateWeek();
      navigateMonth();
      navigateYear();
      navigateAll();
    });

    function navigateNow() {
      cy.get('#stats-now').should('be.visible');

      cy.location('pathname').should('equal', `/inverter/${path}/now`);
      cy.title().should('contain', 'Live');
      cy.get('header').should('contain', '12:00 Uhr');

      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-now').should('be.visible');
    }

    function navigateDay() {
      cy.contains('Tag').click();
      cy.get('#stats-day').should('be.visible');

      cy.location('pathname').should('equal', `/inverter/${path}/2022-06-21`);
      cy.title().should('contain', 'Dienstag, 21. Juni 2022');
      cy.get('header').should('contain', 'Dienstag, 21. Juni 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-day').should('be.visible');

      clickPrevAndExpect('Montag, 20. Juni 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#inverter-chart-2022-06-20').should(
        'contain',
        'Keine Daten vorhanden',
      );

      clickNextAndExpect('Dienstag, 21. Juni 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-day').should('be.visible');
    }

    function navigateWeek() {
      cy.contains('Woche').click();
      cy.get('#stats-week').should('be.visible');

      cy.location('pathname').should('equal', `/inverter/${path}/2022-W25`);
      cy.title().should('contain', 'KW 25, 2022');
      cy.get('header').should('contain', 'KW 25, 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-week').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power_1').should('contain', '18,0\u00a0kWh');
      }

      clickPrevAndExpect('KW 24, 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#inverter-chart-2022-W24').should(
        'contain',
        'Keine Daten vorhanden',
      );

      clickNextAndExpect('KW 25, 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-week').should('be.visible');
    }

    function navigateMonth() {
      cy.contains('Monat').click();
      cy.get('#stats-month').should('be.visible');

      cy.location('pathname').should('equal', `/inverter/${path}/2022-06`);
      cy.title().should('contain', 'Juni 2022');
      cy.get('header').should('contain', 'Juni 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-month').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power_1').should('contain', '18,0\u00a0kWh');
      }

      clickPrevAndExpect('Mai 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#inverter-chart-2022-05').should(
        'contain',
        'Keine Daten vorhanden',
      );

      clickNextAndExpect('Juni 2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-month').should('be.visible');
    }

    function navigateYear() {
      cy.contains('Jahr').click();
      cy.get('#stats-year').should('be.visible');

      cy.location('pathname').should('equal', `/inverter/${path}/2022`);
      cy.title().should('contain', '2022');
      cy.get('header').should('contain', '2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-year').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power_1').should('contain', '18,0\u00a0kWh');
      }

      clickPrevAndExpect('2021');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#inverter-chart-2021').should('contain', 'Keine Daten vorhanden');

      clickNextAndExpect('2022');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-year').should('be.visible');
    }

    function navigateAll() {
      cy.contains('Gesamt').click();
      cy.get('#stats-all').should('be.visible');

      cy.location('pathname').should('equal', `/inverter/${path}/all`);
      cy.title().should('contain', 'Seit Inbetriebnahme');
      cy.get('header').should('contain', 'Seit Inbetriebnahme');
      cy.get("[data-controller='stats-with-chart--component']").should('exist');
      cy.get('#chart-all').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power_1').should('contain', '18,0\u00a0kWh');
      }
    }

    function clickPrevAndExpect(expectedTime) {
      cy.get('header a[rel="prev"]').click();
      cy.get('header time').should('contain', expectedTime);
    }

    function clickNextAndExpect(expectedTime) {
      cy.get('header a[rel="next"]').click();
      cy.get('header time').should('contain', expectedTime);
    }
  });
});
