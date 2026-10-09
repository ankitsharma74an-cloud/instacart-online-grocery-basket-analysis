# KPI Definitions — Instacart Online Grocery Basket Analysis

## 1. Purpose

This document defines the official Key Performance Indicators (KPIs), analytical metrics, formulas, validated values, analytical grains, interpretation rules, and governance standards used in the **Instacart Online Grocery Basket Analysis** project.

It ensures that each KPI has one definition and one validated result across:

- PostgreSQL analytical tables
- Python EDA and analytical validation
- Market Basket Analysis
- Power BI data model, DAX measures, and dashboards
- Business recommendations and project documentation

This document is the KPI source of reference for the project.

### Project Workflow

```text
Business Problem
      ↓
Data Understanding
      ↓
Source Data Validation
      ↓
Controlled SQL Cleaning
      ↓
Clean-Layer QA
      ↓
SQL Analytical Layer
      ↓
SQL Analytical QA
      ↓
Python EDA & Statistical Validation
      ↓
SQL ↔ Python Reconciliation
      ↓
Market Basket Analysis
      ↓
Power BI Data Model
      ↓
DAX Measures & QA
      ↓
Dashboard Validation
      ↓
Business Recommendations
```

---

## 2. Analytical Scope

### 2.1 Primary Analysis Set: PRIOR

`PRIOR` order history is the primary historical analysis set (`analysis_set = PRIOR`). Unless stated otherwise, all KPIs in this document refer to the PRIOR population.

| Population Metric | Validated Value |
|---|---:|
| Orders | 3,214,874 |
| Customers | 206,209 |
| Purchased item records | 32,434,489 |
| Reordered item records | 19,126,536 |
| First-time item records | 13,307,953 |
| Distinct purchased products | 49,677 |

PRIOR is used for executive KPIs, basket analysis, reorder analysis, customer behavior, product / department / aisle performance, time-based analysis, purchase-gap analysis, Market Basket Analysis, and Power BI dashboard metrics.

It is the primary population because it provides the historical order-item records required for full basket and behavioral analysis. A single, clearly defined population gives consistent KPI calculations, reproducible SQL results, consistent Python validation, stable Power BI measures, and clear business interpretation.

### 2.2 TRAIN

`TRAIN` is a reference and validation dataset, not the primary analytical population. It is retained for dataset completeness, schema validation, structural comparison, and understanding the original dataset design.

TRAIN is not combined with PRIOR in primary KPI calculations, which prevents double-counting and mixing of populations.

### 2.3 TEST

`TEST` is preserved as part of the source dataset semantics but is not treated as completed historical transactions. It is not used for historical KPIs, reorder rates, basket KPIs, or customer behavior claims, and it is not converted into completed transactions.

---

## 3. Core Executive KPIs

| KPI | Definition | Formula | Grain | Validated Value |
|---|---|---|---|---:|
| Total Orders | Distinct customer orders in the PRIOR population | `COUNT(DISTINCT order_id)` | Order | 3,214,874 |
| Total Customers | Distinct customers in the PRIOR population | `COUNT(DISTINCT user_id)` | Customer | 206,209 |
| Total Items Purchased | Product records associated with PRIOR orders (one row per order-product record) | `COUNT(order-product records)` | Order-product | 32,434,489 |
| Reordered Items | Item records where `reordered = 1` | `COUNT(item records WHERE reordered = 1)` | Order-product | 19,126,536 |
| First-Time Items | Item records where `reordered = 0` | `COUNT(item records WHERE reordered = 0)` | Order-product | 13,307,953 |
| Purchased Products | Distinct products in the PRIOR purchased-item population | `COUNT(DISTINCT product_id)` | Product | 49,677 |

**Business use**

- **Total Orders** — foundational KPI for executive reporting, basket-size calculations, order-frequency analysis, time-based analysis, and Market Basket support calculations.
- **Total Customers** — supports frequency analysis, segmentation, orders-per-customer analysis, and reorder behavior analysis.
- **Total Items Purchased** — denominator for the overall reorder rate and numerator for average basket size.
- **Reordered / First-Time Items** — measure repeat purchasing volume and validate the overall item population.
- **Purchased Products** — measures the breadth of products in the primary purchasing population.

**Item reconciliation**

```text
Reordered Items + First-Time Items = Total Items Purchased
19,126,536 + 13,307,953 = 32,434,489
```

**Catalog vs. purchased products**

