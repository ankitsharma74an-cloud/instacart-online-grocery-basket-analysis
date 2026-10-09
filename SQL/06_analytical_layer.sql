
-- ============================================================
CREATE SCHEMA IF NOT EXISTS analytics;
-- ============================================================


-- ============================================================
-- Analytical-layer cleanup preparation
-- ============================================================
DROP TABLE IF EXISTS analytics.market_basket_product_universe;
DROP TABLE IF EXISTS analytics.customer_behavior;
DROP TABLE IF EXISTS analytics.customer_purchase_gap_distribution;
DROP TABLE IF EXISTS analytics.customer_frequency;
DROP TABLE IF EXISTS analytics.aisle_performance;
DROP TABLE IF EXISTS analytics.department_performance;
DROP TABLE IF EXISTS analytics.product_performance;
DROP TABLE IF EXISTS analytics.reorder_by_sequence;
DROP TABLE IF EXISTS analytics.reorder_summary;
DROP TABLE IF EXISTS analytics.basket_size_distribution;
DROP TABLE IF EXISTS analytics.orders_by_day_hour;
DROP TABLE IF EXISTS analytics.orders_by_hour;
DROP TABLE IF EXISTS analytics.orders_by_day;
DROP TABLE IF EXISTS analytics.order_basket_summary;
DROP TABLE IF EXISTS analytics.enriched_order_product_prior;

-- ============================================================
-- Create the core analytical dataset
-- ============================================================
CREATE TABLE analytics.enriched_order_product_prior AS
SELECT
    o.order_id,
    o.user_id,
    o.order_number,
    o.order_dow,
    o.order_hour_of_day,
    o.days_since_prior_order,

    op.product_id,
    p.product_name,

    p.aisle_id,
    p.aisle,

    p.department_id,
    p.department,

    op.add_to_cart_order,
    op.reordered

FROM analytics.clean_order_products_prior op

INNER JOIN analytics.clean_orders o
    ON op.order_id = o.order_id
   AND o.eval_set = 'prior'

INNER JOIN analytics.clean_products p
    ON op.product_id = p.product_id;


-- ============================================================
-- Validate the enriched dataset
-- ============================================================
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT (order_id, product_id)) AS distinct_order_product_keys
FROM analytics.enriched_order_product_prior;
-- ============================================================
SELECT COUNT(*) AS row_difference
FROM (
    SELECT order_id, product_id
    FROM analytics.clean_order_products_prior

    EXCEPT

    SELECT order_id, product_id
    FROM analytics.enriched_order_product_prior
) x;
-- ============================================================
SELECT COUNT(*) AS invalid_departments
FROM analytics.enriched_order_product_prior
WHERE department_id IS NULL
   OR department IS NULL;
-- ============================================================
SELECT COUNT(*) AS invalid_aisles
FROM analytics.enriched_order_product_prior
WHERE aisle_id IS NULL
   OR aisle IS NULL;
-- ============================================================
SELECT COUNT(*) AS wrong_eval_set
FROM analytics.enriched_order_product_prior e
JOIN analytics.clean_orders o
    ON e.order_id = o.order_id
WHERE o.eval_set <> 'prior';


-- ============================================================
-- Create indexes for the analytical dataset
-- ============================================================
CREATE INDEX idx_eop_prior_order_id
    ON analytics.enriched_order_product_prior(order_id);

CREATE INDEX idx_eop_prior_user_id
    ON analytics.enriched_order_product_prior(user_id);

CREATE INDEX idx_eop_prior_product_id
    ON analytics.enriched_order_product_prior(product_id);

CREATE INDEX idx_eop_prior_aisle_id
    ON analytics.enriched_order_product_prior(aisle_id);

CREATE INDEX idx_eop_prior_department_id
    ON analytics.enriched_order_product_prior(department_id);
-- ============================================================
ANALYZE analytics.enriched_order_product_prior;
-- ============================================================



-- ============================================================
-- Create order-level analytical table
-- ============================================================
CREATE TABLE analytics.order_basket_summary AS
SELECT
    order_id,
    MIN(user_id) AS user_id,
    MIN(order_number) AS order_number,
    MIN(order_dow) AS order_dow,
    MIN(order_hour_of_day) AS order_hour_of_day,
    MIN(days_since_prior_order) AS days_since_prior_order,

    COUNT(*) AS basket_size,

    SUM(
        CASE
            WHEN reordered = 1 THEN 1
            ELSE 0
        END
    ) AS reordered_items,

    SUM(
        CASE
            WHEN reordered = 0 THEN 1
            ELSE 0
        END
    ) AS first_time_items

FROM analytics.enriched_order_product_prior

GROUP BY order_id;


