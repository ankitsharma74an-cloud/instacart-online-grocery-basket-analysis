from __future__ import annotations

from collections import Counter
from datetime import datetime
from getpass import getpass
from itertools import combinations
from pathlib import Path
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import psycopg2
from scipy.stats import spearmanr

# ============================================================
# INSTACART ONLINE GROCERY BASKET ANALYSIS
# PYTHON EDA V2 — BUILT ONLY ON VALIDATED SQL ANALYTICAL OUTPUTS
# ============================================================
# Architectural rule:
#   public.*                 -> NEVER READ BY THIS SCRIPT
#   analytics.clean_*        -> not used for EDA calculations
#   analytics.* analytical  -> ONLY INPUT TO PYTHON
#
# Python responsibilities:
#   - EDA
#   - descriptive/statistical exploration
#   - customer behavioral segmentation
#   - outlier analysis
#   - reorder opportunity candidates
#   - Market Basket Association Analysis
#   - SQL-output validation
#   - final analytical validation
#
# Power BI responsibilities come AFTER this script passes.
# ============================================================

# ------------------------- CONFIG ----------------------------
DB_HOST = "localhost"
DB_PORT = 5432
DB_USER = "postgres"
DB_NAME = "instacart_analytics"

ANALYSIS_SET = "prior"
BASKET_TOP_N = 100
MIN_PAIR_ORDERS = 100
MAX_ASSOCIATIONS = 500
MIN_REORDER_PRODUCT_PURCHASES = 1000

# Fixed control totals from the validated SQL analytical layer.
CONTROL = {
    "prior_orders": 3_214_874,
    "prior_customers": 206_209,
    "prior_items": 32_434_489,
    "prior_reordered_items": 19_126_536,
    "prior_first_time_items": 13_307_953,
    "prior_purchased_products": 49_677,
    "day_rows": 7,
    "hour_rows": 24,
    "basket_distribution_rows": 113,
    "reorder_sequence_rows": 99,
    "product_rows": 49_677,
    "department_rows": 21,
    "aisle_rows": 134,
    "customer_rows": 206_209,
    "basket_universe_rows": 100,
}

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "outputs" / "python_eda_v2"
CSV_DIR = OUTPUT_DIR / "csv"
CHART_DIR = OUTPUT_DIR / "charts"
REPORT_DIR = OUTPUT_DIR / "reports"
for folder in (CSV_DIR, CHART_DIR, REPORT_DIR):
    folder.mkdir(parents=True, exist_ok=True)

# ------------------------- HELPERS ---------------------------
def header(title: str) -> None:
    print("\n" + "=" * 76)
    print(title)
    print("=" * 76)


def ok(message: str) -> None:
    print(f"[PASS] {message}")


def info(message: str) -> None:
    print(f"[INFO] {message}")


def warn(message: str) -> None:
    print(f"[WARNING] {message}")


def fail(message: str) -> None:
    print(f"[ERROR] {message}")


def get_password() -> str:
    password = getpass(f"Enter PostgreSQL password for user '{DB_USER}': ")
    if not password:
        raise RuntimeError("PostgreSQL password cannot be empty.")
    return password


def connect_database(password: str):
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=password,
        )
        conn.autocommit = False
        return conn
    except psycopg2.OperationalError as exc:
        message = str(exc)
        if "does not exist" in message:
            raise RuntimeError(f"Database '{DB_NAME}' does not exist.") from exc
        if "password authentication failed" in message.lower():
            raise RuntimeError("PostgreSQL password authentication failed.") from exc
        if "connection refused" in message.lower():
            raise RuntimeError("PostgreSQL connection refused. Check the PostgreSQL service.") from exc
        raise RuntimeError(f"PostgreSQL connection failed:\n{message}") from exc


def scalar(conn, query: str, params=None):
    with conn.cursor() as cur:
        cur.execute(query, params)
        row = cur.fetchone()
    return row[0]


def dataframe(conn, query: str, params=None) -> pd.DataFrame:
    with conn.cursor() as cur:
        cur.execute(query, params)
        rows = cur.fetchall()
        columns = [desc[0] for desc in cur.description]
    return pd.DataFrame(rows, columns=columns)


def save(df: pd.DataFrame, filename: str, folder: Path = CSV_DIR) -> Path:
    path = folder / filename
    df.to_csv(path, index=False, encoding="utf-8-sig")
    ok(f"Saved: {path}")
    return path


def assert_columns(df: pd.DataFrame, name: str, required: list[str]) -> None:
    missing = sorted(set(required) - set(df.columns))
    if missing:
        raise RuntimeError(f"{name} missing required columns: {missing}")
    if df.empty:
        raise RuntimeError(f"{name} is empty.")
    ok(f"{name}: {len(df):,} rows x {len(df.columns)} columns")


def validate_expected_rows(name: str, actual: int, expected: int) -> None:
    if int(actual) != int(expected):
        raise RuntimeError(f"{name}: expected {expected:,}, got {actual:,}")
    ok(f"{name}: {actual:,} rows")


def validate_numeric_range(df: pd.DataFrame, column: str, low: float, high: float, name: str) -> None:
    values = pd.to_numeric(df[column], errors="coerce")
    invalid = int((values.lt(low) | values.gt(high) | values.isna()).sum())
    if invalid:
        raise RuntimeError(f"{name}: {invalid} invalid values")
    ok(f"{name}: all values in [{low}, {high}]")


def save_bar(
    df: pd.DataFrame,
    category: str,
    value: str,
    title: str,
    filename: str,
    top_n: int | None = None,
    horizontal: bool = False,
    rotation: int = 0,
) -> None:
    if df.empty:
        return
    plot_df = df.copy()
    if top_n is not None:
        plot_df = plot_df.sort_values(value, ascending=False).head(top_n)
    plot_df[category] = plot_df[category].fillna("(Unknown)").astype(str)

    plt.figure(figsize=(11, 6))
    if horizontal:
        plot_df = plot_df.sort_values(value, ascending=True)
        plt.barh(plot_df[category], plot_df[value])
    else:
        plt.bar(plot_df[category], plot_df[value])
        if rotation:
            plt.xticks(rotation=rotation, ha="right")
    plt.title(title)
    plt.xlabel(category)
    plt.ylabel(value)
    plt.tight_layout()
    path = CHART_DIR / filename
    plt.savefig(path, dpi=150, bbox_inches="tight")
    plt.close()
    ok(f"Chart saved: {path}")


def save_line(df: pd.DataFrame, x: str, y: str, title: str, filename: str) -> None:
    if df.empty:
        return
    plt.figure(figsize=(11, 6))
    plt.plot(df[x], df[y], marker="o")
    plt.title(title)
    plt.xlabel(x)
    plt.ylabel(y)
    plt.tight_layout()
    path = CHART_DIR / filename
    plt.savefig(path, dpi=150, bbox_inches="tight")
    plt.close()
    ok(f"Chart saved: {path}")


