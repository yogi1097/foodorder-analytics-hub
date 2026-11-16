# Power BI Report

## Report File

powerbi/FoodOrder_Analytics_Hub.pbix

## Pages

### Overview

Displays:
- Total orders
- Completed-order revenue
- Average order value
- Cancellation rate
- Daily completed-order revenue
- Completed-order revenue by restaurant

Filters:
- Cuisine
- Order date range

### Validation

Contains the headline measures in a table for comparison
against SQL results.

## Metric Definitions

Revenue includes only orders where:
- order_status = Completed
- payment_status = Paid

Average order value is qualifying revenue divided by
the number of completed, paid orders.

Cancellation rate is cancelled orders divided by all orders.

All data is synthetic. Monetary amounts are displayed as USD
for demonstration purposes.

## Verified Results

After the incremental insert and update tests:

| Metric | Expected value |
|---|---:|
| Total orders | 1,001 |
| Completed paid orders | 867 |
| Revenue | $55,116.77 |
| Average order value | $63.57 |
| Cancellation rate | 8.39% |

Checks performed:
- Headline measures matched SQL results.
- Cuisine selections filtered the cards and both charts.
- Clearing Cuisine restored the overall totals.
- Selecting July 1, 2026 returned one order and $35 revenue.
- Clearing the date filter restored the overall totals.

July contains only the incremental test order.
Its low revenue does not represent a real business decline.

## Opening the Report

Open the PBIX file with Power BI Desktop.

The saved report contains imported synthetic data and can
be viewed without connecting to the original computer.

## Refreshing the Report

1. Start the local MySQL Server.
2. Build and populate the project databases using the README.
3. Run the required full or incremental warehouse load.
4. Open the PBIX in Power BI Desktop.
5. Configure MySQL credentials under:
   File > Options and settings > Data source settings.
6. Select Home > Refresh.

The report connects to:
- Server: 127.0.0.1:3306
- Database: foodorder_analytics

MySQL Connector/NET must be installed for the native connector.

Power BI uses Import mode. Database changes appear in the
report only after refreshing it.

A Microsoft Fabric workspace is not required.

## Current Scope

The report currently covers order volume, revenue,
cancellations, restaurant performance, and cuisine/date filters.

Customer retention analysis and cloud migration are possible
future extensions.