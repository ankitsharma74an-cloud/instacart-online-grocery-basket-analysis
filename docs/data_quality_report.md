# Data Quality Report

## 1. Purpose

This document records the data-quality and analytical-integrity checks performed throughout the Instacart Online Grocery Basket Analysis project.

The objective was to ensure that data remained consistent from:

**Source CSV → PostgreSQL → Clean Layer → Analytical Layer → Python → Power BI**

---

# 2. Source Data QA

The six original Kaggle CSV files were loaded into PostgreSQL source tables.

| Source Table | Validated Rows |
|---|---:|
| `aisles` | 134 |
| `departments` | 21 |
| `products` | 49,688 |
| `orders` | 3,421,083 |
| `order_products__prior` | 32,434,489 |
| `order_products__train` | 1,384,617 |

## Source QA Results

| Check | Result |
|---|---|
| Primary/composite key uniqueness | PASS |
| Order-product duplicate-key check | PASS |
| Product → aisle mapping | PASS |
| Product → department mapping | PASS |
| `eval_set` validation | PASS |
| Product-name NULL check | PASS |
| Expected `days_since_prior_order` NULL handling | PASS |

---

# 3. Source Data Semantics

## Department `missing`

The source dataset contains a department literally named `missing`.

Validation established that:

- It exists in the original department table.
- Products map to it through valid department keys.
- No source product-to-department mapping failures were found.
- The value is therefore treated as legitimate source data.

It is not deleted, renamed, or converted into an artificial unknown category.

## `days_since_prior_order`

NULL values are expected for first orders.

They are preserved instead of being incorrectly classified as missing data errors.

---

# 4. Clean-Layer QA

The controlled cleaning layer applies standardized transformations without deleting valid source rows.

Validation included:

- Row-count preservation
- Key uniqueness
- Text standardization
- Blank-to-NULL handling
- Product hierarchy validation
- Source-to-clean mapping reconciliation

Results:

| Check | Result |
|---|---|
| Clean-layer row integrity | PASS |
| Product hierarchy mapping | PASS |
| Source-to-clean mapping reconciliation | PASS |
| Unexpected NULL descriptive attributes | PASS |
| Key uniqueness | PASS |

---

# 5. Analytical Layer QA

Expected analytical controls included:

| Analytical Control | Expected Result |
|---|---:|
| PRIOR orders | 3,214,874 |
| PRIOR customers | 206,209 |
| PRIOR items | 32,434,489 |
| PRIOR reordered items | 19,126,536 |
| PRIOR first-time items | 13,307,953 |
| PRIOR purchased products | 49,677 |
| Average basket size | 10.088883... |
| Overall reorder rate | 58.969746...% |
| Departments | 21 |
| Aisles | 134 |
| Customer records | 206,209 |
| Product performance records | 49,677 |

---

# 6. Business-Level Reconciliation

Selected results were reconciled across the analytical layer.

### Department

- Produce purchases: **9,479,291**
- Dairy Eggs purchases: **5,414,016**
- Dairy Eggs reorder rate: **67.00%**

### Customer

- PRIOR customers: **206,209**
- High-frequency/high-reorder customers: **49,610**
- Share of customers: approximately **24.06%**

### Reorder

- Overall reorder rate: **58.97%**

### Basket

- Average basket size: approximately **10.09 items**

### Market Basket

Strongest validated observed pair:

- Sparkling Lemon Water
- Lime Sparkling Water
- Orders together: **8,546**
- Lift: **18.0024**

These results were validated before being used in Power BI and business recommendations.

---

# 7. Python QA

The Python analytical workflow performed automated validation of the SQL analytical layer.

Results:

- SQL analytical object validation: PASS
- Expected row-count contracts: PASS
- Key uniqueness: PASS
- Reorder-rate range validation: PASS
- Basket integrity: PASS
- Customer integrity: PASS
- Product integrity: PASS
- Customer-segment reconciliation: PASS
- Market-basket association validation: PASS
- Methodology controls: PASS
- SQL ↔ Python cross-validation: **23 checks / 0 failures**
- Python final analytical validation: **27 checks / 0 failures**

The customer-segment percentages can sum to 99.99% because of two-decimal display rounding; the underlying customer counts reconcile exactly.

---

# 8. Market Basket QA

Market basket analysis was performed using a controlled top-100 product universe.

Controls included:

- Minimum pair orders = 100
- Product-pair ordering standardized as A < B
- No duplicate pairs
- Support constrained to valid proportions
- Confidence constrained to valid percentages
- Lift greater than zero
- Maximum output controlled for analytical usability

The Python workflow processed the analytical basket data and validated the known regression pair:

**Sparkling Lemon Water + Lime Sparkling Water**

- Together: 8,546 orders
- Lift: 18.0024

Association is interpreted as an observed relationship, not proof of causation.

---

# 9. SQL ↔ Python Reconciliation

The project completed cross-validation between PostgreSQL analytical outputs and Python.

**Result: PASS**

Validated areas included:

- Executive KPIs
- Row counts
- Customer counts
- Product counts
- Department totals
- Reorder metrics
- Basket metrics
- Market basket regression control
- Analytical object contracts

---

# 10. Power BI Model QA

Power BI was connected to validated analytical outputs rather than the uncontrolled raw CSV layer.

Model QA covered:

- Table row counts
- Dimension uniqueness
- Relationship cardinality
- Relationship direction
- Key matching
- Hour/day dimensions
- Legitimate `missing` department preservation
- Analytical fact integrity

**Result: PASS**

---

# 11. DAX QA

DAX measures were validated against known SQL/Python control values.

Key controls included:

- Orders
- Customers
- Items
- Reordered items
- First-time items
- Reorder rate
- Average basket size

**Result: PASS**

---

# 12. Final Dashboard QA

The final Power BI dashboard was reviewed for:

- KPI consistency
- Correct filtering behavior
- Relationship behavior
- Visual correctness
- Analytical interpretation
- Page structure
- Business recommendation alignment

**Result: PASS**

---

# 13. Overall QA Status

| QA Stage | Status |
|---|---|
| Source QA | PASS |
| Clean-Layer QA | PASS |
| SQL Analytical QA | PASS |
| SQL ↔ Python Reconciliation | PASS |
| Python Analytical Validation | PASS |
| Power BI Model QA | PASS |
| DAX QA | PASS |
| Final Dashboard QA | PASS |

## Overall Analytical Integrity: PASS

No known analytical integrity issue requires another analytical rebuild based on the completed validation workflow.

---

# 14. Limitations

The dataset does not support:

- Revenue analysis
- Profit analysis
- Customer demographics
- Conventional monetary RFM
- Confirmed customer churn
- Confirmed stockout analysis
- Inventory availability analysis

These limitations are retained throughout the project rather than replaced with unsupported assumptions.