```text
49,688 source catalog products
− 49,677 PRIOR purchased products
=     11 catalog products not purchased in PRIOR
```

---

## 4. Basket KPIs

### 4.1 Basket Size

**Definition:** The number of product-item records in an individual order.

```text
Basket Size = COUNT(product records within the order)
```

**Grain:** Order

**Example:** An order containing Bananas, Milk, Bread, and Eggs has a Basket Size of 4.

**Supports:** average basket analysis, basket-size distribution, customer shopping behavior, basket composition, and cross-selling and recommendation analysis.

### 4.2 Average Basket Size

**Definition:** The average number of purchased product records per order.

```text
Average Basket Size = Total Items Purchased / Total Orders
                    = 32,434,489 / 3,214,874
                    = 10.088883...
```

| Item | Value |
|---|---|
| Dashboard display | **10.09 items per order** |
| Grain | Order-level basket size |

**Interpretation:** The PRIOR order population contains approximately ten product-item records per order on average. The metric is based on order-product records, so it does not mean ten unique product types in every basket.

### 4.3 Basket Size Distribution

**Definition:** The frequency of orders across different basket-size values.

```text
For each basket size: COUNT(orders having that basket size)
```

| Item | Value |
|---|---|
| Validated output | 113 basket-size records/categories |
| Grain | Basket-size category |

**Supports:** small vs. large basket analysis, shopping behavior, basket concentration, and distribution of order sizes.

**Interpretation rule:** `113` is the number of categories in the distribution output. It must not be described as "Maximum basket size = 113".

---

## 5. Reorder KPIs

### 5.1 Reorder KPI Framework

Reorder KPIs measure repeat purchasing behavior using the `reordered` indicator in the source data.

```text
Reorder Rate = Reordered Item Records / Total Item Records × 100
```

### 5.2 Reorder KPI Summary

| KPI | Formula | Grain | Validated Value |
|---|---|---|---|
| Overall Reorder Rate | `19,126,536 / 32,434,489 × 100` | Order-product | 58.969746...% (dashboard: **58.97%**) |
| Product Reorder Rate | `Product Reordered Items / Product Total Item Records × 100` | Product | — |
| Department Reorder Rate | `Department Reordered Items / Department Total Item Records × 100` | Department | Dairy Eggs: **67.00%** |
| Aisle Reorder Rate | `Aisle Reordered Items / Aisle Total Item Records × 100` | Aisle | — |

The overall reorder rate provides the repeat-purchase benchmark for the primary analytical population. Product, department, and aisle reorder rates compare repeat purchasing behavior at each level.

### 5.3 Interpretation Rules

- A higher reorder rate indicates a greater proportion of item records associated with repeat purchasing, within the source dataset's `reordered` definition.
- It does not establish customer loyalty in a CRM sense, retention, churn prevention, revenue impact, profitability, product quality, customer satisfaction, stockout, or inventory conditions.
- Product, department, and aisle reorder rates must be read together with purchase volume. A high reorder rate on very low volume is not automatically a stronger opportunity than a high-volume product with a slightly lower rate.

---

## 6. Customer KPIs

Customer KPIs are calculated at customer grain using the PRIOR population.

### 6.1 Orders per Customer

```text
Orders per Customer = COUNT(DISTINCT order_id) for each customer
```

**Grain:** Customer

**Purpose:** Understand order frequency and distinguish lower- and higher-frequency purchasing behavior.

### 6.2 Customer Purchase Frequency

**Definition:** The number of orders associated with each customer, represented operationally by the customer's order count.

```text
Customer Purchase Frequency = Customer Order Count
```

**Grain:** Customer

**Supports:** customer segmentation, frequency analysis, high-frequency customer identification, and behavioral comparison.

**Interpretation:** This is a behavioral frequency measure, not conventional monetary RFM, because the dataset has no customer-level monetary information.

### 6.3 Customer Behavioral Segmentation

**Definition:** Customers are classified by two behavioral dimensions derived from validated analytical data:

```text
Order Frequency + Reorder Behavior
```

| Item | Value |
|---|---|
| Segment combinations | 9 |
| Reconciled customer total | 206,209 |
| Grain | Customer |

Displayed segment percentages may sum to 99.99% because of rounding; the underlying customer counts reconcile exactly to 206,209.

**Purpose:** Identify distinct customer behavioral patterns, including high-frequency / high-reorder customers.

### 6.4 High-Frequency / High-Reorder Segment

