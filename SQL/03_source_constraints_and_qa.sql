-- ==============================================================
-- ==============================================================
-- Run this script once after loading the source tables.
-- ==============================================================
-- ==============================================================
-- ------------------------------------------------------------
-- Verify all row counts 
-- ------------------------------------------------------------

SELECT 'aisles' AS table_name, COUNT(*) AS row_count
FROM public.aisles

UNION ALL

SELECT 'departments', COUNT(*)
FROM public.departments

UNION ALL

SELECT 'products', COUNT(*)
FROM public.products

UNION ALL

SELECT 'orders', COUNT(*)
FROM public.orders

UNION ALL

SELECT 'order_products__prior', COUNT(*)
FROM public.order_products__prior

UNION ALL

SELECT 'order_products__train', COUNT(*)
FROM public.order_products__train
ORDER BY table_name;


-- ------------------------------------------------------------
-- Verify column structures 
-- ------------------------------------------------------------

SELECT
    table_name,
    column_name,
    data_type,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
      'aisles',
      'departments',
      'products',
      'orders',
      'order_products__prior',
      'order_products__train'
  )
ORDER BY table_name, ordinal_position;


-- ------------------------------------------------------------
-- Verify important source-table keys
-- ------------------------------------------------------------
SELECT
    'aisles' AS table_name,
    COUNT(*) AS rows,
    COUNT(DISTINCT aisle_id) AS distinct_ids
FROM public.aisles

UNION ALL

SELECT
    'departments',
    COUNT(*),
    COUNT(DISTINCT department_id)
FROM public.departments

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id)
FROM public.products

UNION ALL

SELECT
    'orders',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM public.orders;


-- ------------------------------------------------------------
-- Verify order-product duplicate keys BEFORE adding PKs
-- ------------------------------------------------------------
SELECT
    order_id,
    product_id,
    COUNT(*) AS duplicate_count
FROM public.order_products__prior
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
LIMIT 20;

SELECT
    order_id,
    product_id,
    COUNT(*) AS duplicate_count
FROM public.order_products__train
GROUP BY order_id, product_id
HAVING COUNT(*) > 1
LIMIT 20;


--------------------------------------------------
-- Verify product → aisle mapping
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_products
FROM public.products p
LEFT JOIN public.aisles a
    ON p.aisle_id = a.aisle_id
WHERE a.aisle_id IS NULL;

--------------------------------------------------
--Verify product → department mapping
-- ------------------------------------------------------------
SELECT COUNT(*) AS orphan_products
FROM public.products p
LEFT JOIN public.departments d
    ON p.department_id = d.department_id
WHERE d.department_id IS NULL;


--------------------------------------------------
--Verify orders.eval_set
-- ------------------------------------------------------------

SELECT
    eval_set,
    COUNT(*) AS order_count
FROM public.orders
GROUP BY eval_set
ORDER BY eval_set;

-- ------------------------------------------------------------
-- Verify expected NULL behavior
-- ------------------------------------------------------------
SELECT COUNT(*) AS null_days_since_prior_order
FROM public.orders
WHERE days_since_prior_order IS NULL;

-- ------------------------------------------------------------
-- Verify no unexpected NULL product names
-- ------------------------------------------------------------
SELECT COUNT(*) AS null_product_names
FROM public.products
WHERE product_name IS NULL;


-- ============================================================
-- SOURCE CONSTRAINTS
-- ============================================================

ALTER TABLE public.aisles
    ADD CONSTRAINT pk_aisles
    PRIMARY KEY (aisle_id);

ALTER TABLE public.departments
    ADD CONSTRAINT pk_departments
    PRIMARY KEY (department_id);

ALTER TABLE public.products
    ADD CONSTRAINT pk_products
    PRIMARY KEY (product_id);

ALTER TABLE public.orders
    ADD CONSTRAINT pk_orders
    PRIMARY KEY (order_id);

ALTER TABLE public.order_products__prior
    ADD CONSTRAINT pk_order_products_prior
    PRIMARY KEY (order_id, product_id);

