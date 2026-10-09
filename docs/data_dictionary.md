# Data Dictionary

## 1. Purpose

This document defines the principal source, cleaned, and analytical data structures used in the Instacart Online Grocery Basket Analysis project.

The project uses the original Kaggle Instacart dataset as the source layer and PostgreSQL as the primary analytical database.

## 2. Source Dataset

**Dataset:** Instacart Online Grocery Basket Analysis Dataset  
**Source:** Kaggle  
**Author:** yasserh

Source files:

- `aisles.csv`
- `departments.csv`
- `products.csv`
- `orders.csv`
- `order_products__prior.csv`
- `order_products__train.csv`

## 3. Source Tables

### 3.1 `aisles`

Product aisle master table.

| Column | Description |
|---|---|
| `aisle_id` | Unique identifier for an aisle |
| `aisle` | Aisle name |

**Grain:** One row per aisle.

Validated row count: **134**

---

### 3.2 `departments`

Product department master table.

| Column | Description |
|---|---|
| `department_id` | Unique identifier for a department |
| `department` | Department name |

**Grain:** One row per department.

Validated row count: **21**

> Note: `missing` is a legitimate source department value and is preserved as source data.

---

### 3.3 `products`

Product master/catalog table.

| Column | Description |
|---|---|
| `product_id` | Unique product identifier |
| `product_name` | Product name |
| `aisle_id` | Foreign-key reference to `aisles` |
| `department_id` | Foreign-key reference to `departments` |

**Grain:** One row per product.

Validated row count: **49,688**

---

### 3.4 `orders`

Order-level customer and order-sequence table.

| Column | Description |
|---|---|
| `order_id` | Unique order identifier |
| `user_id` | Customer identifier |
| `eval_set` | Dataset assignment such as prior, train, or test |
| `order_number` | Sequential order number for the customer |
| `order_dow` | Day of week on which the order was placed |
| `order_hour_of_day` | Hour of day on which the order was placed |
| `days_since_prior_order` | Days since the customer's previous order |

**Grain:** One row per order.

Validated row count: **3,421,083**

### NULL handling

`days_since_prior_order` contains expected NULL values for first orders.

These NULLs are preserved because they represent the absence of a previous order rather than a data-quality failure.

---

### 3.5 `order_products__prior`

Products purchased in customers' prior orders.

| Column | Description |
|---|---|
| `order_id` | Order identifier |
| `product_id` | Product identifier |
| `add_to_cart_order` | Position of the product in the customer's basket |
| `reordered` | Indicates whether the product had been purchased previously by the customer |

**Grain:** One row per product within an order.

Validated row count: **32,434,489**

---

### 3.6 `order_products__train`

Products associated with the training/evaluation order set.

| Column | Description |
|---|---|
| `order_id` | Order identifier |
| `product_id` | Product identifier |
| `add_to_cart_order` | Position of the product in the basket |
| `reordered` | Reorder indicator |

**Grain:** One row per product within an order.

Validated row count: **1,384,617**

---

# 4. Controlled Clean Layer

The project creates controlled cleaned tables under the `analytics` schema.

| Clean Table | Purpose |
|---|---|
| `analytics.clean_aisles` | Cleaned aisle master |
| `analytics.clean_departments` | Cleaned department master |
| `analytics.clean_products` | Cleaned product master |
| `analytics.clean_orders` | Cleaned order data |
| `analytics.clean_order_products_prior` | Cleaned prior-order product data |
| `analytics.clean_order_products_train` | Cleaned train-order product data |

Cleaning rules include:

- Trimming text values
- Converting blank text values to NULL
- Standardizing `eval_set` using lowercase and trimming
- Preserving legitimate NULL values
- Preserving source department `missing`
- Preserving source row counts
- Preserving source hierarchy relationships

No artificial `unknown` or `missing` labels were introduced.

---

# 5. Analytical Layer

The analytical layer contains business-ready tables used by Python and Power BI.

| Analytical Object | Purpose |
|---|---|
| `analytics.enriched_order_product_prior` | Enriched prior-order product-level analysis |
| `analytics.order_basket_summary` | Basket-level metrics |
| `analytics.reorder_summary` | Overall reorder metrics |
| `analytics.orders_by_day` | Order activity by day of week |
| `analytics.orders_by_hour` | Order activity by hour |
| `analytics.orders_by_day_hour` | Day/hour order activity |
| `analytics.basket_size_distribution` | Basket-size distribution |
| `analytics.reorder_by_sequence` | Reorder behavior by order sequence |
| `analytics.product_performance` | Product purchase and reorder performance |
| `analytics.department_performance` | Department-level performance |
| `analytics.aisle_performance` | Aisle-level performance |
| `analytics.customer_behavior` | Customer-level behavioral metrics |
| `analytics.customer_frequency` | Customer order-frequency analysis |
| `analytics.customer_purchase_gap_distribution` | Purchase-gap distribution |
| `analytics.market_basket_product_universe` | Controlled product universe for basket analysis |

---

# 6. Key Analytical Grain

The project deliberately uses multiple analytical grains.

### Order grain

Used for:

- Order counts
- Order timing
- Basket analysis
- Customer order frequency

### Order-product grain

Used for:

- Product purchases
- Reorders
- Basket composition
- Market basket analysis

### Customer grain

Used for:

- Customer behavior
- Order frequency
- Reorder behavior
- Behavioral segmentation

### Product grain

Used for:

- Product purchase volume
- Product reorder rate

### Department grain

Used for:

- Department purchase volume
- Department reorder rate

### Aisle grain

Used for:

- Aisle purchase volume
- Aisle performance

---

# 7. Power BI Analytical Tables

The Power BI model uses validated analytical outputs rather than directly connecting the dashboard to the raw CSV layer.

Principal model entities include:

- `DimCustomer`
- `DimProduct`
- `DimAisle`
- `DimDepartment`
- `DimOrderDay`
- `DimOrderHour`
- `FactOrderBehavior`
- `FactCustomerBehavior`
- `FactProductPerformance`
- `FactDepartmentPerformance`
- `FactAislePerformance`
- `FactOrdersByDay`
- `FactOrdersByHour`
- `FactReorderSummary`
- `FactBasketAssociation`

The Power BI model was subjected to relationship, cardinality, model, DAX, and dashboard QA.

---

# 8. Data Semantics and Limitations

The following interpretations are intentionally preserved:

- `PRIOR` is the primary historical analysis set.
- `TRAIN` is used as a reference/validation dataset.
- `TEST` is not treated as completed historical transactions.
- `reordered` represents product reorder behavior, not customer churn.
- The dataset does not provide revenue or profit information.
- Demographic information is not available.
- Conventional monetary RFM cannot be calculated from the supplied data.
- `missing` is a legitimate source department.
- Market basket association does not establish causation.

This dictionary describes the structures actually used in the project and does not introduce unsupported business fields or assumptions.