**Definition:** Customers in the highest defined behavioral categories for both Order Frequency and Reorder Behavior.

| Item | Value |
|---|---:|
| Customers | **49,610** |
| Share of PRIOR customers (206,209) | **~24.06%** |

**Business meaning:** A substantial group of customers shows both frequent ordering and strong repeat-product purchasing.

**Potential business actions**

- Personalized reorder shortcuts
- Reorder recommendations
- Relevant repeat-purchase suggestions
- Loyalty-oriented engagement
- Convenience-focused customer experiences

**Recommended supporting KPIs:** Orders per Customer and Reorder Rate.

**Limitations:** This segment must not be interpreted as guaranteed loyal customers, high-value customers in monetary terms, high-profitability customers, or customers who will churn without intervention. The dataset has no revenue, profit, demographic, or confirmed churn data.

---

## 7. Time-Based KPIs

Time-based KPIs describe order activity by day, hour, and day-hour combination, and show ordering patterns and temporal demand concentration.

| KPI | Formula | Grain | Validated Output |
|---|---|---|---:|
| Orders by Day | `COUNT(DISTINCT order_id) GROUP BY day_of_week` | Day | 7 rows |
| Orders by Hour | `COUNT(DISTINCT order_id) GROUP BY hour_of_day` | Hour (00–23) | 24 rows |
| Day-Hour Order Activity | `COUNT(DISTINCT order_id) GROUP BY day_of_week, hour_of_day` | Day-hour (7 × 24) | 168 rows |

**Grain rule:** The 24-row hour output and the 168-row day-hour output represent different analytical grains and do not contradict each other.

```text
Orders by Hour     → 24 categories
Orders by Day-Hour → up to 168 combinations
```

---

## 8. Product KPIs

Product KPIs evaluate purchasing activity and repeat purchasing behavior at product level.

### 8.1 Product Purchase Count

```text
Product Purchase Count = COUNT(product item records) GROUP BY product_id
```

| Item | Value |
|---|---|
| Grain | Product |
| Validated example | Banana: **472,565** |

Product Purchase Count measures historical product demand as item-record volume. It is not revenue, profit, monetary value, or customer lifetime value.

### 8.2 Product Performance

**Definition:** Product-level purchase activity combined with reorder behavior.

**Key measures:** Purchase Count, Reordered Item Count, First-Time Item Count, Reorder Rate.

| Item | Value |
|---|---|
| Grain | Product |
| Validated product population | 49,677 purchased products |

Supports product ranking and comparison based on observed historical purchase and reorder behavior.

---

## 9. Department KPIs

Department KPIs aggregate product-level activity to department level.

### 9.1 Department Purchase Count

```text
Department Purchase Count = COUNT(item records) GROUP BY department
```

| Item | Value |
|---|---:|
| Validated department population | 21 |
| Produce | 9,479,291 purchases |
| Dairy Eggs | 5,414,016 purchases |

### 9.2 Department Reorder Rate

```text
Department Reorder Rate = Department Reordered Items / Department Total Item Records × 100
```

**Validated example — Dairy Eggs:** Purchase Count = 5,414,016; Reorder Rate = **67.00%**

### 9.3 Department Performance

**Definition:** Department purchase volume combined with reorder behavior.

**Key measures:** Purchase Count, Reordered Item Count, First-Time Item Count, Reorder Rate.

**Business meaning:** Dairy Eggs combines substantial purchase volume with a high observed reorder rate, making it relevant for availability-focused planning, replenishment prioritization, repeat-purchase convenience, and merchandising analysis.

**Limitation:** Department performance does not establish revenue, profitability, margin, inventory availability, or stockouts, because these data are not in the source dataset. The project must not state that a department has stockouts or shortages based on these KPIs.

---

## 10. Aisle KPIs

Aisle KPIs provide a more granular category view below department level.

| KPI | Formula | Grain | Validated Value |
|---|---|---|---:|
| Aisle Purchase Count | `COUNT(item records) GROUP BY aisle` | Aisle | 134 aisles |
| Aisle Reorder Rate | `Aisle Reordered Items / Aisle Total Item Records × 100` | Aisle | — |

**Purpose:** Identify high- and lower-volume purchasing areas within departments and compare repeat purchasing behavior across aisles. Aisle reorder rate must be read together with aisle purchase volume.

---

## 11. Market Basket KPIs

Market Basket Analysis identifies product combinations that frequently occur together in the same order. It identifies associations, not causal relationships.