-- ============================================================
-- Validate order_basket_summary
-- ============================================================
SELECT
    COUNT(*) AS order_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    SUM(basket_size) AS total_items,
    SUM(reordered_items) AS reordered_items,
    SUM(first_time_items) AS first_time_items
FROM analytics.order_basket_summary;


-- ============================================================
SELECT
    COUNT(*) AS invalid_basket_sizes
FROM analytics.order_basket_summary
WHERE basket_size < 1;
-- ============================================================
SELECT
    SUM(
        reordered_items
        + first_time_items
        - basket_size
    ) AS composition_difference
FROM analytics.order_basket_summary;



-- ============================================================
-- Create reorder summary
-- ============================================================
CREATE TABLE analytics.reorder_summary AS
SELECT
    COUNT(*) AS total_items,

    SUM(
        CASE
            WHEN reordered = 1 THEN 1
            ELSE 0
        END
    ) AS reordered_items,

    SUM(
        CASE
            WHEN reordered = 0 THEN 1
            ELSE 0
        END
    ) AS first_time_items,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN reordered = 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS reorder_rate_pct

FROM analytics.enriched_order_product_prior;



-- ============================================================
-- Create orders-by-day analytical output
-- ============================================================
CREATE TABLE analytics.orders_by_day AS
SELECT
    order_dow,

    CASE order_dow
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,

    COUNT(*) AS total_orders

FROM analytics.order_basket_summary

GROUP BY order_dow

ORDER BY order_dow;

-- ============================================================
-- Validate day output
-- ============================================================
SELECT
    COUNT(*) AS day_rows,
    SUM(total_orders) AS total_orders
FROM analytics.orders_by_day;



-- ============================================================
-- Create orders-by-hour output
-- ============================================================
CREATE TABLE analytics.orders_by_hour AS
SELECT
    order_hour_of_day,
    LPAD(order_hour_of_day::text, 2, '0') || ':00' AS hour_label,
    COUNT(*) AS total_orders

FROM analytics.order_basket_summary

GROUP BY order_hour_of_day

ORDER BY order_hour_of_day;

-- ============================================================
-- Validate hour output
-- ============================================================
SELECT
    COUNT(*) AS hour_rows,
    SUM(total_orders) AS total_orders
FROM analytics.orders_by_hour;



-- ============================================================
-- Create day-hour output
-- ============================================================
CREATE TABLE analytics.orders_by_day_hour AS
SELECT
    order_dow,
    order_hour_of_day,

    CASE order_dow
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,

    LPAD(order_hour_of_day::text, 2, '0') || ':00'
        AS hour_label,

    COUNT(*) AS total_orders

FROM analytics.order_basket_summary

GROUP BY
    order_dow,
    order_hour_of_day

ORDER BY
    order_dow,
    order_hour_of_day;
-- ============================================================
-- Validate day-hour output
-- ============================================================
SELECT
    COUNT(*) AS rows,
    SUM(total_orders) AS total_orders
FROM analytics.orders_by_day_hour;
-- ============================================================
SELECT COUNT(*) AS invalid_combinations
FROM analytics.orders_by_day_hour
WHERE order_dow NOT BETWEEN 0 AND 6
   OR order_hour_of_day NOT BETWEEN 0 AND 23;




-- ============================================================
-- Create basket-size distribution
-- ============================================================
CREATE TABLE analytics.basket_size_distribution AS
SELECT
    basket_size,
    COUNT(*) AS order_count
FROM analytics.order_basket_summary
GROUP BY basket_size
ORDER BY basket_size;
-- ============================================================
-- Validate basket distribution
-- ============================================================
SELECT
    COUNT(*) AS distribution_rows,
    SUM(order_count) AS orders
FROM analytics.basket_size_distribution;




-- ============================================================
-- Create reorder-by-order-sequence
-- ============================================================
CREATE TABLE analytics.reorder_by_sequence AS
SELECT
    order_number,

    COUNT(*) AS item_purchases,

    SUM(
        CASE
            WHEN reordered = 1 THEN 1
            ELSE 0
        END
    ) AS reordered_items,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN reordered = 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS reorder_rate_pct

FROM analytics.enriched_order_product_prior

GROUP BY order_number

ORDER BY order_number;
-- ============================================================
-- Validate reorder sequence
-- ============================================================
SELECT
    COUNT(*) AS sequence_rows,
    MIN(order_number) AS minimum_order_number,
    MAX(order_number) AS maximum_order_number
FROM analytics.reorder_by_sequence;
-- ============================================================
SELECT COUNT(*) AS invalid_rates
FROM analytics.reorder_by_sequence
WHERE reorder_rate_pct < 0
   OR reorder_rate_pct > 100;



