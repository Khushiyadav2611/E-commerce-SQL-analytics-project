# E-Commerce Sales & Customer Analytics (SQL)

Analysis of a relational e-commerce dataset (customers, orders, order items, products) using MySQL
to answer core business questions: who are our best customers, which products/regions drive
revenue, how is revenue trending, and how should we segment customers for retention.

**Tools:** MySQL, JOINs, CTEs, window functions (`RANK()`, `ROW_NUMBER()`, `LAG()`, `SUM() OVER`), aggregate queries, `CASE` logic
**Data:** 500 customers · 140 products · 3,200 orders · 7,132 order line items (Jan 2023 – Dec 2024)

> Note: this dataset is synthetically generated with realistic patterns built in — festive-season
> seasonality, customer spend variation, repeat-purchase behavior — so the SQL and findings below
> reflect genuine analysis, not a real company's data.

## Schema

```
customers   (customer_id, customer_name, email, city, region, segment, signup_date)
products    (product_id, product_name, category, sub_category, unit_price, cost_price)
orders      (order_id, customer_id, order_date, ship_date, region, payment_method)
order_items (order_item_id, order_id, product_id, quantity, unit_price, discount_pct)
```
`customers (1)───(many) orders (1)───(many) order_items (many)───(1) products`

Full table definitions in [`schema_mysql.sql`](schema_mysql.sql).

## Key Findings

- **Total revenue: ₹1.44 crore** across 3,200 orders, average order value **₹4,512**.
- **Customer concentration:** the top **21% of customers drive 57% of total revenue** — a clear
  concentration pattern worth acting on for loyalty/retention targeting.
- **87.8% repeat-purchase rate** (410 of 467 customers placed more than one order).
- **Festive season spikes are the clearest trend in the data:** October revenue jumped **+132%
  and +139%** month-over-month in 2023 and 2024 respectively, driven by the Oct–Dec festive period.
- **Electronics leads product revenue** — "Mouse Plus" is the single highest-revenue product
  (₹3.37L), ahead of top sellers in every other category.
- **Regional revenue is fairly balanced:** North (26.3%), South (26.2%), West (25.1%), East
  (22.4%) — no single region is over-dependent, unlike the sharper customer-level concentration.
- **Customer lifecycle split (recency-based):** 151 Active (ordered in last 30 days of the
  dataset), 141 Warm/At Risk (31–90 days), 175 Cold/Churned (90+ days) — roughly a third of the
  customer base needs a win-back campaign.

## Queries & Techniques

All queries below were written and debugged from scratch as part of this project.

| # | Question | SQL technique |
|---|---|---|
| 1 | What are our top-line KPIs (orders, revenue, AOV)? | Aggregate functions |
| 2 | Who are our top customers by revenue? | JOIN + GROUP BY |
| 3 | Which regions drive the most revenue? | JOIN + GROUP BY |
| 4 | What's our repeat customer rate? | CTE + `CASE` + conditional `SUM` |
| 5 | Which product ranks #1 in each category? | CTE + `RANK() OVER (PARTITION BY ...)` |
| 6 | How does revenue trend month-over-month? | CTE + `LAG() OVER` |
| 7 | What % of customers drive what % of revenue? (Pareto) | Chained CTEs + `ROW_NUMBER()` + running `SUM() OVER` |
| 8 | How do we segment customers by recency? | Chained CTEs + `DATEDIFF()` + `CASE` |

### Example: Pareto analysis (customer revenue concentration)

```sql
WITH customer_revenue AS (
    SELECT c.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id
),
ranked_revenue AS (
    SELECT
        customer_id,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC) AS customer_rank,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS running_total
    FROM customer_revenue
)
SELECT
    customer_id,
    revenue,
    customer_rank,
    running_total,
    (customer_rank / COUNT(*) OVER ()) * 100 AS pct_of_customers_so_far,
    (running_total / SUM(revenue) OVER ()) * 100 AS pct_of_revenue_so_far
FROM ranked_revenue
ORDER BY revenue DESC;
```

### Example: Customer recency segmentation

```sql
WITH customer_orders AS (
    SELECT
        c.customer_name,
        MAX(o.order_date) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS monetary
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_name
),
customer_recency AS (
    SELECT
        customer_name, last_order_date, frequency, monetary,
        DATEDIFF('2024-12-31', last_order_date) AS recency_days
    FROM customer_orders
)
SELECT
    customer_name, frequency, monetary, recency_days,
    CASE
        WHEN recency_days <= 30 THEN 'Active'
        WHEN recency_days <= 90 THEN 'Warm / At Risk'
        ELSE 'Cold / Churned'
    END AS customer_status
FROM customer_recency
ORDER BY monetary DESC;
```

The remaining queries follow the same patterns (JOIN → GROUP BY → window function / CASE) and are
included in [`analysis_queries.sql`](analysis_queries.sql).

## How to run

1. Run [`schema_mysql.sql`](schema_mysql.sql) in MySQL to create the database and tables.
2. Load the CSVs (`data/customers.csv`, `data/products.csv`, `data/orders.csv`, `data/order_items.csv`) using
   `LOAD DATA LOCAL INFILE` — customers and products first, then orders, then order_items (foreign
   key order matters).
3. Run the queries in `analysis_queries.sql`.

## Files

| File | Purpose |
|---|---|
| `schema_mysql.sql` | Table definitions |
| `analysis_queries.sql` | All business-question SQL queries |
| `customers.csv`, `products.csv`, `orders.csv`, `order_items.csv` | Raw data tables |
