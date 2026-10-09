-- ============================================================
-- INSTACART ANALYTICS
-- LOAD ALL 6 KAGGLE CSV FILES
-- Database: instacart_analytics
-- ============================================================

-- ------------------------------------------------------------
-- IMPORTANT
-- Replace:
-- C:/YOUR_DATA_FOLDER/
-- with the actual folder containing the 6 CSV files.
--
-- Example:
-- C:/INSTACART ONLINE GROCERY BASKET ANALYSIS/data/
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 1. TRUNCATE source tables
-- ------------------------------------------------------------
TRUNCATE TABLE
    public.order_products__prior,
    public.order_products__train,
    public.orders,
    public.products,
    public.aisles,
    public.departments
RESTART IDENTITY CASCADE;


-- ------------------------------------------------------------
-- 2. COPY aisles
-- ------------------------------------------------------------
copy public.aisles (aisle_id, aisle)
FROM 'C:/YOUR_DATA_FOLDER/aisles.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);


-- ------------------------------------------------------------
-- 3. COPY departments
-- ------------------------------------------------------------
copy public.departments (department_id, department)
FROM 'C:/YOUR_DATA_FOLDER/departments.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);


-- ------------------------------------------------------------
-- 4. COPY products
-- ------------------------------------------------------------
copy public.products
    (product_id, product_name, aisle_id, department_id)
FROM 'C:/YOUR_DATA_FOLDER/products.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);


-- ------------------------------------------------------------
-- 5. COPY orders
-- ------------------------------------------------------------
copy public.orders
    (
        order_id,
        user_id,
        eval_set,
        order_number,
        order_dow,
        order_hour_of_day,
        days_since_prior_order
    )
FROM 'C:/YOUR_DATA_FOLDER/orders.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);


-- ------------------------------------------------------------
-- 6. COPY prior
-- ------------------------------------------------------------
copy public.order_products__prior
    (
        order_id,
        product_id,
        add_to_cart_order,
        reordered
    )
FROM 'C:/YOUR_DATA_FOLDER/order_products__prior.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);


-- ------------------------------------------------------------
-- 7. COPY train
-- ------------------------------------------------------------
copy public.order_products__train
    (
        order_id,
        product_id,
        add_to_cart_order,
        reordered
    )
FROM 'C:/YOUR_DATA_FOLDER/order_products__train.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    QUOTE '"',
    ESCAPE '"',
    ENCODING 'UTF8'
);

--------------------------------------------------------------