def save_hist(df: pd.DataFrame, column: str, title: str, filename: str, bins: int = 30) -> None:
    values = pd.to_numeric(df[column], errors="coerce").dropna()
    if values.empty:
        return
    plt.figure(figsize=(11, 6))
    plt.hist(values, bins=bins)
    plt.title(title)
    plt.xlabel(column)
    plt.ylabel("Frequency")
    plt.tight_layout()
    path = CHART_DIR / filename
    plt.savefig(path, dpi=150, bbox_inches="tight")
    plt.close()
    ok(f"Chart saved: {path}")


def save_heatmap(matrix: pd.DataFrame, title: str, filename: str) -> None:
    if matrix.empty:
        return
    plt.figure(figsize=(10, 8))
    image = plt.imshow(matrix.values, aspect="auto", interpolation="nearest")
    plt.colorbar(image, label="Spearman rho")
    plt.xticks(range(len(matrix.columns)), matrix.columns, rotation=45, ha="right")
    plt.yticks(range(len(matrix.index)), matrix.index)
    plt.title(title)
    plt.tight_layout()
    path = CHART_DIR / filename
    plt.savefig(path, dpi=150, bbox_inches="tight")
    plt.close()
    ok(f"Chart saved: {path}")

# ============================================================
# 1. VALIDATED SQL INPUT LAYER
# ============================================================
SQL_INPUTS = {
    "reorder_summary": (
        "SELECT * FROM analytics.reorder_summary"
    ),
    "orders_by_day": (
        "SELECT * FROM analytics.orders_by_day ORDER BY order_dow"
    ),
    "orders_by_hour": (
        "SELECT * FROM analytics.orders_by_hour ORDER BY order_hour_of_day"
    ),
    "orders_by_day_hour": (
        "SELECT * FROM analytics.orders_by_day_hour ORDER BY order_dow, order_hour_of_day"
    ),
    "order_basket_summary": (
        "SELECT * FROM analytics.order_basket_summary ORDER BY order_id"
    ),
    "basket_size_distribution": (
        "SELECT * FROM analytics.basket_size_distribution ORDER BY basket_size"
    ),
    "reorder_by_sequence": (
        "SELECT * FROM analytics.reorder_by_sequence ORDER BY order_number"
    ),
    "product_performance": (
        "SELECT * FROM analytics.product_performance ORDER BY product_id"
    ),
    "department_performance": (
        "SELECT * FROM analytics.department_performance ORDER BY department_id"
    ),
    "aisle_performance": (
        "SELECT * FROM analytics.aisle_performance ORDER BY aisle_id"
    ),
    "customer_behavior": (
        "SELECT * FROM analytics.customer_behavior ORDER BY user_id"
    ),
    "customer_frequency": (
        "SELECT * FROM analytics.customer_frequency ORDER BY total_orders"
    ),
    "customer_purchase_gap_distribution": (
        "SELECT * FROM analytics.customer_purchase_gap_distribution ORDER BY days_since_prior_order"
    ),
    "market_basket_product_universe": (
        "SELECT * FROM analytics.market_basket_product_universe ORDER BY product_rank"
    ),
}


