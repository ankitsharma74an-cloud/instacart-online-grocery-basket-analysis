
-- ============================================================
-- INSTACART ONLINE GROCERY BASKET ANALYSIS
-- CONTROLLED SQL CLEANING
--
-- Database : instacart_analytics
-- Source   : public.*
-- Clean    : analytics.clean_*
--
-- IMPORTANT:
-- 1. public.* SOURCE TABLES ARE NEVER UPDATED/DELETED.
-- 2. This script only creates/rebuilds analytics.clean_*.
-- 3. No analytical fact/dimension tables are created here.
-- 4. No artificial "missing" / "unknown" values are introduced.
-- ============================================================


-- ============================================================
-- SECTION 0 — CREATE CLEANING SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS analytics;


-- ============================================================
-- SECTION 1 — FREEZE SOURCE LAYER
-- ============================================================
-- "Freeze" here means the public source layer is read-only
-- from the project workflow perspective.
--
-- DO NOT run UPDATE / DELETE / TRUNCATE on:
--
-- public.aisles
-- public.departments
-- public.products
-- public.orders
-- public.order_products__prior
-- public.order_products__train
--
-- This script reads from public.* only.
-- ============================================================


-- Optional audit snapshot of the frozen source row counts.
-- This does NOT modify any public source table.

DROP TABLE IF EXISTS analytics.source_control_snapshot;

CREATE TABLE analytics.source_control_snapshot AS

SELECT
    CURRENT_TIMESTAMP AS snapshot_time,
    'aisles'::text AS table_name,
    COUNT(*)::bigint AS row_count
FROM public.aisles

UNION ALL

SELECT
    CURRENT_TIMESTAMP,
    'departments',
    COUNT(*)::bigint
FROM public.departments

UNION ALL

SELECT
    CURRENT_TIMESTAMP,
    'products',
    COUNT(*)::bigint
FROM public.products

UNION ALL

SELECT
    CURRENT_TIMESTAMP,
    'orders',
    COUNT(*)::bigint
FROM public.orders

UNION ALL

SELECT
    CURRENT_TIMESTAMP,
    'order_products__prior',
    COUNT(*)::bigint
FROM public.order_products__prior

UNION ALL

SELECT
    CURRENT_TIMESTAMP,
    'order_products__train',
    COUNT(*)::bigint
FROM public.order_products__train;


-- ============================================================
-- SECTION 2 — REMOVE ONLY PREVIOUS CLEAN-LAYER OBJECTS
-- ============================================================
-- These are rebuildable analytical-cleaning objects.
-- SOURCE TABLES ARE NOT TOUCHED.
-- ============================================================

DROP TABLE IF EXISTS analytics.clean_order_products_train;
DROP TABLE IF EXISTS analytics.clean_order_products_prior;
DROP TABLE IF EXISTS analytics.clean_orders;
DROP TABLE IF EXISTS analytics.clean_products;
DROP TABLE IF EXISTS analytics.clean_aisles;
DROP TABLE IF EXISTS analytics.clean_departments;


-- ============================================================
-- SECTION 3 — CLEAN AISLES
-- ============================================================
-- Cleaning rule:
-- aisle_id       → preserved
-- aisle          → trim whitespace
-- blank text     → NULL
--
-- No replacement value is created.
-- ============================================================

CREATE TABLE analytics.clean_aisles AS
SELECT
    aisle_id,
    NULLIF(BTRIM(aisle), '') AS aisle
FROM public.aisles;


-- ============================================================
-- SECTION 4 — CLEAN DEPARTMENTS
-- ============================================================
-- Cleaning rule:
-- department_id  → preserved
-- department     → trim whitespace
-- blank text     → NULL
--
-- No replacement value is created.
-- ============================================================

CREATE TABLE analytics.clean_departments AS
SELECT
    department_id,
    NULLIF(BTRIM(department), '') AS department
FROM public.departments;


-- ============================================================
-- SECTION 5 — CLEAN PRODUCTS
-- ============================================================
-- IMPORTANT:
--
-- Product hierarchy is rebuilt directly from the validated
-- source key relationships:
--
-- public.products.department_id
--      ↓
-- public.departments.department_id
--
-- public.products.aisle_id
--      ↓
-- public.aisles.aisle_id
--
-- No COALESCE(...,'missing') is used.
-- No product row is deleted.
-- ============================================================

CREATE TABLE analytics.clean_products AS
SELECT
    p.product_id,
    NULLIF(BTRIM(p.product_name), '') AS product_name,
    p.aisle_id,
    p.department_id,
    a.aisle,
    d.department