### 11.1 Product Universe

**Definition:** The controlled set of products used for pairwise association analysis.

| Item | Value |
|---|---|
| Top N products | 100 |
| Grain | Selected product |

The top-100 universe is an analytical control that reduces computational complexity and keeps the analysis focused on the most relevant products. It does not mean only 100 products exist: the source catalog has 49,688 products, the PRIOR purchased population has 49,677, and the analysis uses 100 selected products.

### 11.2 Pair Orders

```text
Pair Orders = COUNT(DISTINCT order_id containing both Product A and Product B)
```

**Grain:** Product pair

### 11.3 Minimum Pair-Order Threshold

| Item | Value |
|---|---|
| Minimum Pair Orders | 100 |

The threshold reduces the influence of very rare combinations. Pairs below the threshold are excluded from the final association output.

### 11.4 Support, Confidence, and Lift

| Metric | Formula | Validated Range / Rule |
|---|---|---|
| Support | `Support(A,B) = Pair Orders(A,B) / Total Analyzed Orders` | 0 ≤ Support ≤ 1 |
| Confidence | `Confidence(A → B) = Support(A,B) / Support(A)` | Valid percentage; directional |
| Lift | `Lift(A → B) = Confidence(A → B) / Support(B)` | Lift > 0; Lift > 1 means co-occurrence above the independence baseline |

- **Support** indicates how prevalent a product pair is across analyzed orders.
- **Confidence** is directional: Confidence(A → B) does not necessarily equal Confidence(B → A).
- **Lift** compares observed co-occurrence with the expected co-occurrence under independence.

### 11.5 Strongest Observed Pair

| Item | Value |
|---|---|
| Product pair | Sparkling Lemon Water + Lime Sparkling Water |
| Orders together | **8,546** |
| Lift | **18.0024** |

This pair shows a strong observed association within the analyzed basket population and serves as the known regression-check pair.

**Potential business applications:** complementary product recommendations, cart-level recommendations, cross-selling experiments, product placement tests, and bundle testing.

**Limitation:** Association does not prove causation, and it does not establish incremental revenue, profit impact, conversion improvement, or customer preference causality. Recommendations should be framed as opportunities to test.

Appropriate wording: *"Product A and Product B show a strong observed association in the analyzed orders."* The project must not state that buying Product A causes customers to buy Product B.

### 11.6 Output Controls

| Control | Value |
|---|---:|
| Top product universe | 100 products |
| Minimum pair orders | 100 |
| Maximum output rows | 500 |

**Validation rules**

- Product A < Product B
- No duplicate product pairs
- Support between 0 and 1
- Confidence valid
- Lift > 0
- Minimum pair orders ≥ 100

---

## 12. Purchase Gap KPIs

Purchase-gap analysis measures the interval between consecutive customer orders where a previous-order interval is available.

### 12.1 Purchase Gap

**Definition:** The number of days between consecutive customer orders, derived from the order-level interval information (`days_since_prior_order`).

**Grain:** Order / customer interval

**Data rule:** First orders have no previous-order interval, so the first-order purchase gap is `NULL`. These NULL values must not be converted to zero.

### 12.2 Weighted Average Purchase Gap

**Definition:** The average observed purchase interval, excluding records where a previous interval is unavailable.

| Item | Value |
|---|---|
| Validated result | **10.71 days** |

**Limitation:** Purchase gap is a behavioral timing metric. It must not be interpreted as a guaranteed reorder cycle, retention period, churn threshold, revenue forecast, or customer lifetime value. No confirmed churn model exists in this project.

---

## 13. KPI Reconciliation

| Reconciliation | Calculation | Result |
|---|---|---|
| Item reconciliation | `19,126,536 + 13,307,953 = 32,434,489` | PASS |
| Reorder rate | `19,126,536 / 32,434,489 × 100 = 58.969746...%` (display: 58.97%) | PASS |
| Average basket size | `32,434,489 / 3,214,874 = 10.088883...` (display: 10.09) | PASS |
| Customer segmentation | Segment totals reconcile to 206,209 customers | PASS |

**Source catalog vs. purchased products:** 49,688 catalog products − 49,677 PRIOR purchased products = 11 products. This is not a data-quality error; these catalog products do not appear in the PRIOR purchased-item population.

---

## 14. Power BI KPI Governance

Power BI is the presentation and interactive analysis layer. Its model must use validated analytical data rather than redefining the underlying business logic.

