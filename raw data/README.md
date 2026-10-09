# Raw Data

This folder contains the six original CSV files used for the Instacart Online Grocery Basket Analysis project.

## Dataset Source

- **Dataset:** Instacart Online Grocery Basket Analysis Dataset
- **Source:** Kaggle
- **Dataset Author:** yasserh
- **Source:** https://www.kaggle.com/datasets/yasserh/instacart-online-grocery-basket-analysis-dataset

The files in this folder are retained as the project's source-data layer. They are not overwritten by SQL cleaning or analytical transformations.

## Source Files

| File | Description | Key / Grain |
|---|---|---|
| `aisles.csv` | Product aisle master data | `aisle_id` |
| `departments.csv` | Product department master data | `department_id` |
| `products.csv` | Product master/catalog data with aisle and department mappings | `product_id` |
| `orders.csv` | Order-level customer and order-sequence information | `order_id` |
| `order_products__prior.csv` | Products purchased in customers' prior orders | `order_id` + `product_id` |
| `order_products__train.csv` | Products associated with the training/evaluation order set | `order_id` + `product_id` |

## Role in the Project

The six source files are loaded into PostgreSQL source tables and then processed through a controlled cleaning layer before analytical tables are created.

```text
Raw Kaggle CSVs
      ↓
PostgreSQL Source Tables
      ↓
Source QA
      ↓
Controlled Clean Layer
      ↓
Clean-Layer QA
      ↓
Analytical Layer
      ↓
Python Validation & EDA
      ↓
Power BI Model & Dashboard
      ↓
Business Recommendations
```
