---- month-over-month sales growth for each product ----
WITH sales AS (
SELECT
	productkey,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE)) AS sales_year,
	DATE_PART('month', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE)) AS sales_month,
	SUM(salestotal) AS total_monthly_sales
FROM
	dbo.factsalesorder
GROUP BY
	productkey,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE)),
	DATE_PART('month', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))
)
SELECT
	ms.productkey,
	ms.sales_year,
	ms.sales_month,
	ms.total_monthly_sales,
	LAG(ms.total_monthly_sales) OVER(PARTITION BY ms.productkey ORDER BY ms.sales_year, ms.sales_month) AS previous_monthly_sales,
	(ms.total_monthly_sales - LAG(ms.total_monthly_sales) OVER(PARTITION BY ms.productkey ORDER BY ms.sales_year, ms.sales_month)) AS month_over_month_growth
FROM
	sales ms;

---- Average sales per weekday for each product category ----
SELECT
	p.category,
	d.weekdayname,
	ROUND(AVG(salestotal), 2) AS average_sales
FROM
	dbo.factsalesorder f
JOIN
	dbo.dimdate d
	ON f.salesorderdatekey = d.datekey
JOIN 
	dbo.dimproduct p
	ON f.productkey = p.productkey
WHERE 
	d.weekdayname NOT IN ('Saturday', 'Sunday')
GROUP BY
	p.category,
	d.weekdayname
ORDER BY
	average_sales,
	d.weekdayname

---- Percentage contribution of each product to total sales within its category ----
WITH sales AS (
SELECT
	p.productkey,
	p.category,
	SUM(f.salestotal) AS  total_sales
FROM
	dbo.factsalesorder f
JOIN
	dbo.dimproduct p
	ON f.productkey = p.productkey
GROUP BY
	p.productkey,
	p.category
)
SELECT
	ts.productkey,
	ts.category,
	ts.total_sales,
	SUM(ts.total_sales) OVER (PARTITION BY ts.category ORDER BY ts.category, ts.productkey )  AS total_per_category,
	ROUND((( ts.total_sales * 100)/ SUM(ts.total_sales) OVER (PARTITION BY ts.category ORDER BY ts.category, ts.productkey)), 2) AS percentage_contribution
FROM
	sales ts


----Customers who placed orders in at least 3 different years----
SELECT
	customerkey,
	COUNT(DISTINCT DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))) AS orders_year
FROM
	dbo.factsalesorder
GROUP BY
	customerkey
HAVING
	COUNT(DISTINCT DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))) >= 3

----Products that have a higher average sales total on weekends than weekdays.----
SELECT
	f.productkey,
	ROUND(AVG(CASE WHEN d.weekdayname IN ('Saturday', 'Sunday')
			 THEN f.salestotal END), 2) AS average_weekend_sales,
	ROUND(AVG(CASE WHEN d.weekdayname NOT IN ('Saturday', 'Sunday')
			 THEN f.salestotal END), 2) AS average_weekday_sales
FROM
	dbo.factsalesorder f
JOIN
	dbo.dimdate d
	ON f.salesorderdatekey = d.datekey
GROUP BY
	f.productkey
HAVING
	AVG(CASE WHEN d.weekdayname IN ('Saturday', 'Sunday')
			 THEN f.salestotal END)
			>
	AVG(CASE WHEN d.weekdayname NOT IN ('Saturday', 'Sunday')
			 THEN f.salestotal END) 
ORDER BY
	f.productkey

---- Top-selling product per year using a correlated subquery ----
WITH sales AS (
SELECT
	productkey,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE)) AS orders_year,
	SUM(salestotal) AS total_sales
FROM
	dbo.factsalesorder 
GROUP BY
	productkey,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))
)
SELECT
	s.productkey,
	s.orders_year,
	s.total_sales
FROM
	sales s
WHERE
	s.total_sales = (
					SELECT MAX(sub.total_sales)
					FROM sales sub
					WHERE sub.orders_year = s.orders_year
					)
ORDER BY
	s.orders_year,
	s.productkey

---- Customers whose total sales dropped by more than 50% compared to the previous year----
WITH sales AS (
SELECT
	customerkey,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE)) AS sales_year,
	SUM(salestotal) AS total_sales
FROM
	dbo.factsalesorder
GROUP BY
	customerkey,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))
),
lag_calculations AS(
SELECT
	s.customerkey,
	s.sales_year,
	s.total_sales,
	LAG(s.total_sales) OVER( PARTITION BY s.customerkey ORDER BY s.sales_year) AS previous_year_total_sales,
	ROUND(
		(s.total_sales - LAG(s.total_sales) OVER( PARTITION BY s.customerkey ORDER BY s.sales_year)) / 
		COALESCE(LAG(s.total_sales) OVER( PARTITION BY s.customerkey ORDER BY s.sales_year), 0) * 100, 2) AS percentage_change
FROM
	sales s
)
SELECT
	l.customerkey,
	l.sales_year,
	l.total_sales,
	l.previous_year_total_sales,
	l.percentage_change
FROM
	lag_calculations l
WHERE
	l.previous_year_total_sales IS NOT NULL AND 
	l.total_sales < (0.5 * l.previous_year_total_sales)
ORDER BY
	l.sales_year,
	l.percentage_change,
	l.customerkey

---- Report showing total sales per month for each product category ----
WITH sales AS (
SELECT
	p.category,
	DATE_PART('year', CAST(CAST(f.salesorderdatekey AS CHAR(8)) AS DATE)) AS sales_year,
	DATE_PART('month', CAST(CAST(f.salesorderdatekey AS CHAR(8)) AS DATE)) AS sales_month,
	SUM(f.salestotal) AS total_sales
FROM
	dbo.factsalesorder f
JOIN
	dbo.dimproduct p
	ON p.productkey = f.productkey
GROUP BY
	p.category,
	DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE)),
	DATE_PART('month', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))
)
SELECT
	s.category,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 1), 0) AS jan_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 2), 0) AS feb_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 3), 0) AS mar_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 4), 0) AS apr_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 5), 0) AS may_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 6), 0) AS june_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 7), 0) AS july_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 8), 0) AS aug_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 9), 0) AS sep_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 10), 0) AS oct_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 11), 0) AS nov_sales,
	COALESCE(SUM(s.total_sales) FILTER (WHERE s.sales_month = 12), 0) AS dec_sales
FROM
	sales s
GROUP BY
	s.category
ORDER BY 
	s.category

	
---Optimize a query that joins all four tables and filters by year, category, and country.
SELECT
	p.category,
	d."Year",
	c.countryregion,
	SUM(f.salestotal) AS total_sales
FROM
	dbo.factsalesorder f
JOIN
	dbo.dimproduct p
	ON p.productkey = f.productkey
JOIN
	dbo.dimdate d
	ON f.salesorderdatekey = d.datekey
JOIN
	dbo.dimcustomer c
	ON c.customerkey = f.customerkey
WHERE
	p.category = 'Road Bikes' AND
	d."Year" = 2022 OR
	c.countryregion = 'Cananda'
GROUP BY
	p.category,
	d."Year",
	c.countryregion
ORDER BY
	total_sales