FROM public.products p
LEFT JOIN analytics.clean_aisles a
    ON p.aisle_id = a.aisle_id
LEFT JOIN analytics.clean_departments d
    ON p.department_id = d.department_id;


-- ============================================================
-- SECTION 6 — CLEAN ORDERS
-- ============================================================
-- Cleaning rules:
--
-- eval_set                 → LOWER + TRIM
-- numeric fields           → preserved
-- days_since_prior_order   → NULL preserved
--
-- IMPORTANT:
-- First-order NULL is valid analytical information and must NOT
-- be replaced with 0.
-- ============================================================

CREATE TABLE analytics.clean_orders AS
SELECT
    order_id,
    user_id,
    LOWER(BTRIM(eval_set)) AS eval_set,
    order_number,
    order_dow,
    order_hour_of_day,
    days_since_prior_order
FROM public.orders;


-- ============================================================
-- SECTION 7 — CLEAN PRIOR ORDER-PRODUCT DATA
-- ============================================================
-- No semantic transformation is applied.
--
-- The source values are preserved exactly because:
-- order_id + product_id
-- is the business key that must remain intact.
-- ============================================================

CREATE TABLE analytics.clean_order_products_prior AS
SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered
FROM public.order_products__prior;


-- ============================================================
-- SECTION 8 — CLEAN TRAIN ORDER-PRODUCT DATA
-- ============================================================
-- No semantic transformation is applied.
-- TRAIN remains separate from PRIOR.
-- ============================================================

CREATE TABLE analytics.clean_order_products_train AS
SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered
FROM public.order_products__train;


-- ============================================================
-- SECTION 9 — DOCUMENT CLEANING RULES
-- ============================================================

COMMENT ON TABLE analytics.clean_aisles IS
'Cleaned aisle dimension. Source: public.aisles. Text is trimmed; blank text becomes NULL.';

COMMENT ON TABLE analytics.clean_departments IS
'Cleaned department dimension. Source: public.departments. Text is trimmed; blank text becomes NULL.';

COMMENT ON TABLE analytics.clean_products IS
'Cleaned product dimension. Product hierarchy is mapped directly through source aisle_id and department_id keys. No artificial missing labels are introduced.';

COMMENT ON TABLE analytics.clean_orders IS
'Cleaned order table. eval_set is normalized with LOWER/TRIM. days_since_prior_order NULL values are preserved because first orders have no previous order.';

COMMENT ON TABLE analytics.clean_order_products_prior IS
'Cleaned PRIOR order-product table. Source values preserved. PRIOR is the primary historical analysis set.';

COMMENT ON TABLE analytics.clean_order_products_train IS
'Cleaned TRAIN order-product table. Source values preserved. TRAIN remains separate reference/validation data.';


-- ============================================================
-- SECTION 10 — CLEANING COMPLETE
-- ============================================================
-- ============================================================





-- ============================================================
-- Create the clean schema
-- ============================================================
CREATE SCHEMA IF NOT EXISTS analytics;

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'analytics';

-- ============================================================
-- Clean Aisles
-- ============================================================
DROP TABLE IF EXISTS analytics.clean_aisles;

CREATE TABLE analytics.clean_aisles AS
SELECT
    aisle_id,
    NULLIF(BTRIM(aisle), '') AS aisle
FROM public.aisles;


-- ============================================================
-- Validate clean_aisles
-- ============================================================
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT aisle_id) AS distinct_aisle_ids,
    COUNT(*) FILTER (WHERE aisle_id IS NULL) AS null_ids,
    COUNT(*) FILTER (WHERE aisle IS NULL) AS null_names
FROM analytics.clean_aisles;

-- ============================================================
-- Duplicate QA
-- ============================================================
SELECT aisle_id, COUNT(*)
FROM analytics.clean_aisles
GROUP BY aisle_id
HAVING COUNT(*) > 1;


-- ============================================================
-- Freeze key
-- ============================================================
ALTER TABLE analytics.clean_aisles
ADD CONSTRAINT pk_clean_aisles
PRIMARY KEY (aisle_id);

-- ============================================================
-- Clean Departments
-- ============================================================
DROP TABLE IF EXISTS analytics.clean_departments;

CREATE TABLE analytics.clean_departments AS
SELECT
    department_id,
    NULLIF(BTRIM(department), '') AS department
FROM public.departments;

