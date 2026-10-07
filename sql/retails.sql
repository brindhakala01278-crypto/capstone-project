use retail_database;

-- show tables
show tables;

-- table cloumns and type,null,default ..
describe customers;

-- question
-- 1. Revenue & AOV across Demographics:What is the total revenue and average order value (AOV) generated across different customer gender and age group demographics?
SELECT c.gender, c.age_group, SUM(oi.quantity * p.selling_price) AS total_revenue, 
    AVG(oi.quantity * p.selling_price) AS avg_order_value
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY c.gender, c.age_group;

-- Key Takeaway: Female buyers in the 36–45 age group generate the highest gross revenue (~₹131.99M), 
-- while older demographics (56–65) exhibit higher individual order values (~₹8,138).

-- 2.Customer Base Distribution across Loyalty Tiers
-- Question: What is the proportional distribution of our overall customer base across defined  loyalty tiers (e.g., Loyal, New, Returning)?

SELECT customer_segment, COUNT(customer_id) AS customer_count,
    ROUND(COUNT(customer_id) * 100.0 / (SELECT COUNT(*) FROM customers), 2) AS pct_distribution
FROM customers GROUP BY customer_segment
ORDER BY customer_count DESC;

-- Key Takeaway: New customers make up 50.23% of the user base, Returning customers comprise 34.97%, and  high-value Loyal customers represent 14.80%.

-- 3. Loyal Customer Spending in Key Age Groups
-- Question: What proportion of high-value "Loyal" customers belong to key age segments (26–35 and 36–45), and how does their spending correlate with age?

SELECT c.age_group, COUNT(DISTINCT c.customer_id) AS loyal_customer_count,
    SUM(oi.quantity * p.selling_price) AS total_revenue,
    ROUND(AVG(oi.quantity * p.selling_price), 2) AS avg_spend_per_item
FROM customers c JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE c.customer_segment = 'Loyal' AND c.age_group IN ('26-35', '36-45')
GROUP BY c.age_group;

-- Key Takeaway: The 36–45 age group forms the largest cohort of loyal customers (2,087 users) and accounts for over ₹57.24M  in total revenue.

-- 4. Audit of Missing Geographic ZIP Codes
-- Question: How many customer records have missing or incomplete geographic ZIP codes, and does this impact regional sales tracking?

SELECT COUNT(DISTINCT c.customer_id) AS missing_zip_customers,
COALESCE(SUM(oi.quantity * p.selling_price), 0) AS affected_revenue
FROM customers c LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE c.customer_zip_code IS NULL OR c.customer_zip_code = '';


-- Key Takeaway: Clean data hygiene across the customer master table ensures 100% geographic coverage with 0 missing ZIP codes.

-- 5. Discount Elasticity & Optimal Discount Range
-- Question: How does customer purchasing volume respond across different discount percentage tiers, and what is 
-- the optimal discount range that maximizes order demand and overall sales revenue?
SELECT CASE 
        WHEN oi.`discount(%)` = 0 THEN '0%'
        WHEN oi.`discount(%)` BETWEEN 1 AND 10 THEN '1-10%'
        WHEN oi.`discount(%)` BETWEEN 11 AND 20 THEN '11-20%'
        WHEN oi.`discount(%)` BETWEEN 21 AND 30 THEN '21-30%'
        ELSE '30%+'
    END AS discount_tier,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * p.selling_price) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY discount_tier
ORDER BY total_revenue DESC;

-- Key Takeaway: The 11–20% discount tier yields the highest total sales revenue (~₹373.5M across 68,276 units),identifying it as the optimal promotional sweet spot.
-- subquer in from clause
-- 6. Top 10 Product Brands by Revenue
-- Question: Which top 10 product brands generate  the highest total sales volume, and should inventory allocation be prioritized for them?
SELECT brand, total_revenue
FROM (
    SELECT p.brand, SUM(oi.quantity * p.selling_price) AS total_revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.brand
) AS brand_sales
ORDER BY total_revenue DESC
LIMIT 10;

-- Key Takeaway: Domestic volume drivers like Generic Indian (₹594M) and furniture brands like Urban Ladder,  Pepperfry, and Nilkamal lead overall revenue generation

-- 7. Stock Availability Performance
-- Question: Does product stock availability status significantly correlate with sales  performance and item popularity?


