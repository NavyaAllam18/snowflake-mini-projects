/*==============================================================================
 Project Name : Snowflake Warehouse Performance & Cost Optimization

 Description:
 This project demonstrates how to configure, scale, monitor, and optimize
 Snowflake Virtual Warehouses for analytical workloads.

 Objectives:
 ✔ Create and configure a Virtual Warehouse
 ✔ Implement Auto Suspend and Auto Resume
 ✔ Configure Multi-Cluster Warehouse
 ✔ Generate 5 Million Sample Sales Records
 ✔ Execute Analytical Queries
 ✔ Compare Performance Across Warehouse Sizes
 ✔ Monitor Credit Consumption
 ✔ Analyze Query History
 ✔ Configure Resource Monitor for Cost Governance

 Technologies:
 - Snowflake
 - SQL

 Concepts Covered:
 ✔ Virtual Warehouses
 ✔ Warehouse Sizing
 ✔ Multi-Cluster Scaling
 ✔ Auto Suspend & Auto Resume
 ✔ Synthetic Data Generation
 ✔ Query Performance Optimization
 ✔ Warehouse Metering
 ✔ Query History Analysis
 ✔ Credit Optimization
 ✔ Resource Monitors

===============================================================================*/


/*==============================================================================
 STEP 1: Create Virtual Warehouse

 Purpose:
 Create a warehouse optimized for sales analytics with automatic suspend/resume
 and multi-cluster support for handling concurrent workloads.
==============================================================================*/

CREATE WAREHOUSE SALES_WHOUSE
WAREHOUSE_SIZE = 'SMALL'
AUTO_SUSPEND = 20
AUTO_RESUME = TRUE
MIN_CLUSTER_COUNT = 1
MAX_CLUSTER_COUNT = 3
SCALING_POLICY = 'ECONOMY'
COMMENT = 'Warehouse for Sales Analytics Workloads';



/*==============================================================================
 STEP 2: Verify Warehouse Configuration
==============================================================================*/

SHOW WAREHOUSES;

DESCRIBE WAREHOUSE SALES_WHOUSE;

/*==============================================================================
 STEP 3: Create Database and Schema
==============================================================================*/

CREATE DATABASE SALES_DB;

CREATE SCHEMA SALES_DB.ANALYTICS;



/*==============================================================================
 STEP 4: Create Orders Table

 Purpose:
 Store sales transaction data used for warehouse performance testing.
==============================================================================*/

CREATE TABLE SALES_DB.ANALYTICS.ORDERS
(
    order_id NUMBER,
    order_date DATE,
    customer_id NUMBER,
    product_id NUMBER,
    region VARCHAR(50),
    sales_amount DECIMAL(10,2),
    quantity NUMBER,
    discount_pct DECIMAL(5,2)
);



/*==============================================================================
 STEP 5: Generate Sample Data

 Purpose:
 Insert 5 million synthetic records to simulate a real-world sales dataset.

 Note:
 The GENERATOR function is used to create large volumes of data without
 external files.
==============================================================================*/

INSERT INTO SALES_DB.ANALYTICS.ORDERS

SELECT
    SEQ4() AS order_id,

    DATEADD(
        'day',
        UNIFORM(-730,0,RANDOM()),
        CURRENT_DATE
    ) AS order_date,

    UNIFORM(1,10000,RANDOM()) AS customer_id,

    UNIFORM(1,500,RANDOM()) AS product_id,

    CASE UNIFORM(1,4,RANDOM())
        WHEN 1 THEN 'North'
        WHEN 2 THEN 'South'
        WHEN 3 THEN 'East'
        ELSE 'West'
    END AS region,

    ROUND(UNIFORM(10,5000,RANDOM())::FLOAT,2)
        AS sales_amount,

    UNIFORM(1,20,RANDOM())
        AS quantity,

    ROUND(UNIFORM(0,30,RANDOM())::FLOAT,2)
        AS discount_pct

FROM TABLE(GENERATOR(ROWCOUNT => 5000000));



/*==============================================================================
 STEP 6: Verify Data
==============================================================================*/

SELECT *
FROM SALES_DB.ANALYTICS.ORDERS;



