-- ============================================================
-- Prove whether missing is an actual source department
-- ============================================================
SELECT
    department_id,
    department
FROM public.departments
WHERE LOWER(BTRIM(department)) = 'missing';

-- ============================================================
-- Validate the source Product → Department mapping
-- ============================================================
SELECT
    COUNT(*) AS mapping_failures
FROM public.products p
LEFT JOIN public.departments d
    ON p.department_id = d.department_id
WHERE d.department_id IS NULL
   OR p.department_id IS NULL;
-- ============================================================
-- Confirm the missing department is actually assigned to products
-- ============================================================
SELECT
    d.department_id,
    d.department,
    COUNT(*) AS product_count
FROM public.products p
JOIN public.departments d
    ON p.department_id = d.department_id
WHERE LOWER(BTRIM(d.department)) = 'missing'
GROUP BY
    d.department_id,
    d.department;
-- ============================================================
-- Confirm the clean layer preserved that source category
-- ============================================================
SELECT
    department_id,
    department,
    COUNT(*) AS product_count
FROM analytics.clean_products
WHERE LOWER(BTRIM(department)) = 'missing'
GROUP BY
    department_id,
    department;
-- ============================================================
-- Confirm source and clean mapping are identical
-- ============================================================
SELECT COUNT(*) AS mapping_mismatches
FROM analytics.clean_products cp
JOIN public.products p
    ON cp.product_id = p.product_id
JOIN public.departments d
    ON p.department_id = d.department_id
WHERE cp.department_id <> d.department_id
   OR cp.department <> BTRIM(d.department);
-- ============================================================
-- Correct only the Master QA rule
-- ============================================================
SELECT
    'Artificial missing departments',
    0,
    COUNT(*)
FROM analytics.clean_products
WHERE LOWER(BTRIM(department)) = 'missing'


-- ============================================================
-- ============================================================
SELECT
    'Unexpected NULL departments',
    0,
    COUNT(*)
FROM analytics.clean_products
WHERE department_id IS NULL
   OR department IS NULL

-- ============================================================
-- a legitimate-category validation check
-- ============================================================
SELECT
    'Source missing department mapping',
    0,
    COUNT(*)
FROM public.products p
LEFT JOIN public.departments d
    ON p.department_id = d.department_id
WHERE d.department_id IS NULL
   OR d.department IS NULL


-- ============================================================
-- clean-vs-source mapping validation to Master QA
-- ============================================================
SELECT
    'Clean product department mapping mismatch',
    0,
    COUNT(*)
FROM analytics.clean_products cp
JOIN public.products p
    ON cp.product_id = p.product_id
JOIN public.departments d
    ON p.department_id = d.department_id
WHERE cp.department_id <> d.department_id
   OR cp.department <> BTRIM(d.department)