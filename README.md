# FoodOrder Analytics Hub

A local data engineering and analytics project built with
Python, MySQL, and SQL. A Power BI dashboard is in progress.

The project generates synthetic food-order data, loads it into
a source database, transforms it into a dimensional warehouse,
and supports full and incremental loading.

## Project Status

In progress.

Completed:
- Reproducible synthetic data generation
- MySQL source database and CSV loading
- Dimensional analytics warehouse
- Transactional full-refresh procedure
- Source validation and warehouse reconciliation
- Reporting views
- Pipeline execution logging
- Controlled failure logging and successful recovery
- Watermark-based incremental order loading
- Insert, update, and repeat-run checks

Remaining:
- Power BI dashboard
- Final reproducibility checks
- Screenshots and demonstration
- Documentation cleanup

Microsoft Fabric migration is outside the current scope
and may be added as a future extension.

## Architecture

Python data generator
→ CSV files
→ MySQL source database
→ SQL transformations
→ MySQL analytics warehouse
→ Power BI report (in progress)

The Python runner executes warehouse procedures and records
pipeline status, timestamps, row counts, and errors.

## Technology Stack

- Python 3.13
- Faker
- MySQL Connector/Python
- MySQL Server 8.0
- MySQL Workbench
- Git and GitHub
- Power BI Desktop (report in progress)

Exact Python package versions are in requirements.txt.

## Data

All data is synthetic and does not represent real customers,
restaurants, or business performance.

The base generator creates:
- 100 customers
- 10 restaurants
- 1,000 orders
- Order activity from January through June 2026

The incremental test scripts add order 1001 and change its
amount from 25.00 to 35.00.

## Data Model

Source database: foodorder_source
- customers
- restaurants
- orders

Analytics database: foodorder_analytics
- dim_customers: one row per customer
- dim_restaurants: one row per restaurant
- dim_date: one row per calendar date
- fact_orders: one row per order
- pipeline_run_log: pipeline execution history
- pipeline_watermarks: incremental loading progress

The date dimension contains all 365 dates in 2026.

Customer and restaurant dimensions currently keep one
current record per source ID.

## Business Definitions

- Total orders includes every order status.
- Completed paid orders are both Completed and Paid.
- Revenue is the sum of amounts for completed, paid orders.
- Average order value uses the same qualifying orders.
- Cancellation rate is cancelled orders divided by all orders.

Revenue here represents qualifying order value,
not platform profit.

## Loading Strategies

### Initial CSV Load

src/load_mysql.py loads customers, restaurants, and orders
into empty source tables.

It uses parameterized batch inserts, checks row counts,
and rolls back if the load fails.

### Full Refresh

The refresh_analytics procedure rebuilds the dimensions
and order facts in a transaction.

It checks source-to-warehouse order counts and revenue
before committing.

Warehouse surrogate keys may change during a full refresh.
Dimensions and facts are rebuilt together.

### Incremental Orders

The load_orders_incremental procedure:
- Reads orders using updated_at
- Uses a one-minute overlap around the saved watermark
- Updates changed facts
- Inserts new facts
- Preserves existing fact keys
- Commits fact changes and the watermark together

Missing customer, restaurant, or date dimension lookups
cause the batch to fail.

## Validation Results

| Check | Observed result |
|---|---:|
| Source orders without customers | 0 |
| Source orders without restaurants | 0 |
| Nonpositive source amounts | 0 |
| Orders before customer registration | 0 |
| Base source and warehouse order counts | 1,000 each |
| Base completed paid orders | 866 |
| Base qualifying revenue | 55,081.77 |
| Base average order value | 63.60 |
| Base cancellation rate | 8.40% |

Reporting-view totals were reconciled to the warehouse.

Incremental tests:
- Existing-data initialization: 0 inserts, 0 updates
- Repeat run: 0 inserts, 0 updates
- New order: 1 insert
- Changed order: 1 update
- Repeat after update: 0 inserts, 0 updates

After both incremental test scripts:
- Total orders: 1,001
- Completed paid orders: 867
- Qualifying revenue: 55,116.77

A controlled failure before warehouse loading was logged
as FAILED. A subsequent normal run completed successfully.
This test did not simulate a failure inside the refresh transaction.

## Local Setup

Prerequisites:
- Git
- Python 3.13
- MySQL Server 8.0
- MySQL Workbench

Clone this repository and open its folder.

Create the Python environment in Windows PowerShell:

    py -3.13 -m venv .venv

Install dependencies:

    .\.venv\Scripts\python.exe -m pip install -r requirements.txt

Generate the base CSV files:

    .\.venv\Scripts\python.exe src/generate_data.py

Execute sql/mysql/01_create_source_database.sql
in MySQL Workbench.

Load the source data:

    .\.venv\Scripts\python.exe src/load_mysql.py

Execute these SQL scripts in order:
1. sql/mysql/03_create_analytics_tables.sql
2. sql/mysql/04_load_analytics.sql
3. sql/mysql/05_reporting_views.sql
4. sql/mysql/06_create_pipeline_log.sql
5. sql/mysql/07_create_watermarks.sql
6. sql/mysql/08_load_orders_incremental.sql

The loader and runner prompt for the local MySQL root password.
The password is not stored in the scripts.

Run a logged full refresh:

    .\.venv\Scripts\python.exe src/run_analytics.py --mode full

Run logged incremental loading:

    .\.venv\Scripts\python.exe src/run_analytics.py --mode incremental

Test failure logging:

    .\.venv\Scripts\python.exe src/run_analytics.py --mode incremental --simulate-failure

The failure-test command intentionally exits with an error.

Run validation scripts in sql/validation.

The incremental insert test modifies the synthetic source data
and should be executed once on the base dataset.
Run the update test afterward.

## Limitations

- Runs locally; cloud migration is not implemented.
- Power BI report is still in progress.
- Incremental loading currently handles orders only.
- Source changes must update updated_at.
- Backdated changes older than the overlap may be missed.
- Physical source deletions are not captured.
- New customers and restaurants require dimension loading.
- The calendar currently covers 2026 only.
- Concurrent full and incremental runs are not supported.
- The local scripts currently use the root account;
  a dedicated database user is a planned improvement.
- Incremental batch counts are printed in the terminal;
  execution logs store overall source and warehouse counts.

## Learning Reference

Inspired by the FoodOrder Analytics Hub learning project
in Darshil Parmar's DataVidhya course resources:

https://github.com/darshilparmar/DataVidhya-Data-Engineering-Course-Resources

This repository documents my local implementation,
adaptations, and validation results.

## Author

Yogesh Kumar