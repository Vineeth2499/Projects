-- CTE for Top 3
WITH Top3 AS (
    SELECT 
        maker_name,
        fiscal_year,
        SUM(sales_count) AS total_sales,
        'Top 3' AS category
    FROM dim_date d
    JOIN sales_by_makers m ON d.date = m.date
    WHERE fiscal_year = 2023 AND vehicle_category = '2-Wheelers'
    GROUP BY maker_name, fiscal_year
    ORDER BY total_sales DESC
    LIMIT 3
),

-- CTE for Bottom 3

Bottom3 AS (
    SELECT 
        maker_name,
        fiscal_year,
        SUM(sales_count) AS total_sales,
        'Bottom 3' AS category
    FROM dim_date d
    JOIN sales_by_makers m ON d.date = m.date
    WHERE fiscal_year = 2023 AND vehicle_category = '2-Wheelers'
    GROUP BY maker_name, fiscal_year
    ORDER BY total_sales ASC
    LIMIT 3
)

-- 1) i) TOP and BOTTOM 3 makers by sales in fiscal year 2023

SELECT * 
FROM Top3
UNION ALL
SELECT * 
FROM Bottom3;

-- CTE for Top 3
WITH Top3 AS (
    SELECT 
        maker_name,
        fiscal_year,
        SUM(sales_count) AS total_sales,
        'Top 3' AS category
    FROM dim_date d
    JOIN sales_by_makers m ON d.date = m.date
    WHERE fiscal_year = 2024 AND vehicle_category = '2-Wheelers'
    GROUP BY maker_name, fiscal_year
    ORDER BY total_sales DESC
    LIMIT 3
),

-- CTE for Bottom 3
Bottom3 AS (
    SELECT 
        maker_name,
        fiscal_year,
        SUM(sales_count) AS total_sales,
        'Bottom 3' AS category
    FROM dim_date d
    JOIN sales_by_makers m ON d.date = m.date
    WHERE fiscal_year = 2024 AND vehicle_category = '2-Wheelers'
    GROUP BY maker_name, fiscal_year
    ORDER BY total_sales ASC
    LIMIT 3
)

--ii) TOP and BOTTOM 3 makers by sales in fiscal year 2024

SELECT * 
FROM Top3
UNION ALL
SELECT * 
FROM Bottom3;

2) --Top 5 states with high penetration rate in 2-wheeler and 4-wheeler in FY 2024

WITH sales AS (
    SELECT 
        state, 
        SUM(electric_vehicles_sold) AS total_electric_vehicles, 
        SUM(total_vehicles_sold) AS total_vehicles
    FROM sales_by_state
    WHERE EXTRACT(YEAR FROM date) = 2024
    GROUP BY state
)
SELECT 
    state,
    TO_CHAR(TRUNC((CAST(total_electric_vehicles AS DECIMAL) / CAST(total_vehicles AS DECIMAL)) * 100, 2), 'FM999990.00') || '%' AS penetration_rate
FROM sales
ORDER BY TRUNC((CAST(total_electric_vehicles AS DECIMAL) / CAST(total_vehicles AS DECIMAL)) * 100, 2) DESC
LIMIT 5;

3) --States with negative penetration in EV sales from 2022 to 2024

WITH sales AS (
    SELECT 
        state, 
        SUM(electric_vehicles_sold) AS total_electric_vehicles, 
        SUM(total_vehicles_sold) AS total_vehicles
    FROM sales_by_state
    WHERE EXTRACT(YEAR FROM date) BETWEEN 2022 AND 2024
    GROUP BY state
)
SELECT 
    state,
    TO_CHAR(TRUNC((CAST(total_electric_vehicles AS DECIMAL) / CAST(total_vehicles AS DECIMAL)) * 100, 2), 'FM999990.00') || '%' AS penetration_rate
FROM sales
ORDER BY TRUNC((CAST(total_electric_vehicles AS DECIMAL) / CAST(total_vehicles AS DECIMAL)) * 100, 2) ASC;