-- ============================================================
-- Validate Departments
-- ============================================================
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT department_id) AS distinct_department_ids,
    COUNT(*) FILTER (WHERE department_id IS NULL) AS null_ids,
    COUNT(*) FILTER (WHERE department IS NULL) AS null_names
FROM analytics.clean_departments;

-- ============================================================
--Duplicate QA
-- ============================================================
SELECT department_id, COUNT(*)
FROM analytics.clean_departments
GROUP BY department_id
HAVING COUNT(*) > 1;
-- ============================================================
-- Freeze key
-- ============================================================
ALTER TABLE analytics.clean_departments
ADD CONSTRAINT pk_clean_departments
PRIMARY KEY (department_id);




-- ============================================================
-- Clean Products
-- ============================================================
DROP TABLE IF EXISTS analytics.clean_products;

CREATE TABLE analytics.clean_products AS
SELECT
    p.product_id,
    NULLIF(BTRIM(p.product_name), '') AS product_name,
    p.aisle_id,
    p.department_id,
    ca.aisle,
    cd.department
FROM public.products p
LEFT JOIN analytics.clean_aisles ca
    ON p.aisle_id = ca.aisle_id
LEFT JOIN analytics.clean_departments cd
    ON p.department_id = cd.department_id;


-- ============================================================
-- Validate product row count
-- ============================================================
SELECT COUNT(*) AS rows
FROM analytics.clean_products;
-- ============================================================
-- Validate product key uniqueness
-- ============================================================
SELECT product_id, COUNT(*)
FROM analytics.clean_products
GROUP BY product_id
HAVING COUNT(*) > 1;
-- ============================================================
-- Validate product names
-- ============================================================
SELECT COUNT(*) AS invalid_product_names
FROM analytics.clean_products
WHERE product_name IS NULL;

-- ============================================================
-- Validate product → aisle mapping
-- ============================================================
SELECT COUNT(*) AS invalid_aisle_mappings
FROM analytics.clean_products
WHERE aisle_id IS NULL
   OR aisle IS NULL;
-- ============================================================
-- Validate product → department mapping
-- ============================================================
SELECT COUNT(*) AS invalid_department_mappings
FROM analytics.clean_products
WHERE department_id IS NULL
   OR department IS NULL;


-- ============================================================
-- Reconcile product mapping directly to source
-- ============================================================
SELECT COUNT(*) AS department_mapping_mismatches
FROM analytics.clean_products cp
JOIN public.products p
    ON cp.product_id = p.product_id
JOIN public.departments d
    ON p.department_id = d.department_id
WHERE cp.department_id <> d.department_id
   OR cp.department <> BTRIM(d.department);

-- ============================================================
-- Reconcile aisle mapping directly to source
-- ============================================================
SELECT COUNT(*) AS aisle_mapping_mismatches
FROM analytics.clean_products cp
JOIN public.products p
    ON cp.product_id = p.product_id
JOIN public.aisles a
    ON p.aisle_id = a.aisle_id
WHERE cp.aisle_id <> a.aisle_id
   OR cp.aisle <> BTRIM(a.aisle);

-- ============================================================
-- Check explicitly for artificial missing
-- ============================================================
SELECT COUNT(*) AS artificial_missing_departments
FROM analytics.clean_products
WHERE LOWER(BTRIM(department)) = 'missing';




-- ============================================================
-- Clean Orders
-- ============================================================
DROP TABLE IF EXISTS analytics.clean_orders;

CREATE TABLE analytics.clean_orders AS
SELECT
    order_id,
    user_id,
    LOWER(BTRIM(eval_set)) AS eval_set,
    order_number,
    order_dow,
    order_hour_of_day,
    days_since_prior_order
FROM public.orders;

-- ============================================================
-- Validate row count
-- ============================================================
SELECT COUNT(*) AS rows
FROM analytics.clean_orders;
-- ============================================================
-- Validate order key
-- ============================================================
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM analytics.clean_orders;
-- ============================================================
-- Validate eval_set
-- ============================================================
SELECT
    eval_set,
    COUNT(*) AS order_count
FROM analytics.clean_orders
GROUP BY eval_set
ORDER BY eval_set;
-- ============================================================
-- Validate order_dow
-- ============================================================
SELECT COUNT(*) AS invalid_order_dow
FROM analytics.clean_orders
WHERE order_dow IS NULL
   OR order_dow NOT BETWEEN 0 AND 6;