ALTER TABLE public.order_products__train
    ADD CONSTRAINT pk_order_products_train
    PRIMARY KEY (order_id, product_id);

-- ============================================================
-- Add source-level business checks
-- ============================================================
ALTER TABLE public.orders
    ADD CONSTRAINT chk_orders_eval_set
    CHECK (eval_set IN ('prior','train','test'));

ALTER TABLE public.orders
    ADD CONSTRAINT chk_orders_order_number
    CHECK (order_number >= 1);

ALTER TABLE public.orders
    ADD CONSTRAINT chk_orders_dow
    CHECK (order_dow BETWEEN 0 AND 6);

ALTER TABLE public.orders
    ADD CONSTRAINT chk_orders_hour
    CHECK (order_hour_of_day BETWEEN 0 AND 23);

ALTER TABLE public.orders
    ADD CONSTRAINT chk_orders_days_since_prior
    CHECK (
        days_since_prior_order IS NULL
        OR days_since_prior_order BETWEEN 0 AND 30
    );

ALTER TABLE public.order_products__prior
    ADD CONSTRAINT chk_prior_cart_position
    CHECK (add_to_cart_order >= 1);

ALTER TABLE public.order_products__prior
    ADD CONSTRAINT chk_prior_reordered
    CHECK (reordered IN (0,1));

ALTER TABLE public.order_products__train
    ADD CONSTRAINT chk_train_cart_position
    CHECK (add_to_cart_order >= 1);

ALTER TABLE public.order_products__train
    ADD CONSTRAINT chk_train_reordered
    CHECK (reordered IN (0,1));

-- ============================================================
-- Add source foreign keys
-- ============================================================
ALTER TABLE public.products
    ADD CONSTRAINT fk_products_aisle
    FOREIGN KEY (aisle_id)
    REFERENCES public.aisles(aisle_id);

ALTER TABLE public.products
    ADD CONSTRAINT fk_products_department
    FOREIGN KEY (department_id)
    REFERENCES public.departments(department_id);

ALTER TABLE public.order_products__prior
    ADD CONSTRAINT fk_prior_order
    FOREIGN KEY (order_id)
    REFERENCES public.orders(order_id);

ALTER TABLE public.order_products__prior
    ADD CONSTRAINT fk_prior_product
    FOREIGN KEY (product_id)
    REFERENCES public.products(product_id);

ALTER TABLE public.order_products__train
    ADD CONSTRAINT fk_train_order
    FOREIGN KEY (order_id)
    REFERENCES public.orders(order_id);

ALTER TABLE public.order_products__train
    ADD CONSTRAINT fk_train_product
    FOREIGN KEY (product_id)
    REFERENCES public.products(product_id);

-- ============================================================
-- only the necessary indexes
-- ============================================================
CREATE INDEX idx_products_aisle_id
    ON public.products(aisle_id);

CREATE INDEX idx_products_department_id
    ON public.products(department_id);

CREATE INDEX idx_orders_user_id
    ON public.orders(user_id);

CREATE INDEX idx_orders_eval_set
    ON public.orders(eval_set);

CREATE INDEX idx_prior_product_id
    ON public.order_products__prior(product_id);

CREATE INDEX idx_train_product_id
    ON public.order_products__train(product_id);

-- ============================================================
-- the final source QA
-- ============================================================
SELECT
    'aisles' AS table_name,
    COUNT(*) AS rows,
    COUNT(DISTINCT aisle_id) AS distinct_keys
FROM public.aisles

UNION ALL
SELECT
    'departments',
    COUNT(*),
    COUNT(DISTINCT department_id)
FROM public.departments

UNION ALL
SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id)
FROM public.products

UNION ALL
SELECT
    'orders',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM public.orders

UNION ALL
SELECT
    'order_products__prior',
    COUNT(*),
    COUNT(DISTINCT (order_id, product_id))
FROM public.order_products__prior

UNION ALL
SELECT
    'order_products__train',
    COUNT(*),
    COUNT(DISTINCT (order_id, product_id))
FROM public.order_products__train;