/*==============================================================================
 STEP 7: Scale Warehouse Down

 Purpose:
 Execute analytical queries using a smaller warehouse and compare performance.
==============================================================================*/

ALTER WAREHOUSE SALES_WHOUSE
SET WAREHOUSE_SIZE='X-SMALL';



/*==============================================================================
 STEP 8: Disable Result Cache

 Purpose:
 Ensure every query is executed instead of returning cached results, allowing
 accurate warehouse performance benchmarking.
==============================================================================*/

ALTER SESSION SET USE_CACHED_RESULT = FALSE;



/*==============================================================================
 STEP 9: Execute Analytical Query

 Objective:
 Calculate sales by region and month along with customer count and average
 discount.
==============================================================================*/

SELECT
    region,
    DATE_TRUNC('month', order_date) AS month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_id) AS unique_customers,
    AVG(discount_pct) AS avg_discount
FROM SALES_DB.ANALYTICS.ORDERS
GROUP BY 1,2
ORDER BY 2,1;



/*==============================================================================
 STEP 10: Scale Warehouse Up

 Purpose:
 Increase compute resources and compare execution performance against the
 previous warehouse size.
==============================================================================*/

ALTER WAREHOUSE SALES_WHOUSE
SET WAREHOUSE_SIZE='X-LARGE';



/*==============================================================================
 STEP 11: Execute Complex Analytical Query

 Purpose:
 Evaluate warehouse performance using joins and aggregations.
==============================================================================*/

SELECT
    p.product_id,
    SUM(o.sales_amount) AS total_sales

FROM SALES_DB.ANALYTICS.ORDERS o

JOIN
(
    SELECT DISTINCT product_id
    FROM SALES_DB.ANALYTICS.ORDERS
    WHERE discount_pct > 20
) p

ON o.product_id = p.product_id

GROUP BY 1;



/*==============================================================================
 STEP 12: Monitor Warehouse Credit Consumption

 Purpose:
 Review warehouse credit usage for cost analysis.
==============================================================================*/

SELECT
    warehouse_name,
    SUM(credits_used) AS total_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE START_TIME >= CURRENT_DATE
GROUP BY warehouse_name;



/*==============================================================================
 STEP 13: Analyze Query History

 Purpose:
 Identify expensive queries and monitor warehouse performance.
==============================================================================*/

SELECT

    query_id,

    warehouse_name,

    execution_time/1000 AS execution_seconds,

    credits_used_cloud_services AS cloud_service_credits

FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY

WHERE warehouse_name='SALES_WHOUSE'

AND start_time >= DATEADD(day,-7,CURRENT_TIMESTAMP)

ORDER BY cloud_service_credits DESC

LIMIT 20;



/*==============================================================================
 STEP 14: Create Resource Monitor

 Purpose:
 Automatically monitor and control monthly warehouse credit consumption.

 Trigger Actions:
 • Notify at 75%
 • Suspend warehouse at 90%
 • Immediately suspend at 100%
==============================================================================*/

CREATE OR REPLACE RESOURCE MONITOR SALES_MONITOR

CREDIT_QUOTA = 50

FREQUENCY = MONTHLY

START_TIMESTAMP = IMMEDIATELY

TRIGGERS

ON 75 PERCENT DO NOTIFY

ON 90 PERCENT DO SUSPEND

ON 100 PERCENT DO SUSPEND_IMMEDIATE;



/*==============================================================================
 STEP 15: Attach Resource Monitor
==============================================================================*/

ALTER WAREHOUSE SALES_WHOUSE
SET RESOURCE_MONITOR = SALES_MONITOR;



/*==============================================================================
 STEP 16: Verify Resource Monitor
==============================================================================*/

SHOW RESOURCE MONITORS;



/*==============================================================================
 Project Summary

 This project demonstrates:

 ✔ Warehouse Creation and Configuration

 ✔ Auto Suspend & Auto Resume

 ✔ Multi-Cluster Warehouse Scaling

 ✔ Synthetic Data Generation (5 Million Records)

 ✔ Performance Benchmarking

 ✔ Warehouse Resizing

 ✔ Query Optimization

 ✔ Query History Analysis

 ✔ Credit Usage Monitoring

 ✔ Cost Optimization

 ✔ Resource Monitor Configuration

==============================================================================*/