-- ============================================================
-- Validate order_hour_of_day
-- ============================================================
SELECT COUNT(*) AS invalid_order_hour
FROM analytics.clean_orders
WHERE order_hour_of_day IS NULL
   OR order_hour_of_day NOT BETWEEN 0 AND 23;
-- ============================================================
-- Validate order_number
-- ============================================================
SELECT COUNT(*) AS invalid_order_number
FROM analytics.clean_orders
WHERE order_number IS NULL
   OR order_number < 1;
-- ============================================================
-- Validate purchase-gap logic
-- ============================================================
SELECT COUNT(*) AS invalid_purchase_gap
FROM analytics.clean_orders
WHERE days_since_prior_order IS NOT NULL
  AND (
      days_since_prior_order < 0
      OR days_since_prior_order > 30
  );
-- ============================================================
-- Validate first-order NULL rule
-- ============================================================
SELECT COUNT(*) AS invalid_first_order_gap
FROM analytics.clean_orders
WHERE order_number = 1
  AND days_since_prior_order IS NOT NULL;
-- ============================================================
-- Validate later-order NULL rule
-- ============================================================
SELECT COUNT(*) AS invalid_later_order_gap
FROM analytics.clean_orders
WHERE order_number > 1
  AND days_since_prior_order IS NULL;


-- ============================================================
-- Freeze order key
-- ============================================================
ALTER TABLE analytics.clean_orders
ADD CONSTRAINT pk_clean_orders
PRIMARY KEY (order_id);


-- ============================================================
-- Clean PRIOR Order Products
-- ============================================================
DROP TABLE IF EXISTS analytics.clean_order_products_prior;

CREATE TABLE analytics.clean_order_products_prior AS
SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered
FROM public.order_products__prior;

-- ============================================================
-- Validate row count
-- ============================================================
SELECT COUNT(*) AS rows
FROM analytics.clean_order_products_prior;
-- ============================================================
-- Validate composite key
-- ============================================================
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT (order_id, product_id)) AS distinct_keys
FROM analytics.clean_order_products_prior;
-- ============================================================
-- Validate reordered
-- ============================================================
SELECT COUNT(*) AS invalid_reordered
FROM analytics.clean_order_products_prior
WHERE reordered IS NULL
   OR reordered NOT IN (0,1);
-- ============================================================
-- Validate cart position
-- ============================================================
SELECT COUNT(*) AS invalid_cart_position
FROM analytics.clean_order_products_prior
WHERE add_to_cart_order IS NULL
   OR add_to_cart_order < 1;
-- ============================================================
-- Validate order references
-- ============================================================
SELECT COUNT(*) AS orphan_orders
FROM analytics.clean_order_products_prior op
LEFT JOIN analytics.clean_orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
-- ============================================================
-- Validate product references
-- ============================================================
SELECT COUNT(*) AS orphan_products
FROM analytics.clean_order_products_prior op
LEFT JOIN analytics.clean_products p
    ON op.product_id = p.product_id
WHERE p.product_id IS NULL;
-- ============================================================
-- Validate PRIOR ↔ PRIOR relationship
-- ============================================================
SELECT COUNT(*) AS wrong_eval_set_links
FROM analytics.clean_order_products_prior op
JOIN analytics.clean_orders o
    ON op.order_id = o.order_id
WHERE o.eval_set <> 'prior';


-- ============================================================
-- Freeze composite key
-- ============================================================
ALTER TABLE analytics.clean_order_products_prior
ADD CONSTRAINT pk_clean_order_products_prior
PRIMARY KEY (order_id, product_id);




-- ============================================================
-- Clean TRAIN Order Products
-- ============================================================
DROP TABLE IF EXISTS analytics.clean_order_products_train;

CREATE TABLE analytics.clean_order_products_train AS
SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered
FROM public.order_products__train;


-- ============================================================
-- Validate row count
-- ============================================================
SELECT COUNT(*) AS rows
FROM analytics.clean_order_products_train;
-- ============================================================
-- Validate composite key
-- ============================================================
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT (order_id, product_id)) AS distinct_keys
FROM analytics.clean_order_products_train;
-- ============================================================
-- Validate reordered
-- ============================================================
SELECT COUNT(*) AS invalid_reordered
FROM analytics.clean_order_products_train
WHERE reordered IS NULL
   OR reordered NOT IN (0,1);
-- ============================================================
-- Validate cart position
-- ============================================================
SELECT COUNT(*) AS invalid_cart_position
FROM analytics.clean_order_products_train
WHERE add_to_cart_order IS NULL
   OR add_to_cart_order < 1;