### 14.1 Validated Control Values

| Control KPI | Value |
|---|---:|
| Total Orders | 3,214,874 |
| Total Customers | 206,209 |
| Total Items | 32,434,489 |
| Reordered Items | 19,126,536 |
| First-Time Items | 13,307,953 |
| Reorder Rate | 58.97% |
| Average Basket | 10.09 |

### 14.2 Governance Rules

1. DAX must follow the approved KPI definitions.
2. Dashboard labels must match KPI definitions.
3. KPI values must reconcile with PostgreSQL and Python validation.
4. Filters must not unintentionally alter executive control metrics.
5. Relationship changes must be validated before KPI approval.
6. Duplicate dimension values must be prevented where uniqueness is required.
7. Hour-level and day-hour-level grains must not be confused.
8. Display rounding must not alter the underlying analytical calculation.
9. Dashboard business claims must remain within the dataset's evidence.
10. KPI changes must be reconciled across SQL, Python, and Power BI before publication.

---

## 15. Rounding and Display Rules

The project distinguishes between the **exact analytical result** and the **dashboard display value**. The underlying analytical value always remains the validated value.

| KPI | Exact Analytical Result | Dashboard Display |
|---|---|---|
| Overall Reorder Rate | 58.969746...% | 58.97% |
| Average Basket Size | 10.088883... | 10.09 |
| Dairy Eggs Reorder Rate | — | 67.00% |
| Market Basket Lift | 18.0024 | May be rounded where appropriate |

Displayed percentages may total slightly below 100% (for example, customer segments at 99.99%) when the underlying counts reconcile correctly.

---

## 16. KPI Interpretation Rules

| # | Rule | Description |
|---|---|---|
| 1 | Do not over-claim | KPIs describe only what the source data and methodology support. |
| 2 | No revenue claims | The dataset has no reliable transaction-level monetary values, so no revenue, profit, margin, or customer monetary value is claimed. |
| 3 | No conventional monetary RFM | Segmentation is based on behavioral dimensions, not monetary value. |
| 4 | No demographic claims | The dataset has no customer demographic information. |
| 5 | No confirmed churn claims | Purchase gap ≠ churn; low frequency ≠ churn; low reorder rate ≠ churn. |
| 6 | No stockout claims | High purchase volume or reorder rate does not prove inventory availability or stockout conditions; no inventory dataset exists. |
| 7 | Association is not causation | Market Basket Analysis shows observed associations only. |
| 8 | Preserve source semantics | The `missing` department is a legitimate source category. It must not be deleted, renamed, reassigned, converted into an invented category, or treated as a failed mapping. The product-to-department mapping was validated successfully. |
| 9 | Do not mix populations | PRIOR, TRAIN, and TEST have different roles and must not be combined without a documented analytical reason. |
| 10 | Respect analytical grain | Each KPI is interpreted at its defined grain (see below). |

**Grain reference**

| KPI Type | Grain |
|---|---|
| Order KPI | Order |
| Customer KPI | Customer |
| Product KPI | Product |
| Department KPI | Department |
| Aisle KPI | Aisle |
| Pair KPI | Product pair |
| Day KPI | Day |
| Hour KPI | Hour |
| Day-hour KPI | Day-hour |

---

## 17. KPI Source-of-Truth Hierarchy

```text
1. PostgreSQL Analytical Layer
            ↓
2. Python Validation & Reconciliation
            ↓
3. Power BI Analytical Model
            ↓
4. DAX Measures
            ↓
5. Dashboard Presentation
            ↓
6. Business Recommendations
```

| Level | Role |
|---|---|
| 1 — PostgreSQL | Primary analytical calculations and structured analytical tables; the foundational layer. |
| 2 — Python | Independent validation of row counts, KPI values, customer segmentation, Market Basket results, data integrity, and SQL ↔ Python reconciliation. It validates the SQL layer and does not replace it. |
| 3 — Power BI Model | Imports validated analytical outputs and provides the governed semantic model. |
| 4 — DAX | Interactive reporting calculations, consistent with the approved KPI definitions. |
| 5 — Dashboard | Presents validated metrics to the business audience without introducing unsupported claims. |
| 6 — Business Recommendations | Derived from validated KPI patterns and limited to the evidence the dataset supports. |

---

## 18. KPI QA Status

