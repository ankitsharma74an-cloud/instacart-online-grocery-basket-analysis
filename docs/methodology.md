# Methodology

## 1. Project Objective

The objective of this project is to analyse historical grocery-order behaviour from the Instacart Online Grocery Basket Analysis dataset and translate the findings into actionable business insights.

The analytical workflow was designed around:

- Customer purchasing behaviour
- Product performance
- Department and aisle performance
- Reorder behaviour
- Order timing
- Basket composition
- Market basket associations
- Business recommendations

---

# 2. End-to-End Analytical Workflow

```text
Business Problem
      ↓
Data Understanding
      ↓
Source Data Validation
      ↓
PostgreSQL Source Layer
      ↓
Controlled SQL Cleaning
      ↓
Clean-Layer QA
      ↓
SQL Analytical Layer
      ↓
SQL Analytical QA
      ↓
Python EDA & Statistical Analysis
      ↓
Market Basket Analysis
      ↓
SQL ↔ Python Reconciliation
      ↓
Power BI Data Model
      ↓
Power BI Model QA
      ↓
DAX Measures & DAX QA
      ↓
Dashboard QA
      ↓
Business Recommendations
```

---

# 3. Data Source

The project uses the Kaggle Instacart Online Grocery Basket Analysis dataset.

The original six files are retained in the raw data/ directory.

The raw files are treated as the source layer and are not overwritten by downstream transformations.

---

# 4. Data Understanding

The dataset contains information about:

- Customers
- Orders
- Products
- Product aisles
- Product departments
- Products added to orders
- Reorder indicators
- Order timing
- Customer order sequence

The project uses the relationships among these entities to construct an analytical model.

---

# 5. Analytical Dataset Selection

### PRIOR

PRIOR is the primary historical analysis population because it represents completed prior-order activity.

It is used for:

- Customer behavior
- Product performance
- Reorder analysis
- Department analysis
- Aisle analysis
- Basket analysis
- Time analysis

### TRAIN

TRAIN is retained as a reference/validation dataset.

It is not combined with PRIOR simply to inflate the primary analytical population.

### TEST

TEST is not treated as completed historical transaction data.

This prevents unsupported interpretation of the evaluation dataset.

---

# 6. PostgreSQL Data Pipeline

The SQL workflow is organised into controlled stages.

### Stage 1 — Source Tables

Source CSV files are loaded into PostgreSQL.

### Stage 2 — Source QA

Source-level checks validate:

- Row counts
- Keys
- Duplicate records
- Product hierarchy mappings
- Dataset labels
- Expected NULL values

### Stage 3 — Controlled Cleaning

The clean layer applies controlled transformations:

- TRIM() for text
- Blank text converted to NULL
- LOWER(TRIM(eval_set))
- Preservation of legitimate NULLs
- Preservation of source hierarchy
- No arbitrary row deletion

### Stage 4 — Clean-Layer QA

Cleaned data is reconciled against source data.

### Stage 5 — Analytical Layer

Business-ready analytical tables are created for:

- Orders
- Baskets
- Customers
- Products
- Departments
- Aisles
- Reorders
- Time patterns
- Market basket analysis

### Stage 6 — Analytical QA

Analytical objects are validated against expected controls.

---

# 7. Data Integrity Decision: missing Department

The source dataset contains a department named missing.

Validation established that this is a legitimate source category.

Therefore:

- It is retained.
- Products mapped to it remain mapped to it.
- It is not deleted.
- It is not renamed to unknown.
- It is not treated as a mapping failure.

This preserves source semantics.

---

# 8. Python EDA and Validation

Python is used after the SQL analytical layer has been established.

The Python workflow performs:

- Exploratory data analysis
- KPI validation
- Customer behavioural analysis
- Product and department analysis
- Time analysis
- Market basket analysis
- Statistical/analytical validation
- SQL ↔ Python reconciliation

Python does not replace SQL as the controlled analytical source.

Instead, it independently validates and explores the prepared analytical layer.

---

# 9. Market Basket Analysis

Market basket analysis identifies products that occur together within orders.

To control computational complexity and analytical interpretation:

- A controlled top-100 product universe is used.
- Minimum qualifying pair orders = 100.
- Duplicate pairs are removed.
- Product pairs are standardised.
- Support, confidence, and lift are calculated.
- Output is controlled for portfolio/dashboard usability.

The analysis identifies associations rather than causal relationships.

---

# 10. Power BI Methodology

Power BI consumes validated analytical outputs.

The model contains dimension and fact-style entities for:

- Customers
- Products
- Aisles
- Departments
- Order day
- Order hour
- Orders
- Customer behaviour
- Product performance
- Department performance
- Aisle performance
- Reorder behaviour
- Basket associations

The model was validated before dashboard development.

---

# 11. DAX Methodology

DAX measures are used for dashboard-level calculations and KPI presentation.

Measures are validated against SQL/Python control values.

Key validation metrics include:

- Orders
- Customers
- Items
- Reordered items
- First-time items
- Reorder rate
- Average basket size

---

# 12. Dashboard Structure

The analytical dashboard contains four primary analytical pages:

1. Executive Overview
2. Customer Behaviour
3. Product & Department Performance
4. Market Basket & Recommendations

A separate Business Recommendations presentation asset is also maintained for the repository.

---

# 13. Quality Assurance Framework

The project uses a multi-stage QA framework.

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

QA is treated as part of the analytical workflow rather than a final cosmetic check.

---

# 14. Analytical Integrity Rules

The following rules govern interpretation:

- No revenue or profit claims.
- No demographic claims.
- No conventional monetary RFM.
- No confirmed churn claims.
- No unsupported stockout claims.
- Reorder behavior is not equivalent to churn prevention.
- Market basket association is not causation.
- Source semantics are preserved.
- Rounded dashboard values are not treated as underlying precision.
- Results must reconcile across SQL, Python, and Power BI.

---

# 15. Business Interpretation

The analysis focuses on actionable areas supported by the available data:

- Replenishment and reorder behaviour
- High-frequency/high-reorder customers
- Department performance
- Product performance
- Basket associations
- Order timing

Recommendations are restricted to evidence available in the dataset.

---

# 16. Reproducibility

The project is organised so that the workflow can be reproduced through:

1. Source CSV files
2. PostgreSQL source-table creation
3. Data loading
4. Source QA
5. Controlled cleaning
6. Clean-layer QA
7. Analytical-layer creation
8. Analytical QA
9. Python EDA and validation
10. Power BI model
11. DAX measures
12. Dashboard outputs