SELECT 
    p.stock_availability, 
    SUM(oi.quantity) AS total_units_sold, 
    SUM(oi.quantity * p.selling_price) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.stock_availability
ORDER BY total_revenue DESC;

-- Key Takeaway: Items marked In Stock account for 96.5% of total revenue (~₹1.14B), confirming that product availability directly limits sales potential.


-- store procedure:
-- 8. Month-over-Month Revenue Growth Trend
-- Question: What is the month-over-month sales revenue growth trend, and are there seasonal demand spikes over time?


DELIMITER //

CREATE PROCEDURE GetMonthlyRevenueByYear (
    IN input_year INT
)
BEGIN
    SELECT 
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS sales_month,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.quantity * p.selling_price) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE YEAR(o.order_purchase_timestamp) = input_year
    GROUP BY sales_month
    ORDER BY sales_month ASC;
END //

DELIMITER ;


-- Runs the monthly revenue report dynamically for the year 2024
CALL GetMonthlyRevenueByYear(2024);

-- Key Takeaway: Tracking monthly sales run-rates helps forecast quarterly inventory buffer requirements and identify Q4 seasonal demand surges.


-- 9. Average Order Fulfillment Cycle Time
-- Question: What is the average total fulfillment cycle time (from order placement to customer delivery), and where do operational lags occur?

SELECT 
    p.Category_name,
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)), 1) AS avg_fulfillment_days,
    COUNT(DISTINCT o.order_id) AS order_count
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY p.Category_name
ORDER BY avg_fulfillment_days DESC;

-- Key Takeaway: The overall fulfillment cycle averages ~72 days across categories, highlighting operational bottlenecks in long-distance logistics channels.


-- 10. Shipping Cost vs. Package Weight Scaling
-- Question: How efficiently do shipping costs scale relative to package weight, and are there pricing anomalies in freight charges?

SELECT 
    FLOOR(p.product_weight_g / 500) * 500 AS weight_bin_g, 
    ROUND(AVG(oi.shipping_cost), 2) AS avg_shipping_cost,
    COUNT(oi.order_item_id) AS total_items
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY weight_bin_g
ORDER BY weight_bin_g ASC;

-- Key Takeaway: Binning package weight by 500g increments confirms whether carrier shipping rates scale linearly or exhibit surcharge jumps.

-- 11. Geographic Delivery Delays by State
-- Question: Which geographic states experience the longest delivery delays relative to their estimated delivery dates?

SELECT 
    g.geolocation_state, 
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)), 1) AS avg_delay_days,
    COUNT(o.order_id) AS delayed_orders_count
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN geolocation g ON c.customer_zip_code = g.geolocation_zip_code
WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
GROUP BY g.geolocation_state
ORDER BY avg_delay_days DESC;

-- Key Takeaway: Isolating delivery SLA breaches by state helps logistics teams re-evaluate regional fulfillment center placements.



-- 12. Order Return & Cancellation Proportions
-- Question: What proportion of customer orders are canceled or remain unfulfilled, and what are the primary contributing factors?

SELECT 
    order_status, 
    COUNT(order_id) AS total_orders,
    ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage
FROM orders
GROUP BY order_status;

-- Key Takeaway: Successfully delivered orders account for 92.39% of volume, while returned orders make up 7.61%.


-- 13. Delivery Delay Impact on Low Customer Ratings
-- Question: How significantly do delivery delays and extended shipping times drive 1-star and 2-star customer ratings?

SELECT 
    r.review_score, 
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)), 1) AS avg_delay_days,
    COUNT(r.review_id) AS total_reviews
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
WHERE r.review_score IN (1, 2)
GROUP BY r.review_score;

-- Key Takeaway: Orders resulting in low ratings show a direct link to shipping SLA breaches compared to on-time deliveries

-- 14. Customer Satisfaction across Payment Channels
-- Question: Does average customer review satisfaction vary significantly depending on the payment channel selected at checkout 
-- (e.g., Credit Card, UPI, Net Banking, Cash on Delivery)?

SELECT 
    o.payment_type, 
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY o.payment_type
ORDER BY avg_review_score DESC;

-- Key Takeaway: Review scores remain consistent across payment channels, averaging ~4.10 for Credit Card and Net Banking down to ~4.08 for Cash on Delivery.


