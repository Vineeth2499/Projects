--Creating Table Customers and Spends

CREATE TABLE Customers (
   customer_id INT PRIMARY KEY,
   age_group VARCHAR,
   city TEXT,
   occupation TEXT,
   gender TEXT,
   marital_status TEXT,
   avg_income INT
)

--Altering column data type in customer table

ALTER TABLE Customers
ALTER COLUMN customer_id TYPE TEXT,
ALTER COLUMN age_group TYPE VARCHAR(10);

CREATE TABLE Spends (
   customer_id TEXT,
   month TEXT,
   category TEXT,
   payment_type TEXT,
   spend INT,
   CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
)

-- 1. Customer Demographics Analysis

-- 1.1 Customers by Age Group

WITH Age_Classification AS (
SELECT age_group,
	   COUNT(customer_id) AS total_customers
FROM customers
GROUP BY age_group
), Totals AS (
SELECT SUM(total_customers) AS grand_total FROM Age_Classification
)
SELECT age_group,
       total_customers,
	   CONCAT(ROUND(100.0 * total_customers/grand_total, 2), '%') AS customers_percentage
FROM Age_Classification, Totals
ORDER BY total_customers DESC;

-- 1.2 Customers by Gender

WITH gender_classification AS(
SELECT gender,
	   COUNT(customer_id) AS total_customers
FROM Customers
GROUP BY gender
), Totals AS (
SELECT SUM(total_customers) AS grand_total FROM gender_classification
)
SELECT gender,
       total_customers,
	   CONCAT(ROUND(100.0 * total_customers/grand_total, 2), '%') AS customers_percentage
FROM gender_classification, totals
ORDER BY total_customers DESC;

-- 1.3 Customers by City

SELECT city,
       COUNT(*) AS Total_customers
FROM Customers
GROUP BY city
ORDER BY city DESC;

-- 1.4 Customers by Occupation

SELECT occupation,
       COUNT(*) FILTER (WHERE occupation IS NOT NULL) AS total_customers
FROM customers
GROUP BY occupation
ORDER BY total_customers DESC;

-- 2. Income Utilization Insights

-- 2.1 Function: get_avg_income_utilization()

DROP FUNCTION get_avg_income_utilization();

CREATE OR REPLACE FUNCTION get_avg_income_utilization()
RETURNS TABLE (
  out_customer_id TEXT,
  out_avg_income INT,
  out_avg_spends NUMERIC,
  out_avg_income_utilization NUMERIC
)
AS $$
BEGIN
  RETURN QUERY
  WITH spend_stats AS (
    SELECT customer_id,
	       ROUND(AVG(spend), 2) AS avg_spends
    FROM spends
    GROUP BY customer_id
  )
  SELECT 
    c.customer_id AS out_customer_id,
    c.avg_income AS out_avg_income,
    ss.avg_spends AS out_avg_spends,
    ROUND(100.0 * ss.avg_spends / c.avg_income, 2) AS out_avg_income_utilization
  FROM customers c
  JOIN spend_stats ss ON c.customer_id = ss.customer_id;
END;
$$ LANGUAGE plpgsql;

-- 2.2 Avg Income Utilization by Customer

WITH spend_stats AS (
  SELECT customer_id,
	     ROUND(AVG(spend), 2) AS avg_spends
  FROM spends
  GROUP BY customer_id
)
SELECT c.customer_id,
       c.avg_income,
       CONCAT('$', ss.avg_spends) AS avg_spends,
       CONCAT(ROUND(100.0 * ss.avg_spends / c.avg_income, 2), '%') AS avg_income_utilization
FROM customers c
JOIN spend_stats ss ON c.customer_id = ss.customer_id
ORDER BY (100.0 * ss.avg_spends / c.avg_income) DESC;

-- 2.3 Avg Income Utilization by Occupation

SELECT c.occupation,
       CONCAT(ROUND(AVG(g.out_avg_income_utilization), 2), '%') AS Income_utilization_by_occupation
FROM customers c
JOIN get_avg_income_utilization() g
ON c.customer_id = g.out_customer_id
GROUP BY c.occupation
ORDER BY Income_utilization_by_occupation DESC;

-- 2.4 Avg Income Utilization by Gender

SELECT c.gender,
       CONCAT(ROUND(AVG(g.out_avg_income_utilization), 2), '%') AS Income_utilization_by_gender
