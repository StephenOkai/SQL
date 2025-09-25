-- Product names and category from DimProduct table
SELECT
    productname,
    category
FROM
    dbo.dimproduct;
	

-- First and Last names of all customers from DimCustomer
SELECT
    firstname,
    lastname
FROM
    dbo.dimcustomer;


-- All columns from DimDate where year is 2025
SELECT 
    *
FROM
    dbo.dimdate d
WHERE
    d."Year" = 2025;


-- Total number of rows in FactSalesOrder
SELECT
    COUNT(*)
FROM
    dbo.factsalesorder;


-- Distinct list of countries from the DimCustomer table
SELECT DISTINCT
    countryregion
FROM
    dbo.dimcustomer;


-- All products with list price > 100
SELECT
    *
FROM 
    dbo.dimproduct
WHERE 
    listprice > 100;


-- All sales orders where quantity > 10
SELECT
    *
FROM
    dbo.factsalesorder
WHERE
    quantity > 10;


-- Customers who live in Amsterdam
SELECT
    *
FROM
    dbo.dimcustomer
WHERE
    city = 'Amsterdam';


-- Weekday name and day of month for all dates in January
SELECT
    weekdayname,
    dayofmonth
FROM
    dbo.dimdate d
WHERE
    monthname = 'January';


-- All columns from DimProduct where categories are Locks and Pumps
SELECT 
    *
FROM
    dbo.dimproduct
WHERE
    category IN ('Locks', 'Pumps');


-- Total sales per product
SELECT
	p.productname,
	SUM(s.quantity * p.listprice) AS totalsales
FROM
	dbo.factsalesorder s
JOIN
	dbo.dimproduct p
	ON s.productkey = p.productkey
GROUP BY 
	p.productname;


-- Customer name and their total number of orders
SELECT
	c.firstname,
	c.lastname,
	COUNT(*) AS totalorders
FROM
	dbo.dimcustomer c
JOIN 
	dbo.factsalesorder s
	ON c.customerkey = s.customerkey
GROUP BY
	c.firstname,
	c.lastname;


--Top 5 products by total sales
SELECT 
	p.productname,
	SUM(s.salestotal) AS totalsales
FROM
	dbo.factsalesorder s
JOIN
	dbo.dimproduct p
	ON s.productkey = p.productkey
GROUP BY 
	p.productname
ORDER BY
	totalsales desc
LIMIT
	5;


-- Average quantity sold per year
SELECT
	d."Year",
	AVG(s.quantity ) AS averagesales
FROM
	 dbo.factsalesorder s
JOIN 
	dbo.dimdate d
	ON s.salesorderkey = d.datekey
GROUP BY
	d."Year";


-- Customers who placed orders totalling more than 1000
SELECT
	c.firstname,
	c.lastname,
	SUM(s.salestotal) AS totalorders
FROM
	dbo.factsalesorder s
JOIN
	dbo.dimcustomer c
	ON c.customerkey = s.customerkey
GROUP BY 
	c.firstname,
	c.lastname
HAVING
	SUM(s.salestotal) > 1000;


--Sales total by month and year
SELECT
	SUM(s.salestotal) as totalsales,
	d."Month",
	d."Year"
FROM
	dbo.factsalesorder s
JOIN 
	dbo.dimdate d
	ON s.salesorderdatekey = d.datekey
GROUP BY
	d."Month",
	d."Year";


-- Products that have never been sold
SELECT
	p.productname
FROM
	dbo.dimproduct p
LEFT JOIN
	dbo.factsalesorder s
	ON p.productkey = s.productkey
WHERE
	s.salestotal IS NULL;


-- Number of orders placed per weekday
SELECT
	d.weekdayname,
	COUNT(*) as orders
FROM
	dbo.factsalesorder s
JOIN
	dbo.dimdate d
	ON s.salesorderdatekey = d.datekey
GROUP BY 
	d.weekdayname; 



-- Most popular product category by number of orders
SELECT
	p.category,
	COUNT(DISTINCT s.salesorderkey) as orders
FROM 
	dbo.dimproduct p
JOIN
	dbo.factsalesorder s
	ON p.productkey = s.productkey
GROUP BY
	p.category
ORDER BY
	orders desc
LIMIT
	1;


-- Customers who placed orders in December
SELECT DISTINCT
	c.firstname,
	c.lastname
FROM
	dbo.factsalesorder s
JOIN
	dbo.dimcustomer c
	ON s.customerkey = c.customerkey
JOIN
	dbo.dimdate d
	ON s.salesorderdatekey = d.datekey
WHERE 
	d.monthname = 'December';