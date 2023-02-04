describe('Home page', () => {
  [
    'inverter_power',
    'bat_power',
    'grid_power',
    'autarky',
    'consumption',
    'house_power',
    'wallbox_charge_power',
  ].forEach((path) => {
    it(`${path} is clickable`, () => {
      cy.visit(`/${path}`);

      navigateNow();
      navigateDay();
      navigateWeek();
      navigateMonth();
      navigateYear();
      navigateAll();
    });

    function navigateNow() {
      cy.contains('Jetzt').click();
      cy.location('pathname').should('equal', `/${path}/now`);
      cy.get('#tab-now').should('be.visible');
      cy.get('header').should('contain', 'Heute, 12:00 Uhr');

      if (path == 'inverter_power')
        cy.get('#segment-inverter_power').should('contain', '9,0\u00a0kW');
    }

    function navigateDay() {
      cy.contains('Tag').click();
      cy.location('pathname').should('equal', `/${path}/2022-06-21`);
      cy.get('#tab-day').should('be.visible');
      cy.get('header').should('contain', 'Dienstag, 21. Juni 2022');
      cy.get('#chart-day').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power').should('contain', '18,0\u00a0kWh');
        cy.get('#chart')
          .should('contain', 'Erwartet werden')
          .should('contain', '58')
          .should('contain', 'kWh');
      }

      clickPrev('Montag, 20. Juni 2022');
      clickNext('Dienstag, 21. Juni 2022');
    }

    function navigateWeek() {
      cy.contains('Woche').click();
      cy.location('pathname').should('equal', `/${path}/2022-W25`);
      cy.get('#tab-week').should('be.visible');
      cy.get('header').should('contain', 'KW 25, 2022');
      cy.get('#chart-week').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power').should('contain', '18,0\u00a0kWh');
      }

      clickPrev('KW 24, 2022');
      clickNext('KW 25, 2022');
    }

    function navigateMonth() {
      cy.contains('Monat').click();
      cy.location('pathname').should('equal', `/${path}/2022-06`);
      cy.get('#tab-month').should('be.visible');
      cy.get('header').should('contain', 'Juni 2022');
      cy.get('#chart-month').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power').should('contain', '18,0\u00a0kWh');
      }

      clickPrev('Mai 2022');
      clickNext('Juni 2022');
    }

    function navigateYear() {
      cy.contains('Jahr').click();
      cy.location('pathname').should('equal', `/${path}/2022`);
      cy.get('#tab-year').should('be.visible');
      cy.get('header').should('contain', '2022');
      cy.get('#chart-year').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power').should('contain', '18,0\u00a0kWh');
      }

      clickPrev('2021');
      clickNext('2022');
    }

    function navigateAll() {
      cy.contains('Gesamt').click();
      cy.location('pathname').should('equal', `/${path}/all`);
      cy.get('#tab-all').should('be.visible');
      cy.get('header').should('contain', 'Seit Inbetriebnahme');
      cy.get('#chart-all').should('be.visible');

      if (path == 'inverter_power') {
        cy.get('#segment-inverter_power').should('contain', '18,0\u00a0kWh');
      }
    }

    function clickPrev(expectedHeader) {
      cy.get('header a[rel="prev nofollow"]').click();
      cy.get('header').should('contain', expectedHeader);
    }

    function clickNext(expectedHeader) {
      cy.get('header a[rel="next nofollow"]').click();
      cy.get('header').should('contain', expectedHeader);
    }
  });
});