FROM customers c
JOIN get_avg_income_utilization() g
ON c.customer_id = g.out_customer_id
GROUP BY c.gender
ORDER BY Income_utilization_by_gender DESC;

-- 2.5 Avg Income Utilization by City

SELECT c.city,
       CONCAT(ROUND(AVG(g.out_avg_income_utilization), 2), '%') AS Income_utilization_by_city
FROM customers c
JOIN get_avg_income_utilization() g
ON c.customer_id = g.out_customer_id
GROUP BY c.city
ORDER BY Income_utilization_by_city DESC;

-- 2.6 Avg Income Utilization by Age Group

SELECT c.age_group,
       CONCAT(ROUND(AVG(g.out_avg_income_utilization), 2), '%') AS Income_utilization_by_age_group
FROM customers c
JOIN get_avg_income_utilization() g
ON c.customer_id = g.out_customer_id
GROUP BY c.age_group
ORDER BY Income_utilization_by_age_group DESC;

-- 3. Spending Behavior

-- 3.1 Average Spent per Category (with Ranking)

WITH Average_Spends_Ranking AS(
SELECT category,
	   ROUND(AVG(spend), 2) AS avg_spend_numeric
FROM spends
GROUP BY category
)
SELECT category,
       CONCAT('$', avg_spend_numeric) AS average_spends,
       RANK() OVER(ORDER BY avg_spend_numeric DESC) AS category_ranking
FROM Average_Spends_Ranking;

-- 3.2 Top Spending Categories by Occupation (Ranked)

WITH average_spend_ranking AS (
  SELECT c.occupation,
	     s.category,
         ROUND(AVG(spend), 2) AS average_spends
  FROM customers c
  JOIN spends s ON c.customer_id = s.customer_id
  GROUP BY c.occupation, s.category
),
ranked_data AS (
  SELECT occupation,
         category,
	     average_spends,
         RANK() OVER (PARTITION BY category ORDER BY average_spends DESC) AS spends_ranking
  FROM average_spend_ranking
)
SELECT *
FROM ranked_data
WHERE spends_ranking <= 5;

-- 3.3 Average Spends by Payment Type

SELECT payment_type,
       ROUND(AVG(spend), 2) AS average_spends
FROM spends
GROUP BY payment_type;

-- 3.4 Top Spenders by Customer (Total Spends)

SELECT c.customer_id,
       SUM(s.spend) AS total_spends
FROM spends s
JOIN customers c
ON c.customer_id = s.customer_id
GROUP BY c.customer_id
ORDER BY total_spends DESC;

-- 3.5 Top 3 Categories per Payment Type (Ranked)

WITH spending_total AS (
  SELECT category,
	     payment_type,
	     SUM(spend) AS total_spent
  FROM spends
  GROUP BY 1, 2
),
ranked_spending AS (
  SELECT category,
	     payment_type,
	     total_spent,
         RANK() OVER (PARTITION BY payment_type ORDER BY total_spent DESC) AS spend_ranking
  FROM spending_total
)
SELECT *
FROM ranked_spending
WHERE spend_ranking <= 3;

-- 4. Deep-Dive Analysis

-- 4.1 Avg Spend & Income Utilization by Marital Status

SELECT c.marital_status,
       ROUND(AVG(out_avg_spends), 2) AS avg_spend,
	   CONCAT(ROUND(AVG(out_avg_income_utilization), 2), '%') AS Income_utilization 
FROM get_avg_income_utilization() g
JOIN customers c
ON g.out_customer_id = c.customer_id
GROUP BY c.marital_status;

-- 4.2 Cross-analysis: Gender + Age Group + Occupation → Income Utilization

-- 4.2.1 Income Utilization by Gender + Age

WITH income_utilization_cte AS (
SELECT c.gender,
	   c.age_group,
	   c.occupation,
	   out_avg_spends,
	   out_avg_income_utilization
FROM customers c
JOIN get_avg_income_utilization()
ON c.customer_id = get_avg_income_utilization.out_customer_id
),
income_utilization_total AS (
SELECT gender,
	   age_group,
	   occupation, 
	   SUM(out_avg_spends) AS total_spends,
	   SUM(out_avg_income_utilization) AS total_income_utilization
FROM income_utilization_cte
GROUP BY gender, age_group, occupation
)
SELECT *
FROM (
	  SELECT *, 
			 RANK() OVER (PARTITION BY gender, age_group ORDER BY total_income_utilization DESC) AS rank_gender_age
	  FROM income_utilization_total
	) ranked_data

