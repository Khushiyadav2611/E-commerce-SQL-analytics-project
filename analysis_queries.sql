-- ============================================================
-- E-Commerce Sales & Customer Analytics
-- All queries written and debugged by hand.
-- ============================================================


-- Q1. Top-line KPIs: total orders, total revenue, average order value
SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS total_revenue,
    SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) / COUNT(DISTINCT o.order_id) AS average_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id;


-- Q2. Top customers by revenue
SELECT c.customer_name,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_revenue DESC
LIMIT 10;


-- Q3. Revenue by region
SELECT c.region,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS total_revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.region
ORDER BY total_revenue DESC;


-- Q4. Repeat customer rate
WITH order_counts AS (
    SELECT customer_id, COUNT(*) AS n_orders
    FROM orders
    GROUP BY customer_id
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    SUM(CASE WHEN n_orders > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100 AS repeat_rate_pct
FROM order_counts;


-- Q5. Top 3 products per category, ranked by revenue
WITH ranked_products AS (
    SELECT category, product_name, total_revenue,
           RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS category_rank
    FROM (
        SELECT p.category, p.product_id, p.product_name,
               SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS total_revenue
        FROM products p
        JOIN order_items oi ON p.product_id = oi.product_id
        GROUP BY p.category, p.product_id, p.product_name
    ) AS product_revenue
)
SELECT category, product_name, total_revenue, category_rank
FROM ranked_products
WHERE category_rank <= 3;


-- Q6. Month-over-month revenue growth
WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100.0)) AS revenue
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS previous_month_revenue,
    ((revenue - LAG(revenue) OVER (ORDER BY order_month))
        / LAG(revenue) OVER (ORDER BY order_month)) * 100 AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;


-- Q7. Pareto analysis: what % of customers drive what % of revenue
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


-- Q8. Customer recency segmentation
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