4) --Quarterly trends based on sales volume for the top 5 EV makers(4-wheelers)

WITH RankedSales AS (
    SELECT 
        maker_name,
        quarter,
        fiscal_year,
        SUM(sales_count) AS sales_volume,
        RANK() OVER (PARTITION BY fiscal_year, quarter ORDER BY SUM(sales_count) DESC) AS rank
    FROM dim_date d
    JOIN sales_by_makers m ON d.date = m.date
    WHERE vehicle_category = '4-Wheelers' 
      AND fiscal_year BETWEEN 2022 AND 2024
    GROUP BY maker_name, quarter, fiscal_year
)
SELECT maker_name,
       quarter,
       fiscal_year,
       sales_volume
FROM RankedSales
WHERE rank <= 5
ORDER BY quarter ASC, fiscal_year ASC, sales_volume DESC;

5) --EV sales and penetration rates in Delhi compare to Karnataka for 2024

WITH sales AS (
    SELECT 
        state, 
        SUM(electric_vehicles_sold) AS total_electric_vehicles, 
        SUM(total_vehicles_sold) AS total_vehicles
    FROM sales_by_state
    WHERE EXTRACT(YEAR FROM date) = 2024
    GROUP BY state
)
SELECT 
    state,
    total_electric_vehicles,
    TO_CHAR(TRUNC((CAST(total_electric_vehicles AS DECIMAL) / CAST(total_vehicles AS DECIMAL)) * 100, 2), 'FM999990.00') || '%' AS penetration_rate
FROM sales
WHERE state IN ('Delhi', 'Karnataka')
ORDER BY TRUNC((CAST(total_electric_vehicles AS DECIMAL) / CAST(total_vehicles AS DECIMAL)) * 100, 2) DESC;

6) --CAGR in 4-Wheelers for Top 5 makers from 2022 to 2024

SELECT maker_name,
       ROUND(POW(MAX(sales_count) * 1.0/NULLIF(MIN(sales_count),0),
       1.0/(MAX(fiscal_year) - MIN(fiscal_year))) -1, 2) AS CAGR
FROM dim_date d
JOIN sales_by_makers m ON d.date = m.date
WHERE sales_count != 0 AND vehicle_category = '4-Wheelers' AND fiscal_year BETWEEN 2022 AND 2024
GROUP BY 1
ORDER BY CAGR ASC
LIMIT 5;

--7) Top 10 states with highest CAGR from 2022 to 2024 in total vehicles sold

SELECT state,
       ROUND(POW(MAX(total_vehicles_sold) * 1.0 / NULLIF(MIN(total_vehicles_sold), 0), 
       1.0 / (MAX(fiscal_year) - MIN(fiscal_year))) - 1, 2) AS CAGR
FROM dim_date d
JOIN sales_by_state s ON d.date = s.date
WHERE total_vehicles_sold != 0 
  AND fiscal_year BETWEEN 2022 AND 2024
GROUP BY state
HAVING MIN(total_vehicles_sold) > 0 -- Exclude states with zero values
   AND MAX(fiscal_year) - MIN(fiscal_year) > 0 -- Ensure multiple years of data
ORDER BY CAGR DESC
LIMIT 10;

--8) Peak and Low season months for EV sales from 2022 to 2024

WITH sales_rank AS(
SELECT fiscal_year,
       EXTRACT(MONTH FROM d.date) AS month,
       SUM(electric_vehicles_sold) AS ev_sold,
       ROW_NUMBER() OVER (PARTITION BY fiscal_year ORDER BY SUM(electric_vehicles_sold) DESC) AS rank
FROM dim_date d
JOIN sales_by_state s ON d.date = s.date
GROUP BY 1, 2)
SELECT fiscal_year,
       month,
	   ev_sold,
	   rank
FROM sales_rank
WHERE rank = 1
ORDER BY fiscal_year;