| QA Stage | Status | Validated Areas |
|---|---|---|
| Source QA | PASS | Row counts, primary/composite key uniqueness, order-product duplicate-key checks, product-to-aisle and product-to-department mapping, evaluation-set integrity, expected NULL behavior |
| Clean-Layer QA | PASS | Controlled text cleaning, preservation of legitimate NULLs and source semantics, product hierarchy mappings, no uncontrolled row deletion |
| SQL Analytical QA | PASS | Analytical objects and KPI controls (see below) |
| SQL ↔ Python Reconciliation | PASS | 23 checks, 0 failures |
| Python Analytical Validation | PASS | 27 checks, 0 failures |
| Power BI Model QA | PASS | Relationship structure, cardinality, dimension uniqueness, table loading, KPI reconciliation, time dimension and hour-level modeling, legitimate `missing` department preservation |
| DAX QA | PASS | Orders, Customers, Items, Reordered Items, First-Time Items, Reorder Rate, Average Basket Size |
| Final Dashboard QA | PASS | KPI accuracy, visual consistency, analytical labels, business interpretation, page structure, cross-layer KPI reconciliation |

**SQL analytical QA controls**

| Control | Value |
|---|---:|
| PRIOR Orders | 3,214,874 |
| PRIOR Customers | 206,209 |
| PRIOR Items | 32,434,489 |
| PRIOR Reordered Items | 19,126,536 |
| PRIOR First-Time Items | 13,307,953 |
| Purchased Products | 49,677 |
| Average Basket Size | 10.09 |
| Overall Reorder Rate | 58.97% |

**Market Basket validation**

| Control | Value |
|---|---:|
| Streamed analytical rows | 7,483,881 |
| Qualifying pairs | 4,945 |
| Final output limit | 500 |
| Known regression pair (orders together) | 8,546 |
| Known lift | 18.0024 |

---

## 19. Final Validated KPI Reference

| KPI | Analytical Grain | Validated Value |
|---|---|---:|
| Total Orders | Order | 3,214,874 |
| Total Customers | Customer | 206,209 |
| Total Items Purchased | Order-product | 32,434,489 |
| Reordered Items | Order-product | 19,126,536 |
| First-Time Items | Order-product | 13,307,953 |
| Purchased Products | Product | 49,677 |
| Source Catalog Products | Product | 49,688 |
| Average Basket Size | Order | 10.09 |
| Basket Distribution Records | Basket-size category | 113 |
| Overall Reorder Rate | Order-product | 58.97% |
| Produce Purchase Count | Department | 9,479,291 |
| Dairy Eggs Purchase Count | Department | 5,414,016 |
| Dairy Eggs Reorder Rate | Department | 67.00% |
| Banana Purchase Count | Product | 472,565 |
| Department Count | Department | 21 |
| Aisle Count | Aisle | 134 |
| Customer Segment Combinations | Segment | 9 |
| High-Frequency / High-Reorder Customers | Customer segment | 49,610 |
| High-Frequency / High-Reorder Customer Share | Customer segment | ~24.06% |
| Orders by Day Records | Day | 7 |
| Orders by Hour Records | Hour | 24 |
| Day-Hour Records | Day-hour | 168 |
| Weighted Average Purchase Gap | Order interval | 10.71 days |
| Market Basket Product Universe | Product | 100 |
| Minimum Pair Orders | Product pair | 100 |
| Market Basket Maximum Output | Product pair | 500 |
| Strongest Observed Pair Orders | Product pair | 8,546 |
| Strongest Observed Pair Lift | Product pair | 18.0024 |

---

## 20. Final KPI Governance Statement

The KPIs in this document are the validated analytical definitions and results for the completed Instacart Online Grocery Basket Analysis project. The following principles are mandatory:

1. PRIOR remains the primary historical analysis set.
2. TRAIN remains a reference/validation dataset.
3. TEST is not treated as completed historical transactions.
4. KPI values must remain reconciled across SQL, Python, and Power BI.
5. The `missing` department remains legitimate source data.
6. No revenue or profit claims are made.
7. No conventional monetary RFM is claimed.
8. No demographic conclusions are made.
9. No confirmed churn conclusions are made.
10. No inventory or stockout conclusions are made.
11. Market Basket Analysis represents association, not causation.
12. KPI interpretation must respect the analytical grain.
13. Exact analytical values must be distinguished from rounded dashboard displays.
14. Business recommendations must be supported by validated KPI evidence.
15. No fabricated, estimated, or unverified KPI values may be added to the project.
