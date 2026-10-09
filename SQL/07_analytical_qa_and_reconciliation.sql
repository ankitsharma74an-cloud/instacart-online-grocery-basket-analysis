
-- ============================================================
-- FINAL SQL ANALYTICAL RECONCILIATION
-- ============================================================

SELECT
    'PRIOR orders' AS check_name,
    3214874::bigint AS expected_value,
    COUNT(*)::bigint AS actual_value,
    CASE
        WHEN COUNT(*) = 3214874
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM analytics.order_basket_summary

UNION ALL

SELECT
    'PRIOR customers',
    206209,
    COUNT(DISTINCT user_id),
    CASE
        WHEN COUNT(DISTINCT user_id) = 206209
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.order_basket_summary

UNION ALL

SELECT
    'PRIOR items',
    32434489,
    SUM(basket_size),
    CASE
        WHEN SUM(basket_size) = 32434489
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.order_basket_summary

UNION ALL

SELECT
    'PRIOR reordered items',
    19126536,
    SUM(reordered_items),
    CASE
        WHEN SUM(reordered_items) = 19126536
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.order_basket_summary

UNION ALL

SELECT
    'PRIOR first-time items',
    13307953,
    SUM(first_time_items),
    CASE
        WHEN SUM(first_time_items) = 13307953
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.order_basket_summary

UNION ALL

SELECT
    'Product purchase total',
    32434489,
    SUM(purchase_count),
    CASE
        WHEN SUM(purchase_count) = 32434489
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.product_performance

UNION ALL

SELECT
    'Product reorder total',
    19126536,
    SUM(reorder_count),
    CASE
        WHEN SUM(reorder_count) = 19126536
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.product_performance

UNION ALL

SELECT
    'Department purchase total',
    32434489,
    SUM(purchase_count),
    CASE
        WHEN SUM(purchase_count) = 32434489
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.department_performance

UNION ALL

SELECT
    'Aisle purchase total',
    32434489,
    SUM(purchase_count),
    CASE
        WHEN SUM(purchase_count) = 32434489
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.aisle_performance

UNION ALL

SELECT
    'Customer item total',
    32434489,
    SUM(total_items),
    CASE
        WHEN SUM(total_items) = 32434489
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.customer_behavior

UNION ALL

SELECT
    'Customer reorder total',
    19126536,
    SUM(reordered_items),
    CASE
        WHEN SUM(reordered_items) = 19126536
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.customer_behavior

UNION ALL

SELECT
    'Customer order total',
    3214874,
    SUM(total_orders),
    CASE
        WHEN SUM(total_orders) = 3214874
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.customer_behavior

UNION ALL

SELECT
    'Day rows',
    7,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 7
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.orders_by_day

UNION ALL

SELECT
    'Hour rows',
    24,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 24
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.orders_by_hour

UNION ALL

SELECT
    'Basket distribution rows',
    113,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 113
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.basket_size_distribution

UNION ALL

SELECT
    'Reorder sequence rows',
    99,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 99
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.reorder_by_sequence

UNION ALL

SELECT
    'Product output rows',
    49677,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 49677
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.product_performance

UNION ALL

SELECT
    'Department output rows',
    21,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 21
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.department_performance

UNION ALL

SELECT
    'Aisle output rows',
    134,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 134
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.aisle_performance

UNION ALL

SELECT
    'Customer output rows',
    206209,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 206209
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.customer_behavior

UNION ALL

SELECT
    'Market Basket universe',
    100,
    COUNT(*),
    CASE
        WHEN COUNT(*) = 100
        THEN 'PASS'
        ELSE 'FAIL'
    END
FROM analytics.market_basket_product_universe

ORDER BY check_name;



-- ============================================================
-- Final analytical integrity checks
-- ============================================================
-- Reorder composition
-- ============================================================
SELECT
    SUM(reordered_items)
    + SUM(first_time_items)
    - SUM(basket_size) AS variance
FROM analytics.order_basket_summary;
-- ============================================================
-- Reorder composition
-- ============================================================
SELECT COUNT(*) AS failures
FROM analytics.product_performance
WHERE reorder_rate_pct < 0
   OR reorder_rate_pct > 100;
-- ============================================================
-- No invalid department rates
-- ============================================================
SELECT COUNT(*) AS failures
FROM analytics.department_performance
WHERE reorder_rate_pct < 0
   OR reorder_rate_pct > 100;
-- ============================================================
-- No invalid aisle rates
-- -- ============================================================
SELECT COUNT(*) AS failures
FROM analytics.aisle_performance
WHERE reorder_rate_pct < 0
   OR reorder_rate_pct > 100;
-- ============================================================
-- No invalid customer rates
-- ============================================================
SELECT COUNT(*) AS failures
FROM analytics.customer_behavior
WHERE reorder_rate_pct < 0
   OR reorder_rate_pct > 100;
-- ============================================================
-- Customer reorder cannot exceed items
-- ============================================================
SELECT COUNT(*) AS failures
FROM analytics.customer_behavior
WHERE reordered_items > total_items;
 -- ============================================================
-- Product reorder cannot exceed purchases
-- ============================================================
SELECT COUNT(*) AS failures
FROM analytics.product_performance
WHERE reorder_count > purchase_count;


-- ============================================================
-- Confirm the department mapping
-- ============================================================
SELECT
    department_id,
    department,
    COUNT(*) AS product_rows
FROM analytics.clean_products
GROUP BY
    department_id,
    department
ORDER BY department_id;
-- ============================================================
SELECT COUNT(*) AS mapping_failures
FROM analytics.enriched_order_product_prior
WHERE department_id IS NULL
   OR department IS NULL;
-- ============================================================

-- ============================================================

-- ============================================================

-- ============================================================

-- ============================================================

-- ============================================================

-- ============================================================