def validate_analytical_objects(conn) -> pd.DataFrame:
    header("1. SQL ANALYTICAL INPUT VALIDATION")
    rows = []
    for name in SQL_INPUTS:
        exists = bool(
            scalar(
                conn,
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_schema = 'analytics'
                      AND table_name = %s
                );
                """,
                (name,),
            )
        )
        rows.append({"object": f"analytics.{name}", "exists": exists, "status": "PASS" if exists else "FAIL"})
        (ok if exists else fail)(f"analytics.{name} exists")

    report = pd.DataFrame(rows)
    save(report, "sql_analytical_object_validation.csv", REPORT_DIR)
    if (report["status"] == "FAIL").any():
        raise RuntimeError("Required SQL analytical input validation failed.")
    return report


def load_sql_inputs(conn) -> dict[str, pd.DataFrame]:
    header("2. LOAD VALIDATED SQL ANALYTICAL OUTPUTS")
    data = {}
    manifest_rows = []
    for name, query in SQL_INPUTS.items():
        frame = dataframe(conn, query)
        data[name] = frame
        manifest_rows.append({
            "object": f"analytics.{name}",
            "rows_loaded": len(frame),
            "columns": len(frame.columns),
        })
        info(f"Loaded analytics.{name}: {len(frame):,} rows")
    save(pd.DataFrame(manifest_rows), "python_sql_input_manifest.csv", REPORT_DIR)
    return data


def validate_sql_input_contracts(data: dict[str, pd.DataFrame]) -> None:
    header("3. SQL ANALYTICAL OUTPUT CONTRACT VALIDATION")

    assert_columns(data["reorder_summary"], "reorder_summary", [
        "total_items", "reordered_items", "first_time_items", "reorder_rate_pct"
    ])
    assert_columns(data["orders_by_day"], "orders_by_day", ["order_dow", "day_name", "total_orders"])
    assert_columns(data["orders_by_hour"], "orders_by_hour", ["order_hour_of_day", "hour_label", "total_orders"])
    assert_columns(data["orders_by_day_hour"], "orders_by_day_hour", ["order_dow", "order_hour_of_day", "day_name", "hour_label", "total_orders"])
    assert_columns(data["order_basket_summary"], "order_basket_summary", [
        "order_id", "user_id", "order_number", "order_dow", "order_hour_of_day",
        "days_since_prior_order", "basket_size", "reordered_items", "first_time_items"
    ])
    assert_columns(data["basket_size_distribution"], "basket_size_distribution", ["basket_size", "order_count"])
    assert_columns(data["reorder_by_sequence"], "reorder_by_sequence", ["order_number", "item_purchases", "reordered_items", "reorder_rate_pct"])
    assert_columns(data["product_performance"], "product_performance", [
        "product_id", "product_name", "aisle", "department", "purchase_count",
        "unique_orders", "unique_customers", "reorder_count", "reorder_rate_pct", "average_cart_position"
    ])
    assert_columns(data["department_performance"], "department_performance", [
        "department_id", "department", "purchase_count", "unique_products", "unique_customers",
        "reorder_count", "reorder_rate_pct"
    ])
    assert_columns(data["aisle_performance"], "aisle_performance", [
        "aisle_id", "aisle", "department_id", "department", "purchase_count",
        "unique_products", "unique_customers", "reorder_count", "reorder_rate_pct"
    ])
    assert_columns(data["customer_behavior"], "customer_behavior", [
        "user_id", "total_orders", "total_items", "unique_products", "reordered_items",
        "avg_basket_size", "reorder_rate_pct", "avg_days_between_orders",
        "favorite_department_id", "favorite_department", "favorite_aisle_id", "favorite_aisle"
    ])
    assert_columns(data["customer_frequency"], "customer_frequency", ["total_orders", "customer_count"])
    assert_columns(data["customer_purchase_gap_distribution"], "customer_purchase_gap_distribution", [
        "days_since_prior_order", "orders"
    ])
    assert_columns(data["market_basket_product_universe"], "market_basket_product_universe", [
        "product_rank", "product_id", "product_name", "aisle_id", "aisle",
        "department_id", "department", "purchase_count"
    ])

    validate_expected_rows("reorder_summary", len(data["reorder_summary"]), 1)
    validate_expected_rows("order_basket_summary", len(data["order_basket_summary"]), CONTROL["prior_orders"])
    validate_expected_rows("orders_by_day", len(data["orders_by_day"]), CONTROL["day_rows"])
    validate_expected_rows("orders_by_hour", len(data["orders_by_hour"]), CONTROL["hour_rows"])
    if set(pd.to_numeric(data["orders_by_day"]["order_dow"], errors="coerce").astype(int)) != set(range(7)):
        raise RuntimeError("orders_by_day must contain order_dow values 0 through 6 exactly once.")
    ok("Orders-by-day covers all 7 weekday codes")
    if set(pd.to_numeric(data["orders_by_hour"]["order_hour_of_day"], errors="coerce").astype(int)) != set(range(24)):
        raise RuntimeError("orders_by_hour must contain hours 0 through 23 exactly once.")
    ok("Orders-by-hour covers all 24 hourly codes")

    validate_expected_rows("basket_size_distribution", len(data["basket_size_distribution"]), CONTROL["basket_distribution_rows"])
    validate_expected_rows("reorder_by_sequence", len(data["reorder_by_sequence"]), CONTROL["reorder_sequence_rows"])
    validate_expected_rows("product_performance", len(data["product_performance"]), CONTROL["product_rows"])
    validate_expected_rows("department_performance", len(data["department_performance"]), CONTROL["department_rows"])
    validate_expected_rows("aisle_performance", len(data["aisle_performance"]), CONTROL["aisle_rows"])
    validate_expected_rows("customer_behavior", len(data["customer_behavior"]), CONTROL["customer_rows"])
    validate_expected_rows("market_basket_product_universe", len(data["market_basket_product_universe"]), CONTROL["basket_universe_rows"])

    # Literal 'missing' is allowed because it is a valid source category.
    missing_department_rows = int(
        (data["product_performance"]["department"].astype(str).str.lower().str.strip() == "missing").sum()
    )
    info(f"Product-performance rows under legitimate department label 'missing': {missing_department_rows:,}")
    info("The literal 'missing' department label is not treated as a QA failure.")

    # Real integrity problems remain failures.
    for name, frame, cols in [
        ("product_performance", data["product_performance"], ["product_name", "aisle", "department"]),
        ("department_performance", data["department_performance"], ["department"]),
        ("aisle_performance", data["aisle_performance"], ["aisle", "department"]),
    ]:
        nulls = int(frame[cols].isna().any(axis=1).sum())
        if nulls:
            raise RuntimeError(f"{name}: {nulls} rows contain unexpected NULL descriptive attributes.")
        ok(f"{name}: no unexpected NULL descriptive attributes")

    # Duplicate key checks.
    duplicate_checks = [
        ("product_performance.product_id", data["product_performance"], "product_id"),
        ("department_performance.department_id", data["department_performance"], "department_id"),
        ("aisle_performance.aisle_id", data["aisle_performance"], "aisle_id"),
        ("customer_behavior.user_id", data["customer_behavior"], "user_id"),
        ("order_basket_summary.order_id", data["order_basket_summary"], "order_id"),
        ("market_basket_product_universe.product_id", data["market_basket_product_universe"], "product_id"),
    ]
    for label, frame, key in duplicate_checks:
        duplicates = int(frame[key].duplicated().sum())
        if duplicates:
            raise RuntimeError(f"{label}: {duplicates} duplicate keys.")
        ok(f"{label}: unique")

    # Numeric QA.
    validate_numeric_range(data["product_performance"], "reorder_rate_pct", 0, 100, "Product reorder rates")
    validate_numeric_range(data["department_performance"], "reorder_rate_pct", 0, 100, "Department reorder rates")
    validate_numeric_range(data["aisle_performance"], "reorder_rate_pct", 0, 100, "Aisle reorder rates")
    validate_numeric_range(data["customer_behavior"], "reorder_rate_pct", 0, 100, "Customer reorder rates")
    validate_numeric_range(data["reorder_by_sequence"], "reorder_rate_pct", 0, 100, "Order-sequence reorder rates")

    if not (data["order_basket_summary"]["basket_size"] >= 1).all():
        raise RuntimeError("Order basket summary contains basket_size < 1.")
    ok("Order basket sizes >= 1")

    if not (data["customer_behavior"]["total_items"] >= data["customer_behavior"]["total_orders"]).all():
        raise RuntimeError("A customer has fewer items than orders.")
    ok("Customer total_items >= total_orders")

    gap_logic_failures = int((
        (data["customer_behavior"]["total_orders"] > 1)
        & (data["customer_behavior"]["avg_days_between_orders"].isna())
    ).sum())
    if gap_logic_failures:
        raise RuntimeError(
            f"Customer purchase-gap logic failed: {gap_logic_failures} customers with >1 PRIOR order have NULL average gap."
        )
    ok("Customer purchase-gap NULL logic is valid")

    if not (data["customer_behavior"]["reordered_items"] <= data["customer_behavior"]["total_items"]).all():
        raise RuntimeError("A customer has reordered_items > total_items.")
    ok("Customer reordered_items <= total_items")

    if not (data["product_performance"]["reorder_count"] <= data["product_performance"]["purchase_count"]).all():
        raise RuntimeError("A product has reorder_count > purchase_count.")
    ok("Product reorder_count <= purchase_count")

    info("SQL analytical input contract validation completed.")

# ============================================================
# 2. PYTHON EDA CALCULATIONS
# ============================================================
def build_executive_kpis(data: dict[str, pd.DataFrame]) -> pd.DataFrame:
    order_summary = data["order_basket_summary"]
    product = data["product_performance"]
    dept = data["department_performance"]
    aisle = data["aisle_performance"]
    reorder = data["reorder_summary"].iloc[0]

    total_orders = len(order_summary)
    total_customers = order_summary["user_id"].nunique()
    total_items = int(order_summary["basket_size"].sum())
    unique_products = int(product["product_id"].nunique())

    result = pd.DataFrame([{
        "total_orders": total_orders,
        "total_customers": total_customers,
        "total_items": total_items,
        "unique_products": unique_products,
        "unique_aisles": int(aisle["aisle_id"].nunique()),
        "unique_departments": int(dept["department_id"].nunique()),
        "average_basket_size": round(total_items / total_orders, 2),
        "reordered_items": int(reorder["reordered_items"]),
        "first_time_items": int(reorder["first_time_items"]),
        "overall_reorder_rate_pct": round(float(reorder["reorder_rate_pct"]), 2),
    }])
    return result


def create_reorder_distribution(reorder: pd.DataFrame) -> pd.DataFrame:
    row = reorder.iloc[0]
    result = pd.DataFrame({
        "category": ["Reordered", "First-time"],
        "items": [int(row["reordered_items"]), int(row["first_time_items"])],
    })
    result["percentage"] = (result["items"] / result["items"].sum() * 100).round(2)
    return result


def create_reorder_opportunity(product: pd.DataFrame) -> pd.DataFrame:
    eligible = product[product["purchase_count"] >= MIN_REORDER_PRODUCT_PURCHASES].copy()
    eligible = eligible.sort_values(
        ["reorder_rate_pct", "purchase_count", "product_id"],
        ascending=[False, False, True],
    ).reset_index(drop=True)
    eligible.insert(0, "opportunity_rank", np.arange(1, len(eligible) + 1))
    return eligible


def create_customer_statistics(customer: pd.DataFrame) -> pd.DataFrame:
    numeric = [
        "total_orders", "total_items", "unique_products", "reordered_items",
        "avg_basket_size", "reorder_rate_pct", "avg_days_between_orders"
    ]
    return (
        customer[numeric]
        .describe()
        .T
        .reset_index()
        .rename(columns={"index": "metric"})
    )


def create_missingness_report(dataframes: dict[str, pd.DataFrame]) -> pd.DataFrame:
    rows = []
    for name, frame in dataframes.items():
        for column in frame.columns:
            null_count = int(frame[column].isna().sum())
            rows.append({
                "dataset": name,
                "column": column,
                "null_count": null_count,
                "null_pct": round((null_count / len(frame) * 100) if len(frame) else 0.0, 4),
            })
    return pd.DataFrame(rows)


def create_behavior_segments(customer: pd.DataFrame) -> pd.DataFrame:
    result = customer.copy()
    frequency_rank = result["total_orders"].rank(method="average", pct=True)
    reorder_rank = result["reorder_rate_pct"].rank(method="average", pct=True)

    result["frequency_segment"] = pd.cut(
        frequency_rank,
        bins=[0, 1 / 3, 2 / 3, 1.000001],
        labels=["Low", "Regular", "High"],
        include_lowest=True,
    )
    result["reorder_segment"] = pd.cut(
        reorder_rank,
        bins=[0, 1 / 3, 2 / 3, 1.000001],
        labels=["Low", "Regular", "High"],
        include_lowest=True,
    )
    result["behavior_segment"] = (
        result["frequency_segment"].astype(str)
        + " Frequency / "
        + result["reorder_segment"].astype(str)
        + " Reorder"
    )
    return result


def create_segment_summary(segment_df: pd.DataFrame) -> pd.DataFrame:
    result = (
        segment_df["behavior_segment"]
        .value_counts()
        .rename_axis("behavior_segment")
        .reset_index(name="customers")
    )
    result["customer_pct"] = (result["customers"] / result["customers"].sum() * 100).round(2)
    return result


def create_spearman_analysis(customer: pd.DataFrame):
    variables = [
        "total_orders", "total_items", "unique_products", "reordered_items",
        "avg_basket_size", "reorder_rate_pct", "avg_days_between_orders"
    ]
    corr = customer[variables].corr(method="spearman")
    rows = []
    for i, var_a in enumerate(variables):
        for var_b in variables[i + 1:]:
            x = pd.to_numeric(customer[var_a], errors="coerce")
            y = pd.to_numeric(customer[var_b], errors="coerce")
            valid = x.notna() & y.notna()
            if valid.sum() < 3:
                continue
            rho, p_value = spearmanr(x[valid], y[valid])
            rows.append({
                "variable_1": var_a,
                "variable_2": var_b,
                "spearman_rho": float(rho),
                "p_value": float(p_value),
                "sample_size": int(valid.sum()),
            })
    return corr, pd.DataFrame(rows)


def create_iqr_report(customer: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    rows = []
    for column in columns:
        values = pd.to_numeric(customer[column], errors="coerce").dropna()
        if values.empty:
            continue
        q1 = values.quantile(0.25)
        q3 = values.quantile(0.75)
        iqr = q3 - q1
        lower = q1 - 1.5 * iqr
        upper = q3 + 1.5 * iqr
        outliers = int(((values < lower) | (values > upper)).sum())
        rows.append({
            "column": column,
            "q1": float(q1),
            "q3": float(q3),
            "iqr": float(iqr),
            "lower_bound": float(lower),
            "upper_bound": float(upper),
            "outlier_count": outliers,
            "outlier_pct": round(outliers / len(values) * 100, 4),
        })
    return pd.DataFrame(rows)

# ============================================================
# 3. PYTHON MARKET BASKET — FROM VALIDATED SQL OUTPUTS ONLY
# ============================================================
def get_market_basket_from_sql(conn, universe: pd.DataFrame) -> pd.DataFrame:
    """
    Market Basket is computed in Python, but the transaction-product input
    comes ONLY from the validated SQL analytical object:
        analytics.enriched_order_product_prior

    We stream only products inside the validated top-100 universe so we do not
    load the entire 32M-row analytical table into pandas.
    """
    header("MARKET BASKET ASSOCIATION ANALYSIS")
    if universe.empty:
        raise RuntimeError("Market Basket product universe is empty.")

    product_ids = [int(v) for v in universe["product_id"].tolist()]
    product_ids_set = set(product_ids)
    order_product_counts = Counter()
    pair_counts = Counter()

    product_sql = """
        SELECT order_id, product_id
        FROM analytics.enriched_order_product_prior
        WHERE product_id = ANY(%s)
        ORDER BY order_id, product_id;
    """

    processed_rows = 0
    current_order = None
    current_products: list[int] = []

    with conn.cursor(name="mba_stream") as cur:
        cur.itersize = 100_000
        cur.execute(product_sql, (product_ids,))

        while True:
            batch = cur.fetchmany(100_000)
            if not batch:
                break

            for order_id, product_id in batch:
                processed_rows += 1

                if current_order is None:
                    current_order = order_id

                if order_id != current_order:
                    unique_products = sorted(set(current_products))
                    for product_id_value in unique_products:
                        order_product_counts[product_id_value] += 1
                    pair_counts.update(combinations(unique_products, 2))

                    current_order = order_id
                    current_products = []

                if product_id in product_ids_set:
                    current_products.append(int(product_id))

    if current_order is not None:
        unique_products = sorted(set(current_products))
        for product_id_value in unique_products:
            order_product_counts[product_id_value] += 1
        pair_counts.update(combinations(unique_products, 2))

    info(f"Streamed qualifying analytical rows: {processed_rows:,}")
    info(f"Observed qualifying product pairs: {len(pair_counts):,}")

    total_prior_orders = int(CONTROL["prior_orders"])
    name_map = universe.set_index("product_id")["product_name"].to_dict()

    records = []
    for (product_a, product_b), orders_together in pair_counts.items():
        if orders_together < MIN_PAIR_ORDERS:
            continue

        orders_a = order_product_counts[product_a]
        orders_b = order_product_counts[product_b]
        if orders_a == 0 or orders_b == 0:
            continue

        support = orders_together / total_prior_orders
        confidence_a_to_b = orders_together / orders_a * 100
        confidence_b_to_a = orders_together / orders_b * 100
        lift = (orders_together * total_prior_orders) / (orders_a * orders_b)

        records.append({
            "product_a": product_a,
            "product_a_name": name_map.get(product_a, "(Unknown Product)"),
            "product_b": product_b,
            "product_b_name": name_map.get(product_b, "(Unknown Product)"),
            "orders_together": int(orders_together),
            "support": round(support, 6),
            "confidence_a_to_b_pct": round(confidence_a_to_b, 2),
            "confidence_b_to_a_pct": round(confidence_b_to_a, 2),
            "lift": round(lift, 4),
        })

    mba = pd.DataFrame(records)
    if mba.empty:
        warn("No pairs met the configured minimum pair-order threshold.")
        return mba

    mba = (
        mba.sort_values(["lift", "orders_together", "product_a", "product_b"], ascending=[False, False, True, True])
        .head(MAX_ASSOCIATIONS)
        .reset_index(drop=True)
    )

    mba["product_pair"] = mba["product_a_name"] + " + " + mba["product_b_name"]
    return mba


def validate_market_basket(mba: pd.DataFrame) -> None:
    if mba.empty:
        raise RuntimeError("Market Basket output is empty; expected qualified associations.")

    duplicate_pairs = int(mba[["product_a", "product_b"]].duplicated().sum())
    if duplicate_pairs:
        raise RuntimeError(f"Market Basket duplicate pairs: {duplicate_pairs}")
    ok("No duplicate Market Basket pairs")

    if not (mba["product_a"] < mba["product_b"]).all():
        raise RuntimeError("Market Basket product ordering rule failed.")
    ok("Product A < Product B for every pair")

    if not ((mba["support"] >= 0) & (mba["support"] <= 1)).all():
        raise RuntimeError("Market Basket support outside 0-1.")
    ok("Support within 0-1")

    confidence_valid = (
        mba["confidence_a_to_b_pct"].between(0, 100)
        & mba["confidence_b_to_a_pct"].between(0, 100)
    ).all()
    if not confidence_valid:
        raise RuntimeError("Market Basket confidence outside 0-100.")
    ok("Confidence within 0-100")

    if not (mba["lift"] > 0).all():
        raise RuntimeError("Market Basket lift must be > 0.")
    ok("Lift > 0")

    if (mba["orders_together"] < MIN_PAIR_ORDERS).any():
        raise RuntimeError("Minimum pair-order threshold was violated.")
    ok(f"Minimum pair orders >= {MIN_PAIR_ORDERS}")

    if len(mba) > MAX_ASSOCIATIONS:
        raise RuntimeError("Market Basket output exceeds maximum association limit.")
    ok(f"Association output <= {MAX_ASSOCIATIONS} rows")

    # Regression check from the previously validated analytical result.
    known = mba[
        (mba["product_a_name"] == "Sparkling Lemon Water")
        & (mba["product_b_name"] == "Lime Sparkling Water")
    ]
    if not known.empty:
        known_row = known.iloc[0]
        if int(known_row["orders_together"]) != 8546:
            raise RuntimeError(
                "Known Market Basket regression mismatch: expected 8,546 orders together."
            )
        if not np.isclose(float(known_row["lift"]), 18.0024, atol=0.0001):
            raise RuntimeError(
                "Known Market Basket regression mismatch: expected lift 18.0024."
            )
        ok("Known pair regression: Sparkling Lemon Water + Lime Sparkling Water")
        ok("Known pair orders together = 8,546")
        ok("Known pair lift = 18.0024")
    else:
        warn("Known regression pair was not present in the final 500 associations.")

# ============================================================
# 4. SQL ↔ PYTHON RECONCILIATION
# ============================================================
def run_cross_validation(data: dict[str, pd.DataFrame], kpi: pd.DataFrame, mba: pd.DataFrame) -> pd.DataFrame:
    header("SQL ↔ PYTHON CROSS-VALIDATION")
    checks = []

    def compare(name: str, actual, expected, tolerance: float = 0.0):
        difference = abs(float(actual) - float(expected))
        passed = difference <= tolerance
        checks.append({
            "check": name,
            "actual": actual,
            "expected": expected,
            "difference": difference,
            "status": "PASS" if passed else "FAIL",
        })
        if passed:
            ok(f"{name}: actual={actual}, expected={expected}")
        else:
            fail(f"{name}: actual={actual}, expected={expected}")

    order_summary = data["order_basket_summary"]
    product = data["product_performance"]
    department = data["department_performance"]
    aisle = data["aisle_performance"]
    customer = data["customer_behavior"]
    day = data["orders_by_day"]
    hour = data["orders_by_hour"]
    day_hour = data["orders_by_day_hour"]
    basket = data["basket_size_distribution"]
    reorder = data["reorder_summary"].iloc[0]

    compare("Order count", len(order_summary), CONTROL["prior_orders"])
    compare("Customer count", order_summary["user_id"].nunique(), CONTROL["prior_customers"])
    compare("Item total", order_summary["basket_size"].sum(), CONTROL["prior_items"])
    compare("Reorder total", order_summary["reordered_items"].sum(), CONTROL["prior_reordered_items"])
    compare("First-time total", order_summary["first_time_items"].sum(), CONTROL["prior_first_time_items"])
    compare("Product purchase total", product["purchase_count"].sum(), CONTROL["prior_items"])
    compare("Product reorder total", product["reorder_count"].sum(), CONTROL["prior_reordered_items"])
    compare("Department purchase total", department["purchase_count"].sum(), CONTROL["prior_items"])
    compare("Department reorder total", department["reorder_count"].sum(), CONTROL["prior_reordered_items"])
    compare("Aisle purchase total", aisle["purchase_count"].sum(), CONTROL["prior_items"])
    compare("Aisle reorder total", aisle["reorder_count"].sum(), CONTROL["prior_reordered_items"])
    compare("Customer item total", customer["total_items"].sum(), CONTROL["prior_items"])
    compare("Customer reorder total", customer["reordered_items"].sum(), CONTROL["prior_reordered_items"])
    compare("Customer order total", customer["total_orders"].sum(), CONTROL["prior_orders"])
    compare("Orders by day total", day["total_orders"].sum(), CONTROL["prior_orders"])
    compare("Orders by hour total", hour["total_orders"].sum(), CONTROL["prior_orders"])
    compare("Orders by day-hour total", day_hour["total_orders"].sum(), CONTROL["prior_orders"])
    compare("Basket distribution total", basket["order_count"].sum(), CONTROL["prior_orders"])
    compare("Reorder summary total items", reorder["total_items"], CONTROL["prior_items"])
    compare("Reorder summary reordered items", reorder["reordered_items"], CONTROL["prior_reordered_items"])
    compare("Reorder summary first-time items", reorder["first_time_items"], CONTROL["prior_first_time_items"])

    # Average basket and reorder rate are ratio checks, not raw row-count checks.
    expected_basket = CONTROL["prior_items"] / CONTROL["prior_orders"]
    expected_reorder_rate = CONTROL["prior_reordered_items"] / CONTROL["prior_items"] * 100
    compare("Average basket size", float(kpi.loc[0, "average_basket_size"]), expected_basket, 0.02)
    compare("Overall reorder rate %", float(kpi.loc[0, "overall_reorder_rate_pct"]), expected_reorder_rate, 0.02)

    result = pd.DataFrame(checks)
    save(result, "sql_python_cross_validation.csv", REPORT_DIR)
    failures = result[result["status"] == "FAIL"]
    print(f"Cross-validation checks: {len(result)}")
    print(f"Cross-validation failures: {len(failures)}")
    if not failures.empty:
        raise RuntimeError("SQL ↔ Python reconciliation failed.")
    ok("All SQL ↔ Python cross-validation checks passed.")

    return result

# ============================================================
# 5. FINAL PYTHON QA
# ============================================================
def final_python_validation(
    data: dict[str, pd.DataFrame],
    kpi: pd.DataFrame,
    segments: pd.DataFrame,
    segment_summary: pd.DataFrame,
    mba: pd.DataFrame,
) -> pd.DataFrame:
    header("FINAL PYTHON ANALYTICAL VALIDATION")
    checks = []

    def add(name: str, condition: bool, value):
        status = "PASS" if bool(condition) else "FAIL"
        checks.append({"check": name, "value": value, "status": status})
        (ok if status == "PASS" else fail)(f"{name}: {value}")

    add("Exactly one KPI row", len(kpi) == 1, len(kpi))
    add("7 day rows", len(data["orders_by_day"]) == 7, len(data["orders_by_day"]))
    add("24 hour rows", len(data["orders_by_hour"]) == 24, len(data["orders_by_hour"]))
    add("Day-hour rows <= 168", len(data["orders_by_day_hour"]) <= 168, len(data["orders_by_day_hour"]))
    add("113 basket distribution rows", len(data["basket_size_distribution"]) == 113, len(data["basket_size_distribution"]))
    add("99 reorder sequence rows", len(data["reorder_by_sequence"]) == 99, len(data["reorder_by_sequence"]))
    add("49,677 product rows", len(data["product_performance"]) == 49_677, len(data["product_performance"]))
    add("21 department rows", len(data["department_performance"]) == 21, len(data["department_performance"]))
    add("134 aisle rows", len(data["aisle_performance"]) == 134, len(data["aisle_performance"]))
    add("206,209 customer rows", len(data["customer_behavior"]) == 206_209, len(data["customer_behavior"]))
    add("100 Market Basket universe rows", len(data["market_basket_product_universe"]) == 100, len(data["market_basket_product_universe"]))

    add("No basket_size < 1", (data["order_basket_summary"]["basket_size"] >= 1).all(), int((data["order_basket_summary"]["basket_size"] < 1).sum()))
    add("Customer total_items >= total_orders", (data["customer_behavior"]["total_items"] >= data["customer_behavior"]["total_orders"]).all(), int((data["customer_behavior"]["total_items"] < data["customer_behavior"]["total_orders"]).sum()))
    add("Customer reordered_items <= total_items", (data["customer_behavior"]["reordered_items"] <= data["customer_behavior"]["total_items"]).all(), int((data["customer_behavior"]["reordered_items"] > data["customer_behavior"]["total_items"]).sum()))
    add("Product reorder_count <= purchase_count", (data["product_performance"]["reorder_count"] <= data["product_performance"]["purchase_count"]).all(), int((data["product_performance"]["reorder_count"] > data["product_performance"]["purchase_count"]).sum()))
    add("Customer segment rows reconcile", len(segments) == CONTROL["customer_rows"], len(segments))
    add("Customer segment summary reconciles", int(segment_summary["customers"].sum()) == CONTROL["prior_customers"], int(segment_summary["customers"].sum()))
    add("Customer segment percentages sum ~100", np.isclose(segment_summary["customer_pct"].sum(), 100, atol=0.02), float(segment_summary["customer_pct"].sum()))

    banana = product_row = data["product_performance"][
        data["product_performance"]["product_name"] == "Banana"
    ]
    if not banana.empty:
        banana_purchase_count = int(banana.iloc[0]["purchase_count"])
        add("Banana purchase regression", banana_purchase_count == 472565, banana_purchase_count)

    produce = data["department_performance"][
        data["department_performance"]["department"].astype(str).str.lower().str.strip() == "produce"
    ]
    if not produce.empty:
        produce_purchase_count = int(produce.iloc[0]["purchase_count"])
        add("Produce purchase regression", produce_purchase_count == 9479291, produce_purchase_count)

    add("No duplicate Market Basket pairs", int(mba[["product_a", "product_b"]].duplicated().sum()) == 0, int(mba[["product_a", "product_b"]].duplicated().sum()))
    add("Product A < Product B", bool((mba["product_a"] < mba["product_b"]).all()), int((mba["product_a"] >= mba["product_b"]).sum()))
    add("Support within 0-1", bool(((mba["support"] >= 0) & (mba["support"] <= 1)).all()), int(((mba["support"] < 0) | (mba["support"] > 1)).sum()))
    add("Confidence within 0-100", bool((mba["confidence_a_to_b_pct"].between(0, 100) & mba["confidence_b_to_a_pct"].between(0, 100)).all()), 0)
    add("Lift > 0", bool((mba["lift"] > 0).all()), int((mba["lift"] <= 0).sum()))
    add("Pair-order threshold respected", bool((mba["orders_together"] >= MIN_PAIR_ORDERS).all()), int((mba["orders_together"] < MIN_PAIR_ORDERS).sum()))
    add("Market Basket output <= 500", len(mba) <= MAX_ASSOCIATIONS, len(mba))

    result = pd.DataFrame(checks)
    save(result, "final_python_analytical_validation.csv", REPORT_DIR)
    failures = result[result["status"] == "FAIL"]
    print(f"Final Python analytical checks: {len(result)}")
    print(f"Final Python analytical failures: {len(failures)}")
    if not failures.empty:
        raise RuntimeError("Final Python analytical validation failed.")
    ok("All final Python analytical checks passed.")
    return result

# ============================================================
# 6. BUSINESS HIGHLIGHTS
# ============================================================
def create_business_highlights(
    kpi: pd.DataFrame,
    day: pd.DataFrame,
    hour: pd.DataFrame,
    product: pd.DataFrame,
    department: pd.DataFrame,
    gap: pd.DataFrame,
    mba: pd.DataFrame,
) -> pd.DataFrame:
    rows = []
    rows.append({"metric": "Total Customers", "value": int(kpi.loc[0, "total_customers"]), "context": "Distinct PRIOR customers"})
    rows.append({"metric": "Total Orders", "value": int(kpi.loc[0, "total_orders"]), "context": "PRIOR orders"})
    rows.append({"metric": "Total Items", "value": int(kpi.loc[0, "total_items"]), "context": "PRIOR product-purchase rows"})
    rows.append({"metric": "Average Basket Size", "value": float(kpi.loc[0, "average_basket_size"]), "context": "Items per PRIOR order"})
    rows.append({"metric": "Overall Reorder Rate %", "value": float(kpi.loc[0, "overall_reorder_rate_pct"]), "context": "Reordered item purchases / all item purchases"})

    peak_day = day.sort_values("total_orders", ascending=False).iloc[0]
    rows.append({"metric": "Highest Order-Volume Day", "value": peak_day["day_name"], "context": int(peak_day["total_orders"])})

    peak_hour = hour.sort_values("total_orders", ascending=False).iloc[0]
    rows.append({"metric": "Highest Order-Volume Hour", "value": int(peak_hour["order_hour_of_day"]), "context": int(peak_hour["total_orders"])})

    top_product = product.sort_values(["purchase_count", "product_id"], ascending=[False, True]).iloc[0]
    rows.append({"metric": "Most Purchased Product", "value": top_product["product_name"], "context": int(top_product["purchase_count"])})

    top_department = department.sort_values(["purchase_count", "department_id"], ascending=[False, True]).iloc[0]
    rows.append({"metric": "Highest Purchase-Volume Department", "value": top_department["department"], "context": int(top_department["purchase_count"])})

    if not gap.empty:
        weighted_gap = float((gap["days_since_prior_order"] * gap["orders"]).sum() / gap["orders"].sum())
        rows.append({"metric": "Weighted Average Purchase Gap", "value": round(weighted_gap, 2), "context": "Days since prior order; first orders excluded"})

    if not mba.empty:
        pair = mba.iloc[0]
        rows.append({
            "metric": "Strongest Observed Product Association",
            "value": f"{pair['product_a_name']} + {pair['product_b_name']}",
            "context": f"Lift={pair['lift']:.4f}; orders together={int(pair['orders_together']):,}",
        })

    return pd.DataFrame(rows)

# ============================================================
# 7. MAIN WORKFLOW
# ============================================================
def main() -> int:
    start = datetime.now()
    header("INSTACART PYTHON EDA V2")
    print("Source: validated SQL analytical layer only")
    print(f"Database          : {DB_NAME}")
    print(f"Analysis set      : {ANALYSIS_SET}")
    print(f"Basket universe   : Top {BASKET_TOP_N} products")
    print(f"Minimum pair rows : {MIN_PAIR_ORDERS}")
    print(f"Output directory  : {OUTPUT_DIR}")

    password = get_password()
    conn = connect_database(password)

    try:
        # ------------------------------------------------------
        # 1. Validate SQL analytical objects
        # ------------------------------------------------------
        validate_analytical_objects(conn)

        # ------------------------------------------------------
        # 2. Load validated SQL analytical outputs
        # ------------------------------------------------------
        data = load_sql_inputs(conn)
        validate_sql_input_contracts(data)

        # ------------------------------------------------------
        # 3. Executive KPI EDA
        # ------------------------------------------------------
        header("4. EXECUTIVE KPI EDA")
        kpi = build_executive_kpis(data)
        save(kpi, "executive_kpis.csv")
        print(kpi.to_string(index=False))

        # ------------------------------------------------------
        # 4. Purchase timing EDA
        # ------------------------------------------------------
        header("5. PURCHASE TIMING EDA")
        day = data["orders_by_day"]
        hour = data["orders_by_hour"]
        day_hour = data["orders_by_day_hour"]
        save(day, "orders_by_day.csv")
        save(hour, "orders_by_hour.csv")
        save(day_hour, "orders_by_day_hour.csv")
        save_bar(day, "day_name", "total_orders", "Orders by Day of Week", "orders_by_day.png")
        save_line(hour, "order_hour_of_day", "total_orders", "Orders by Hour of Day", "orders_by_hour.png")

        # ------------------------------------------------------
        # 5. Basket behavior EDA
        # ------------------------------------------------------
        header("6. BASKET BEHAVIOR EDA")
        order_summary = data["order_basket_summary"]
        basket_distribution = data["basket_size_distribution"]
        save(basket_distribution, "basket_size_distribution.csv")
        save_line(basket_distribution, "basket_size", "order_count", "Basket Size Distribution", "basket_size_distribution.png")

        # Additional basket summaries computed from validated SQL output.
        basket_day = (
            order_summary.groupby("order_dow", as_index=False)
            .agg(
                orders=("order_id", "nunique"),
                average_basket_size=("basket_size", "mean"),
                reorder_rate_pct=("reordered_items", lambda s: 100 * s.sum() / order_summary.loc[s.index, "basket_size"].sum()),
            )
            .sort_values("order_dow")
        )
        basket_hour = (
            order_summary.groupby("order_hour_of_day", as_index=False)
            .agg(
                orders=("order_id", "nunique"),
                average_basket_size=("basket_size", "mean"),
                reorder_rate_pct=("reordered_items", lambda s: 100 * s.sum() / order_summary.loc[s.index, "basket_size"].sum()),
            )
            .sort_values("order_hour_of_day")
        )
        save(basket_day, "basket_metrics_by_day.csv")
        save(basket_hour, "basket_metrics_by_hour.csv")

        # ------------------------------------------------------
        # 6. Reorder EDA
        # ------------------------------------------------------
        header("7. REORDER EDA")
        reorder = data["reorder_summary"]
        reorder_seq = data["reorder_by_sequence"]
        save(reorder, "reorder_summary.csv")
        save(reorder_seq, "reorder_by_order_sequence.csv")
        reorder_distribution = create_reorder_distribution(reorder)
        save(reorder_distribution, "reorder_distribution.csv")
        save_line(reorder_seq, "order_number", "reorder_rate_pct", "Reorder Rate by Order Sequence", "reorder_by_order_sequence.png")

        # ------------------------------------------------------
        # 7. Product EDA
        # ------------------------------------------------------
        header("8. PRODUCT PERFORMANCE EDA")
        product = data["product_performance"]
        save(product, "product_performance_all.csv")
        save_bar(product, "product_name", "purchase_count", "Top 20 Products by Purchase Count", "top_20_products.png", top_n=20, horizontal=True)

        # ------------------------------------------------------
        # 8. Reorder opportunity candidates
        # ------------------------------------------------------
        header("9. REORDER / RECOMMENDATION OPPORTUNITY")
        reorder_opportunity = create_reorder_opportunity(product)
        save(reorder_opportunity, "reorder_opportunity_products.csv")
        save_bar(reorder_opportunity, "product_name", "reorder_rate_pct", "High-Reorder Products", "high_reorder_products.png", top_n=20, horizontal=True)

        # ------------------------------------------------------
        # 9. Department EDA
        # ------------------------------------------------------
        header("10. DEPARTMENT PERFORMANCE EDA")
        department = data["department_performance"]
        save(department, "department_performance.csv")
        save_bar(department, "department", "purchase_count", "Purchases by Department", "department_purchase_count.png", rotation=45)
        save_bar(
            department.sort_values("reorder_rate_pct", ascending=False),
            "department",
            "reorder_rate_pct",
            "Department Reorder Rate",
            "department_reorder_rate.png",
            rotation=45,
        )

        # ------------------------------------------------------
        # 10. Aisle EDA
        # ------------------------------------------------------
        header("11. AISLE PERFORMANCE EDA")
        aisle = data["aisle_performance"]
        save(aisle, "aisle_performance_all.csv")
        save_bar(aisle, "aisle", "purchase_count", "Top 20 Aisles by Purchase Count", "top_20_aisles.png", top_n=20, horizontal=True)

        # ------------------------------------------------------
        # 11. Customer EDA
        # ------------------------------------------------------
        header("12. CUSTOMER BEHAVIOR EDA")
        customer = data["customer_behavior"]
        save(customer, "customer_behavior.csv")

        stats = create_customer_statistics(customer)
        save(stats, "customer_descriptive_statistics.csv")
        print(stats.to_string(index=False))

        numeric = [
            "total_orders", "total_items", "unique_products", "reordered_items",
            "avg_basket_size", "reorder_rate_pct", "avg_days_between_orders"
        ]
        corr, spearman = create_spearman_analysis(customer)
        save(corr.reset_index(), "customer_spearman_correlation_matrix.csv")
        save(spearman, "customer_spearman_analysis.csv")
        save_heatmap(corr, "Customer Behavior Spearman Correlation", "customer_spearman_heatmap.png")

        # ------------------------------------------------------
        # 12. Frequency / purchase-gap EDA
        # ------------------------------------------------------
        header("13. CUSTOMER FREQUENCY + PURCHASE GAP EDA")
        frequency = data["customer_frequency"]
        gap = data["customer_purchase_gap_distribution"]
        save(frequency, "customer_frequency.csv")
        save(gap, "purchase_gap_distribution.csv")
        save_hist(customer, "total_orders", "Customer Order Frequency", "customer_order_frequency.png")
        save_hist(customer, "avg_basket_size", "Customer Average Basket Size", "customer_avg_basket_size.png")
        save_hist(customer, "reorder_rate_pct", "Customer Reorder Rate Distribution", "customer_reorder_rate_distribution.png")
        save_line(gap, "days_since_prior_order", "orders", "Orders by Days Since Prior Order", "purchase_gap_distribution.png")

        # ------------------------------------------------------
        # 13. Behavioral segmentation
        # ------------------------------------------------------
        header("14. CUSTOMER BEHAVIORAL SEGMENTATION")
        segments = create_behavior_segments(customer)
        segment_summary = create_segment_summary(segments)
        save(segments, "customer_behavioral_segments.csv")
        save(segment_summary, "customer_behavioral_segment_summary.csv")
        save_bar(segment_summary, "behavior_segment", "customers", "Customer Behavioral Segments", "customer_behavior_segments.png", rotation=45)
        print(segment_summary.to_string(index=False))

        # ------------------------------------------------------
        # 14. Analytical missingness profile
        # ------------------------------------------------------
        header("15. PYTHON ANALYTICAL MISSINGNESS PROFILE")
        analytical_frames = {
            "executive_kpi": kpi,
            "orders_by_day": day,
            "orders_by_hour": hour,
            "basket_distribution": basket_distribution,
            "reorder_summary": reorder,
            "product_performance": product,
            "department_performance": department,
            "aisle_performance": aisle,
            "customer_behavior": customer,
        }
        missingness = create_missingness_report(analytical_frames)
        save(missingness, "python_analytical_missingness.csv", REPORT_DIR)
        unexpected_nulls = int((missingness["null_count"] > 0).sum())
        info(f"Analytical columns with NULL values: {unexpected_nulls}")

        # The literal 'missing' department is not NULL and is legitimate.
        info("Literal department='missing' remains valid source semantics and is not treated as an error.")

        # ------------------------------------------------------
        # 15. Customer IQR outliers
        # ------------------------------------------------------
        header("16. CUSTOMER IQR OUTLIER ANALYSIS")
        outlier_report = create_iqr_report(customer, numeric)
        save(outlier_report, "customer_iqr_outliers.csv")
        print(outlier_report.to_string(index=False))

        # ------------------------------------------------------
        # 16. Market Basket Association Analysis
        # ------------------------------------------------------
        universe = data["market_basket_product_universe"]
        mba = get_market_basket_from_sql(conn, universe)
        save(mba, "market_basket_associations.csv")
        if not mba.empty:
            validate_market_basket(mba)
            save_bar(
                mba,
                "product_pair",
                "lift",
                "Top Product Associations by Lift",
                "market_basket_top_lift.png",
                top_n=20,
                horizontal=True,
            )

        # ------------------------------------------------------
        # 17. Methodology controls
        # ------------------------------------------------------
        header("17. METHODOLOGY CHECK")
        methodology = pd.DataFrame({
            "item": [
                "Primary historical analysis set",
                "TRAIN role",
                "TEST role",
                "Revenue/profit analysis",
                "Standard RFM",
                "Demographic segmentation",
                "Confirmed true churn",
                "Market Basket universe",
                "Minimum pair orders",
            ],
            "value": [
                "PRIOR",
                "Reference / validation only",
                "Not treated as completed historical transactions",
                "Not performed",
                "Not performed",
                "Not supported by dataset",
                "Not claimed",
                f"Top {BASKET_TOP_N} products",
                MIN_PAIR_ORDERS,
            ],
        })
        save(methodology, "methodology_controls.csv", REPORT_DIR)
        print(methodology.to_string(index=False))

        # ------------------------------------------------------
        # 18. Business highlights
        # ------------------------------------------------------
        header("18. BUSINESS HIGHLIGHTS")
        highlights = create_business_highlights(kpi, day, hour, product, department, gap, mba)
        save(highlights, "business_highlights.csv", REPORT_DIR)
        print(highlights.to_string(index=False))

        # ------------------------------------------------------
        # 19. SQL ↔ Python reconciliation
        # ------------------------------------------------------
        cross_validation = run_cross_validation(data, kpi, mba)

        # ------------------------------------------------------
        # 20. Final Python validation
        # ------------------------------------------------------
        final_validation = final_python_validation(data, kpi, segments, segment_summary, mba)

        # ------------------------------------------------------
        # 21. Run manifest
        # ------------------------------------------------------
        end = datetime.now()
        duration = round((end - start).total_seconds(), 2)
        manifest = pd.DataFrame({
            "property": [
                "database",
                "analysis_set",
                "basket_top_n",
                "minimum_pair_orders",
                "maximum_associations",
                "minimum_reorder_product_purchases",
                "start_time",
                "end_time",
                "duration_seconds",
                "python_version",
                "source_policy",
            ],
            "value": [
                DB_NAME,
                ANALYSIS_SET,
                BASKET_TOP_N,
                MIN_PAIR_ORDERS,
                MAX_ASSOCIATIONS,
                MIN_REORDER_PRODUCT_PURCHASES,
                start.isoformat(),
                end.isoformat(),
                duration,
                sys.version,
                "analytics.* validated outputs only; no public.* reads for EDA",
            ],
        })
        save(manifest, "run_manifest.csv", REPORT_DIR)

        # ------------------------------------------------------
        # FINAL STATUS
        # ------------------------------------------------------
        header("PYTHON EDA V2 — FINAL STATUS")
        for item in [
            "Validated SQL analytical objects",
            "SQL analytical output contract validation",
            "Executive KPI EDA",
            "Purchase timing EDA",
            "Basket behavior EDA",
            "Reorder EDA",
            "Product performance EDA",
            "Reorder opportunity candidates",
            "Department performance EDA",
            "Aisle performance EDA",
            "Customer behavior EDA",
            "Customer frequency / purchase-gap EDA",
            "Behavioral segmentation",
            "Spearman statistical exploration",
            "IQR outlier analysis",
            "Python Market Basket Analysis",
            "Methodology controls",
            "SQL ↔ Python cross-validation",
            "Final Python analytical validation",
        ]:
            ok(item)

        print("\nOutput folders:")
        print(f"CSV     : {CSV_DIR}")
        print(f"Charts  : {CHART_DIR}")
        print(f"Reports : {REPORT_DIR}")
        header("PYTHON EDA V2 COMPLETED SUCCESSFULLY")
        return 0

    finally:
        conn.close()
        print("\nPostgreSQL connection closed.")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nProcess cancelled by user.")
        raise SystemExit(1)
    except Exception as exc:
        header("PYTHON EDA V2 FAILED")
        fail(str(exc))
        print(f"Review reports here: {REPORT_DIR}")
        raise SystemExit(1)