-- ============================================================
-- Validate order references
-- ============================================================
SELECT COUNT(*) AS orphan_orders
FROM analytics.clean_order_products_train op
LEFT JOIN analytics.clean_orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
-- ============================================================
-- Validate product references
-- ============================================================
SELECT COUNT(*) AS orphan_products
FROM analytics.clean_order_products_train op
LEFT JOIN analytics.clean_products p
    ON op.product_id = p.product_id
WHERE p.product_id IS NULL;
-- ============================================================
-- Validate TRAIN ↔ TRAIN relationship
-- ============================================================
SELECT COUNT(*) AS wrong_eval_set_links
FROM analytics.clean_order_products_train op
JOIN analytics.clean_orders o
    ON op.order_id = o.order_id
WHERE o.eval_set <> 'train';
-- ============================================================
-- Check PRIOR/TRAIN overlap
-- ============================================================
SELECT COUNT(*) AS shared_order_ids
FROM (
    SELECT order_id
    FROM analytics.clean_order_products_prior

    INTERSECT

    SELECT order_id
    FROM analytics.clean_order_products_train
) x;



-- ============================================================
-- Freeze composite key
-- ============================================================
ALTER TABLE analytics.clean_order_products_train
ADD CONSTRAINT pk_clean_order_products_train
PRIMARY KEY (order_id, product_id);



-- ============================================================
-- Add clean-layer foreign keys
-- ============================================================
-- ============================================================
-- Product relationships
-- ============================================================
ALTER TABLE analytics.clean_products
ADD CONSTRAINT fk_clean_products_aisle
FOREIGN KEY (aisle_id)
REFERENCES analytics.clean_aisles(aisle_id);

ALTER TABLE analytics.clean_products
ADD CONSTRAINT fk_clean_products_department
FOREIGN KEY (department_id)
REFERENCES analytics.clean_departments(department_id);

-- ============================================================
-- Verify clean_products key
-- ============================================================
SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'analytics'
  AND table_name = 'clean_products'
  AND constraint_type IN ('PRIMARY KEY', 'UNIQUE');
-- ============================================================
-- Add the missing primary key
-- ============================================================
ALTER TABLE analytics.clean_products
ADD CONSTRAINT pk_clean_products
PRIMARY KEY (product_id);

-- ============================================================
-- PRIOR relationships
-- ============================================================
ALTER TABLE analytics.clean_order_products_prior
ADD CONSTRAINT fk_clean_prior_order
FOREIGN KEY (order_id)
REFERENCES analytics.clean_orders(order_id);

ALTER TABLE analytics.clean_order_products_prior
ADD CONSTRAINT fk_clean_prior_product
FOREIGN KEY (product_id)
REFERENCES analytics.clean_products(product_id);
-- ============================================================
-- TRAIN relationships
-- ============================================================
ALTER TABLE analytics.clean_order_products_train
ADD CONSTRAINT fk_clean_train_order
FOREIGN KEY (order_id)
REFERENCES analytics.clean_orders(order_id);

ALTER TABLE analytics.clean_order_products_train
ADD CONSTRAINT fk_clean_train_product
FOREIGN KEY (product_id)
REFERENCES analytics.clean_products(product_id);



-- ============================================================
-- Source vs Clean reconciliation
-- ============================================================
-- ============================================================
-- Row-count reconciliation
-- ============================================================
SELECT
    'aisles' AS table_name,
    (SELECT COUNT(*) FROM public.aisles) AS source_rows,
    (SELECT COUNT(*) FROM analytics.clean_aisles) AS clean_rows

UNION ALL

SELECT
    'departments',
    (SELECT COUNT(*) FROM public.departments),
    (SELECT COUNT(*) FROM analytics.clean_departments)

UNION ALL

SELECT
    'products',
    (SELECT COUNT(*) FROM public.products),
    (SELECT COUNT(*) FROM analytics.clean_products)

UNION ALL

SELECT
    'orders',
    (SELECT COUNT(*) FROM public.orders),
    (SELECT COUNT(*) FROM analytics.clean_orders)

UNION ALL

SELECT
    'order_products__prior',
    (SELECT COUNT(*) FROM public.order_products__prior),
    (SELECT COUNT(*) FROM analytics.clean_order_products_prior)

UNION ALL

SELECT
    'order_products__train',
    (SELECT COUNT(*) FROM public.order_products__train),
    (SELECT COUNT(*) FROM analytics.clean_order_products_train);