-- 15. Logistics Delay Comparison: 1-Star vs. 5-Star Reviews
-- Question: What is the average delivery delay time experienced by orders resulting in 1-star review scores compared to top-rated 5-star orders,
-- and how heavily do extreme logistics delays drive negative customer reviews?
SELECT 
    r.review_score, 
    ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)), 1) AS avg_delay_days,
    MAX(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)) AS max_delay_days,
    COUNT(r.review_id) AS total_reviews
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
WHERE r.review_score IN (1, 5)
GROUP BY r.review_score;

-- Key Takeaway: 1-star reviews suffer from significantly higher maximum delivery delay spikes than 5-star orders.



-- correlation
-- Correlation: Discount % vs. Selling Price
SELECT 
    (
        COUNT(*) * SUM(oi.`discount(%)` * p.selling_price) - 
        (SUM(oi.`discount(%)`) * SUM(p.selling_price))
    ) / 
    (
        SQRT(COUNT(*) * SUM(POWER(oi.`discount(%)`, 2)) - POWER(SUM(oi.`discount(%)`), 2)) * 
        SQRT(COUNT(*) * SUM(POWER(p.selling_price, 2)) - POWER(SUM(p.selling_price), 2))
    ) AS correlation_discount_vs_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id;


-- 2. Correlation: Delivery Delay vs. Review Score

WITH delay_data AS (
    SELECT 
        DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_delay,
        r.review_score
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT 
    (
        COUNT(*) * SUM(delivery_delay * review_score) - 
        (SUM(delivery_delay) * SUM(review_score))
    ) / 
    (
        SQRT(COUNT(*) * SUM(POWER(delivery_delay, 2)) - POWER(SUM(delivery_delay), 2)) * 
        SQRT(COUNT(*) * SUM(POWER(review_score, 2)) - POWER(SUM(review_score), 2))
    ) AS correlation_delay_vs_review_score
FROM delay_data;


-- MySQL Query for selling_price Statistics
WITH ordered_data AS (
    SELECT 
        selling_price,
        ROW_NUMBER() OVER (ORDER BY selling_price) AS row_num,
        COUNT(*) OVER () AS total_count
    FROM products
),
median_calc AS (
    SELECT AVG(selling_price) AS median
    FROM ordered_data
    WHERE row_num IN (FLOOR((total_count + 1) / 2), FLOOR((total_count + 2) / 2))
),
mode_calc AS (
    SELECT selling_price AS mode
    FROM products
    GROUP BY selling_price
    ORDER BY COUNT(*) DESC, selling_price ASC
    LIMIT 1
)
SELECT 
    -- Central Tendency
    AVG(p.selling_price) AS mean,
    m.median,
    mo.mode,
    
    -- Dispersion
    MIN(p.selling_price) AS min_val,
    MAX(p.selling_price) AS max_val,
    (MAX(p.selling_price) - MIN(p.selling_price)) AS `range`,
    VARIANCE(p.selling_price) AS `variance`,
    STDDEV(p.selling_price) AS std_dev,
    
    -- Fisher-Pearson Skewness Formula
    (
        (COUNT(*) * SUM(POWER(p.selling_price - avg_table.avg_sp, 3))) / 
        ((COUNT(*) - 1) * (COUNT(*) - 2) * POWER(STDDEV_SAMP(p.selling_price), 3))
    ) AS skewness

FROM products p
CROSS JOIN median_calc m
CROSS JOIN mode_calc mo
CROSS JOIN (SELECT AVG(selling_price) AS avg_sp FROM products) avg_table;


-- outlier


WITH RankedData AS (
    SELECT 
        oi.unit_price,
        ROW_NUMBER() OVER (ORDER BY oi.unit_price) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM order_items oi
),
Quartiles AS (
    SELECT 
        MAX(CASE WHEN row_num = FLOOR(0.25 * total_rows) THEN unit_price END) AS Q1,
        MAX(CASE WHEN row_num = FLOOR(0.75 * total_rows) THEN unit_price END) AS Q3
    FROM RankedData
)
SELECT 
    'unit price' AS variable,
    Q1,
    Q3,
    (Q3 - Q1) AS IQR,
    (Q1 - 1.5 * (Q3 - Q1)) AS `Lower limit`,
    (Q3 + 1.5 * (Q3 - Q1)) AS `upper limit`
FROM Quartiles;