-- ============================================================
-- Create product performance
-- ============================================================
CREATE TABLE analytics.product_performance AS
SELECT
    product_id,
    MIN(product_name) AS product_name,
    MIN(aisle_id) AS aisle_id,
    MIN(aisle) AS aisle,
    MIN(department_id) AS department_id,
    MIN(department) AS department,

    COUNT(*) AS purchase_count,

    COUNT(DISTINCT order_id) AS unique_orders,

    COUNT(DISTINCT user_id) AS unique_customers,

    SUM(
        CASE
            WHEN reordered = 1 THEN 1
            ELSE 0
        END
    ) AS reorder_count,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN reordered = 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS reorder_rate_pct,

    ROUND(
        AVG(add_to_cart_order)::numeric,
        2
    ) AS average_cart_position

FROM analytics.enriched_order_product_prior

GROUP BY product_id;

-- ============================================================
-- Validate product performance
-- ============================================================
SELECT
    COUNT(*) AS product_rows,
    SUM(purchase_count) AS purchase_total,
    SUM(reorder_count) AS reorder_total
FROM analytics.product_performance;
-- ============================================================
SELECT COUNT(*) AS invalid_reorder_rates
FROM analytics.product_performance
WHERE reorder_rate_pct < 0
   OR reorder_rate_pct > 100;
-- ============================================================
SELECT COUNT(*) AS invalid_products
FROM analytics.product_performance
WHERE product_name IS NULL
   OR aisle IS NULL
   OR department IS NULL;


-- ============================================================
-- Create department performance
-- ============================================================
CREATE TABLE analytics.department_performance AS
SELECT
    department_id,
    department,

    COUNT(*) AS purchase_count,

    COUNT(DISTINCT product_id) AS unique_products,

    COUNT(DISTINCT user_id) AS unique_customers,

    SUM(
        CASE
            WHEN reordered = 1 THEN 1
            ELSE 0
        END
    ) AS reorder_count,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN reordered = 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS reorder_rate_pct

FROM analytics.enriched_order_product_prior

GROUP BY
    department_id,
    department;
-- ============================================================
-- Validate department performance
-- ============================================================
SELECT
    COUNT(*) AS department_rows,
    SUM(purchase_count) AS purchase_total,
    SUM(reorder_count) AS reorder_total
FROM analytics.department_performance;
-- ============================================================
SELECT COUNT(*) AS invalid_department_mappings
FROM analytics.department_performance
WHERE department_id IS NULL
   OR department IS NULL;



-- ============================================================
-- Create aisle performance
-- ============================================================
CREATE TABLE analytics.aisle_performance AS
SELECT
    aisle_id,
    aisle,
    department_id,
    department,

    COUNT(*) AS purchase_count,

    COUNT(DISTINCT product_id) AS unique_products,

    COUNT(DISTINCT user_id) AS unique_customers,

    SUM(
        CASE
            WHEN reordered = 1 THEN 1
            ELSE 0
        END
    ) AS reorder_count,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN reordered = 1 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS reorder_rate_pct

FROM analytics.enriched_order_product_prior

GROUP BY
    aisle_id,
    aisle,
    department_id,
    department;
-- ============================================================
-- Validate aisle performance
-- ============================================================
SELECT
    COUNT(*) AS aisle_rows,
    SUM(purchase_count) AS purchase_total,
    SUM(reorder_count) AS reorder_total
FROM analytics.aisle_performance;
-- ============================================================
SELECT COUNT(*) AS invalid_aisles
FROM analytics.aisle_performance
WHERE aisle_id IS NULL
   OR aisle IS NULL
   OR department_id IS NULL
   OR department IS NULL;




-- ============================================================
-- Create customer behavior
-- ============================================================
CREATE TABLE analytics.customer_behavior AS
WITH customer_orders AS (
    SELECT
        user_id,
        order_id,
        days_since_prior_order
    FROM analytics.order_basket_summary
),

customer_base AS (
    SELECT
        user_id,
        COUNT(*) AS total_orders,
        AVG(days_since_prior_order) AS avg_days_between_orders
    FROM customer_orders
    GROUP BY user_id
),

customer_items AS (
    SELECT
        user_id,

        COUNT(*) AS total_items,

        COUNT(DISTINCT product_id) AS unique_products,

        SUM(
            CASE
                WHEN reordered = 1 THEN 1
                ELSE 0
            END
        ) AS reordered_items
    FROM analytics.enriched_order_product_prior
    GROUP BY user_id
),

department_counts AS (
    SELECT
        user_id,
        department_id,
        department,
        COUNT(*) AS item_count,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY
                COUNT(*) DESC,
                department_id
        ) AS rn
    FROM analytics.enriched_order_product_prior
    GROUP BY
        user_id,
        department_id,
        department
),

aisle_counts AS (
    SELECT
        user_id,
        aisle_id,
        aisle,
        COUNT(*) AS item_count,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY
                COUNT(*) DESC,
                aisle_id
        ) AS rn
    FROM analytics.enriched_order_product_prior
    GROUP BY
        user_id,
        aisle_id,
        aisle
)

