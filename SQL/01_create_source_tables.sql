
-- ============================================================
-- INSTACART ANALYTICS
--  SOURCE TABLE CREATION
-- Database: instacart_analytics
-- ============================================================

-- ------------------------------------------------------------
-- 1. Create public.aisles
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.aisles (
    aisle_id INTEGER,
    aisle VARCHAR(255)
);

-- ------------------------------------------------------------
-- 2. Create public.departments
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.departments (
    department_id INTEGER,
    department VARCHAR(255)
);

-- ------------------------------------------------------------
-- 3. Create public.products
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
    product_id INTEGER,
    product_name VARCHAR(500),
    aisle_id INTEGER,
    department_id INTEGER
);

-- ------------------------------------------------------------
-- 4. Create public.orders
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
    order_id INTEGER,
    user_id INTEGER,
    eval_set VARCHAR(20),
    order_number INTEGER,
    order_dow INTEGER,
    order_hour_of_day INTEGER,
    days_since_prior_order NUMERIC(4,1)
);

-- ------------------------------------------------------------
-- 5. Create public.order_products__prior
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_products__prior (
    order_id INTEGER,
    product_id INTEGER,
    add_to_cart_order INTEGER,
    reordered INTEGER
);

-- ------------------------------------------------------------
-- 6. Create public.order_products__train
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_products__train (
    order_id INTEGER,
    product_id INTEGER,
    add_to_cart_order INTEGER,
    reordered INTEGER
);

-- ------------------------------------------------------------
-- QA
-- ------------------------------------------------------------

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
      'aisles',
      'departments',
      'products',
      'orders',
      'order_products__prior',
      'order_products__train'
  )
ORDER BY table_name;