
-- ============================================================
-- Final comprehensive cleaning QA
-- ============================================================
-- ============================================================
-- master QA query
-- ============================================================
-- ============================================================

-- ============================================================
SELECT
    check_name,
    expected_value,
    actual_value,
    CASE
        WHEN expected_value = actual_value
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM (

    SELECT
        'Aisles row count' AS check_name,
        134::bigint AS expected_value,
        COUNT(*)::bigint AS actual_value
    FROM analytics.clean_aisles

    UNION ALL

    SELECT
        'Departments row count',
        21,
        COUNT(*)
    FROM analytics.clean_departments

    UNION ALL

    SELECT
        'Products row count',
        49688,
        COUNT(*)
    FROM analytics.clean_products

    UNION ALL

    SELECT
        'Orders row count',
        3421083,
        COUNT(*)
    FROM analytics.clean_orders

    UNION ALL

    SELECT
        'PRIOR order-product row count',
        32434489,
        COUNT(*)
    FROM analytics.clean_order_products_prior

    UNION ALL

    SELECT
        'TRAIN order-product row count',
        1384617,
        COUNT(*)
    FROM analytics.clean_order_products_train

    UNION ALL

    SELECT
        'Product duplicate count',
        0,
        COUNT(*)
    FROM (
        SELECT product_id
        FROM analytics.clean_products
        GROUP BY product_id
        HAVING COUNT(*) > 1
    ) x

    UNION ALL

    SELECT
        'Department mapping failures',
        0,
        COUNT(*)
    FROM analytics.clean_products
    WHERE department_id IS NULL
       OR department IS NULL

    UNION ALL

    SELECT
        'Aisle mapping failures',
        0,
        COUNT(*)
    FROM analytics.clean_products
    WHERE aisle_id IS NULL
       OR aisle IS NULL

    UNION ALL

    SELECT
        'Artificial missing departments',
        0,
        COUNT(*)
    FROM analytics.clean_products
    WHERE LOWER(BTRIM(department)) = 'missing'

    UNION ALL

    SELECT
        'PRIOR orphan orders',
        0,
        COUNT(*)
    FROM analytics.clean_order_products_prior op
    LEFT JOIN analytics.clean_orders o
        ON op.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'PRIOR orphan products',
        0,
        COUNT(*)
    FROM analytics.clean_order_products_prior op
    LEFT JOIN analytics.clean_products p
        ON op.product_id = p.product_id
    WHERE p.product_id IS NULL

    UNION ALL

    SELECT
        'TRAIN orphan orders',
        0,
        COUNT(*)
    FROM analytics.clean_order_products_train op
    LEFT JOIN analytics.clean_orders o
        ON op.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'TRAIN orphan products',
        0,
        COUNT(*)
    FROM analytics.clean_order_products_train op
    LEFT JOIN analytics.clean_products p
        ON op.product_id = p.product_id
    WHERE p.product_id IS NULL

    UNION ALL

    SELECT
        'Invalid PRIOR reordered',
        0,
        COUNT(*)
    FROM analytics.clean_order_products_prior
    WHERE reordered IS NULL OR reordered NOT IN (0,1)

    UNION ALL

    SELECT
        'Invalid TRAIN reordered',
        0,
        COUNT(*)
    FROM analytics.clean_order_products_train
    WHERE reordered IS NULL OR reordered NOT IN (0,1)

    UNION ALL

    SELECT
        'Invalid order weekday',
        0,
        COUNT(*)
    FROM analytics.clean_orders
    WHERE order_dow IS NULL
       OR order_dow NOT BETWEEN 0 AND 6

    UNION ALL

    SELECT
        'Invalid order hour',
        0,
        COUNT(*)
    FROM analytics.clean_orders
    WHERE order_hour_of_day IS NULL
       OR order_hour_of_day NOT BETWEEN 0 AND 23

    UNION ALL

    SELECT
        'Invalid eval_set',
        0,
        COUNT(*)
    FROM analytics.clean_orders
    WHERE eval_set IS NULL
       OR eval_set NOT IN ('prior','train','test')

    UNION ALL

    SELECT
        'Invalid purchase gap',
        0,
        COUNT(*)
    FROM analytics.clean_orders
    WHERE days_since_prior_order IS NOT NULL
      AND (
          days_since_prior_order < 0
          OR days_since_prior_order > 30
      )

) q
ORDER BY check_name;



-- ============================================================
-- Final business-control reconciliation
-- ============================================================
-- ============================================================
-- Primary/composite-key uniqueness
-- ============================================================
-- ============================================================
-- PRIOR order count
-- ============================================================
SELECT COUNT(*) AS prior_orders
FROM analytics.clean_orders
WHERE eval_set = 'prior';
-- ============================================================
-- PRIOR item count
-- ============================================================
SELECT COUNT(*) AS prior_items
FROM analytics.clean_order_products_prior;
-- ============================================================
-- PRIOR customer count
-- ============================================================
SELECT COUNT(DISTINCT user_id) AS prior_customers
FROM analytics.clean_orders
WHERE eval_set = 'prior';
-- ============================================================
-- PRIOR purchased products
-- ============================================================
SELECT COUNT(DISTINCT product_id) AS purchased_products
FROM analytics.clean_order_products_prior;
-- ============================================================
-- PRIOR reordered items
-- ============================================================
SELECT
    SUM(CASE WHEN reordered = 1 THEN 1 ELSE 0 END) AS reordered_items
FROM analytics.clean_order_products_prior;
-- ============================================================
-- Reorder-rate control
-- ============================================================
SELECT
    ROUND(
        100.0 * SUM(CASE WHEN reordered = 1 THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS reorder_rate_pct
FROM analytics.clean_order_products_prior;


-- ============================================================
-- ============================================================

-- ============================================================
-- CORRECTED DEPARTMENT QA
-- ============================================================

-- 1. No NULL/unmapped departments in clean layer
SELECT
    'Unexpected NULL departments' AS check_name,
    0::bigint AS expected_value,
    COUNT(*)::bigint AS actual_value,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM analytics.clean_products
WHERE department_id IS NULL
   OR department IS NULL;


-- 2. No missing source department mappings
SELECT
    'Source department mapping failures' AS check_name,
    0::bigint AS expected_value,
    COUNT(*)::bigint AS actual_value,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM public.products p
LEFT JOIN public.departments d
    ON p.department_id = d.department_id
WHERE d.department_id IS NULL
   OR d.department IS NULL;


-- 3. Clean product department must match source
SELECT
    'Clean department mapping mismatches' AS check_name,
    0::bigint AS expected_value,
    COUNT(*)::bigint AS actual_value,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM analytics.clean_products cp
JOIN public.products p
    ON cp.product_id = p.product_id
JOIN public.departments d
    ON p.department_id = d.department_id
WHERE cp.department_id <> d.department_id
   OR cp.department <> BTRIM(d.department);