-- 4.2.2 Income Utilization by Occupation

WITH income_utilization_cte AS (
SELECT c.gender,
	   c.age_group,
	   c.occupation, 
	   out_avg_spends,
	   out_avg_income_utilization
FROM customers c
JOIN get_avg_income_utilization()
ON c.customer_id = get_avg_income_utilization.out_customer_id
),
income_utilization_total AS (
SELECT gender,
	   age_group,
	   occupation, 
SUM(out_avg_spends) AS total_spends, 
SUM(out_avg_income_utilization) AS total_income_utilization
FROM income_utilization_cte
GROUP BY 1, 2, 3
)
SELECT *
FROM (
SELECT *, 
	   RANK() OVER (PARTITION BY occupation ORDER BY total_income_utilization DESC) AS rank_occupation
	   FROM income_utilization_total
	) ranked_data
	
-- 4.3 Monthly Spend Trends per City / Occupation (time-pattern)

-- Creating View

CREATE VIEW monthly_city_occupation_spends AS
WITH total_spends_cte AS (
  SELECT 
    c.city, 
    c.occupation,
    s.month, 
    SUM(s.spend) AS total_spends
  FROM spends s
  JOIN customers c ON s.customer_id = c.customer_id
  GROUP BY 1, 2, 3
), spends_ranking AS (
  SELECT 
    city,
    month,
    occupation,
    total_spends,
    RANK() OVER (PARTITION BY city, month ORDER BY total_spends DESC) AS city_month_spends_ranking
  FROM total_spends_cte
)
SELECT * FROM spends_ranking;

SELECT * FROM monthly_city_occupation_spends WHERE city = 'Bengaluru';

-- 4.4 Credit Card Usage

SELECT *, 
  RANK() OVER (PARTITION BY category ORDER BY total_spends DESC) AS rank_in_category
FROM (
  SELECT payment_type,
	     category,
	     SUM(spend) AS total_spends
  FROM spends
  GROUP BY payment_type, category
) ranked_data;


-- 5 High Value Customers using Pareto Principle

WITH customer_spends AS (
  SELECT customer_id,
	     SUM(spend) AS total_spend
  FROM spends
  GROUP BY customer_id
),
ordered_spends AS (
  SELECT *,
         RANK() OVER (ORDER BY total_spend DESC) AS spend_rank,
         SUM(total_spend) OVER (ORDER BY total_spend DESC) AS cumulative_spend
  FROM customer_spends
),
total AS (
  SELECT SUM(total_spend) AS total_spends_all FROM customer_spends
),
FINAL AS (
  SELECT 
    o.customer_id,
    o.total_spend,
    o.cumulative_spend,
    ROUND(100.0 * o.cumulative_spend / t.total_spends_all, 2) AS cumulative_percentage
  FROM ordered_spends o, total t
)
SELECT *
FROM FINAL
WHERE cumulative_percentage <= 80
ORDER BY cumulative_percentage

-- Credit Seekers

-- Finding Median Income

SELECT ROUND(AVG(avg_income), 2) AS "Median_Income"
FROM (
  SELECT avg_income,
         ROW_NUMBER() OVER (ORDER BY avg_income ASC, customer_id ASC) AS RowAsc,
         ROW_NUMBER() OVER (ORDER BY avg_income DESC, customer_id DESC) AS RowDesc
  FROM customers
) data
WHERE RowAsc IN (RowDesc, RowDesc - 1, RowDesc + 1)

-- Utilization of Very Low and Low Income Level Customers

SELECT 
  c.customer_id,
  c.avg_income,
  out_avg_income_utilization AS utilization,
  CASE
    WHEN c.avg_income <= 35000 THEN 'Very Low'
    WHEN c.avg_income <= 50422 THEN 'Low Income'
    WHEN c.avg_income <= 70000 THEN 'Mid Income'
    ELSE 'High Income'
  END AS income_level
FROM customers c
JOIN get_avg_income_utilization()
  ON c.customer_id = out_customer_id
WHERE c.avg_income <= 50422;