SELECT
    cb.user_id,

    cb.total_orders,

    ci.total_items,

    ci.unique_products,

    ci.reordered_items,

    ROUND(
        ci.total_items::numeric
        / NULLIF(cb.total_orders, 0),
        2
    ) AS avg_basket_size,

    ROUND(
        100.0
        * ci.reordered_items
        / NULLIF(ci.total_items, 0),
        2
    ) AS reorder_rate_pct,

    ROUND(
        cb.avg_days_between_orders::numeric,
        2
    ) AS avg_days_between_orders,

    dc.department_id AS favorite_department_id,
    dc.department AS favorite_department,

    ac.aisle_id AS favorite_aisle_id,
    ac.aisle AS favorite_aisle

FROM customer_base cb

INNER JOIN customer_items ci
    ON cb.user_id = ci.user_id

LEFT JOIN department_counts dc
    ON cb.user_id = dc.user_id
   AND dc.rn = 1

LEFT JOIN aisle_counts ac
    ON cb.user_id = ac.user_id
   AND ac.rn = 1;
-- ============================================================
-- Validate customer behavior
-- ============================================================
SELECT
    COUNT(*) AS customer_rows,
    SUM(total_orders) AS order_total,
    SUM(total_items) AS item_total,
    SUM(reordered_items) AS reorder_total
FROM analytics.customer_behavior;
-- ============================================================
SELECT COUNT(*) AS invalid_customer_baskets
FROM analytics.customer_behavior
WHERE total_items < total_orders
   OR avg_basket_size <= 0;



-- ============================================================
-- Create customer frequency output
-- ============================================================
CREATE TABLE analytics.customer_frequency AS
SELECT
    total_orders,
    COUNT(*) AS customer_count
FROM analytics.customer_behavior
GROUP BY total_orders
ORDER BY total_orders;
-- ============================================================
SELECT SUM(customer_count) AS customers
FROM analytics.customer_frequency;



-- ============================================================
-- Create customer purchase-gap distribution
-- ============================================================
CREATE TABLE analytics.customer_purchase_gap_distribution AS
SELECT
    days_since_prior_order,
    COUNT(*) AS orders
FROM analytics.clean_orders
WHERE eval_set = 'prior'
  AND days_since_prior_order IS NOT NULL
GROUP BY days_since_prior_order
ORDER BY days_since_prior_order;
-- ============================================================
SELECT
    MIN(days_since_prior_order) AS minimum_gap,
    MAX(days_since_prior_order) AS maximum_gap
FROM analytics.customer_purchase_gap_distribution;




-- ============================================================
-- Create controlled Market Basket product universe
-- ============================================================
CREATE TABLE analytics.market_basket_product_universe AS
WITH ranked_products AS (
    SELECT
        product_id,
        product_name,
        aisle_id,
        aisle,
        department_id,
        department,
        purchase_count,

        ROW_NUMBER() OVER (
            ORDER BY
                purchase_count DESC,
                product_id
        ) AS product_rank

    FROM analytics.product_performance
)

SELECT
    product_rank,
    product_id,
    product_name,
    aisle_id,
    aisle,
    department_id,
    department,
    purchase_count

FROM ranked_products

WHERE product_rank <= 100

ORDER BY product_rank;
-- ============================================================
-- Validate Market Basket universe
-- ============================================================
SELECT
    COUNT(*) AS universe_size,
    MIN(product_rank) AS minimum_rank,
    MAX(product_rank) AS maximum_rank
FROM analytics.market_basket_product_universe;
-- ============================================================
SELECT COUNT(*) AS duplicate_products
FROM (
    SELECT product_id
    FROM analytics.market_basket_product_universe
    GROUP BY product_id
    HAVING COUNT(*) > 1
) x;



-- ============================================================
-- Create unique indexes on analytical keys
-- ============================================================
CREATE UNIQUE INDEX ux_enriched_order_product_prior
    ON analytics.enriched_order_product_prior(order_id, product_id);

CREATE UNIQUE INDEX ux_order_basket_summary
    ON analytics.order_basket_summary(order_id);

CREATE UNIQUE INDEX ux_product_performance
    ON analytics.product_performance(product_id);

CREATE UNIQUE INDEX ux_department_performance
    ON analytics.department_performance(department_id);

CREATE UNIQUE INDEX ux_aisle_performance
    ON analytics.aisle_performance(aisle_id);

CREATE UNIQUE INDEX ux_customer_behavior
    ON analytics.customer_behavior(user_id);

CREATE UNIQUE INDEX ux_market_basket_product_universe
    ON analytics.market_basket_product_universe(product_id);
-- ============================================================
-- ============================================================

