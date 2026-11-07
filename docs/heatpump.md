# Heat pump

## Comparison with an oil or a gas heating

The comparison answers one question: what did the heat pump save against a fossil heating that burns oil or gas and makes the same heat? `Heatpump::Comparison` calculates it.

### The columns

The comparison has three columns:

- The heat pump: its costs. Grid energy costs the electricity price, PV energy the lost feed-in revenue.
- The heat pump without the PV system: the grid gives all its energy, at the electricity price of each day.
- The fossil heating: the fuel for the heat at the price of each day, and its running costs per year.

The savings are the costs of the fossil heating less the costs of the heat pump. The comparison shows the savings without the PV system too.

### The heat

The heat comes from the sensor of the generated heat (`heatpump_heating_power`). Without this sensor, there is no comparison. An estimate of the heat from an assumed performance factor would show the estimate and not the measurement.

The heat pump reports the heat itself. Many heat pumps calculate it from their own values and have no calibrated heat meter. If the reported heat is too high, the fuel of the fossil heating and the savings are too high by the same share. The same occurs when the heat includes a heating rod, but the energy of the heat pump does not include its electricity.
A day counts only when it has the heat, the costs of the heat pump, an electricity price and a fuel price. So the three columns make the same heat. The comparison names the days that it leaves out.

### The heating

The admin sets up the fossil heating in Settings > Heat pump (`Heatpump::Heating`). Without a fuel, there is no comparison. The configuration has three values:

- The fuel: heating oil or natural gas.
- The annual efficiency, in percent. It is the part of the energy in the fuel that arrives as heat. It refers to the gross calorific value (the energy of the fuel with the heat of its water vapor), because a gas bill counts the kWh by this value. A condensing boiler reaches 75 to 90 % in daily use, a boiler without condensing 70 to 80 %. The data sheet gives more, because the boiler in a house cycles, keeps a tank warm and makes the hot water in summer. The default is 85 %. If the house had an oil or a gas heating before, its old bills give a more exact value: the generated heat of a year divided by the fuel in kWh of an earlier year with similar weather. This value also cancels an error of the heat sensor, because the comparison divides the same heat by it. The efficiency is the same on each day. A real boiler is worse in summer, when it only makes the hot water, and a little better in winter. So a month in summer shows too little savings and a month in winter a little too much. A whole year is right.
- The running costs per year (`fixed_costs`): all running costs of the fossil heating, for example the maintenance, the chimney sweep, the electricity of the burner and the pump, for oil the cleaning and the insurance of the tank, and an average for repairs. They count for each compared day, a 365th or a 366th of the amount.

The running costs leave out the standing charge for gas, because the gas price includes it. Without an amount, the fossil heating has no running costs. The page then shows them as 0, so the missing amount is visible. There is no default amount, because it would be an assumption that changes the savings.

### The payments

The admin records the payments of the heat pump in Settings > Heat pump > Payments (`Heatpump::Payment`). Like the payments of a car (docs/cars.md), the category of a payment gives its direction, an income or an expense. A refund is a negative amount in its category. The categories are:

| Category        | Examples                                                                | In the comparison |
| --------------- | ----------------------------------------------------------------------- | ----------------- |
| Purchase        | the device, its installation, accessories, the rates of a loan for them | no                |
| Maintenance     | maintenance, repairs                                                    | yes               |
| Operating costs | a meter of its own, the standing charge of a tariff                     | yes               |
| Other           | everything else                                                         | yes               |
| Subsidy         | a subsidy for the purchase (an income)                                  | no                |

A device that measures the heat pump, for example, is an accessory, so it belongs to the purchase. A monthly fee for it would be an operating cost. The purchase and a subsidy are the investment and no running costs, also when a loan spreads the purchase over years. They stay out, because a fossil heating has another price.

The compared payments are the running costs of the heat pump, and they lower its savings. Each side has its own running costs: the heat pump its payments, the fossil heating its running costs per year. A payment of the heat pump never counts for the fossil heating. So a repair of the heat pump lowers the savings of its year, and the maintenance of a burner counts, also when the heat pump has no maintenance.

The payments of a year spread evenly over the days of the heat pump in that year, from its first day with heat. Each compared day gets one part. A later year has 365 or 366 such days. So the first year counts its payments in full, also when the heat pump starts in November. The running year counts a part of its payments, like the running costs of the fossil heating. The date of a payment decides its year. An invoice of December that is paid in January belongs to the new year, unless the admin enters the date of December.

The payments of the cars and of the heat pump share the table `payments` (`Payment`). The column `type` names the class of each payment, `Car::Payment` or `Heatpump::Payment`, and only a car payment has a car.

### The fuel prices

The prices are in InfluxDB and come from the Public Data Collector. `FuelPrices` reads them, the same class that the comparison of a car reads. A price holds until the next one.

| Fuel        | Field                    | Unit    | One value per |
| ----------- | ------------------------ | ------- | ------------- |
| Heating oil | `Fuel:price_heating_oil` | EUR/l   | week          |
| Natural gas | `Gas:price`              | EUR/kWh | month         |

A liter of heating oil has 10.6 kWh by its gross calorific value. The gas price includes the standing charge, the taxes and the levies. Eurostat replaces an estimated gas price with the measured price about six months later. So the comparison of the last months can change.

The prices are in EUR, so the comparison needs `CURRENCY=EUR`. Without the prices of a fuel, the comparison and its settings stay out of sight.

Oil is bought in bulk, not each day. The price of each day is the price to buy the oil again. The comparison of a car with a combustion car uses the same simplification.

### The pages

A badge beside the costs on the heat pump page shows the savings of the timeframe. It opens the comparison, a page below the heat pump page with a way back and a timeframe of its own. A phone has no room for a third badge, and the costs are more important. So on a phone, the savings stand below the costs, split from them as a button of their own: a piggy bank and the amount, without a label. A tap on them opens the comparison in a tall sheet over the heat pump page, like the comparison of a car (docs/ui.md). The sheet keeps the timeframe of the page. The comparison takes each timeframe of whole days, so the live view goes to today. A visitor without the admin login sees the badge only with a result. The admin sees it always, so that the empty comparison can lead to the settings.

The page works like the comparison of a car with a combustion car:

- The heat pump without PV shows only after a click on its button. A cookie keeps the choice. By default, the column is hidden.
- A chart shows the costs of each column for the years of the whole time, or for the months of a shorter timeframe. A month has no chart. A period with fewer compared days than it has gets hatched bars.
- The price range in the column of the fossil heating opens a modal with the prices of the fuel as a line. The prices start at the first compared day and end at the last one, because the prices before the heat pump compare nothing.
- The energy costs of the heat pump link to its costs on the heat pump page, but only when no day with costs is left out. Only then does that page show the same amount.
- For the admin, each payment of the heat pump links to the list of the payments of its category, in the years of the compared days.
