import psycopg2
from psycopg2.extras import execute_values

# --------------------
# DATABASE CONNECTION
# --------------------
def connection():
    conn = psycopg2.connect(
        host = 'localhost',
        user = 'admin',
        password = 'admin',
        database = 'testdb',
        port = '5431'
    )
    return conn


# --------------------
# CREATE SCHEMA
# --------------------
def create_schema(conn, schema_name='sales_analytics'):
    cur = conn.cursor()
    query = f"CREATE SCHEMA IF NOT EXISTS {schema_name}"
    cur.execute(query)
    conn.commit()


# -----------------------------------------
# MONTH OVER MONTH GROPWTH FOR EACH PRODUCT
# -----------------------------------------
def month_over_month(conn, schema_name='sales_analytics', table_name='month_over_month_sales'):
    cur = conn.cursor()
    query = f"""
    CREATE TABLE IF NOT EXISTS {schema_name}.{table_name} AS
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
    """
    cur.execute(query)
    conn.commit()

# ----------------------------------------------------
# AVERAGE SALES PER WEEKDAY FOR EACH PRODUCT CATERGORY
# -----------------------------------------------------
def avg_sales_weekday_per_category(conn, schema_name='sales_analytics', table_name='avg_sales_per_weekday_per_cart'):
    cur = conn.cursor()
    query = f"""
            CREATE TABLE IF NOT EXISTS {schema_name}.{table_name} AS
            SELECT
                p.category,
                d.weekdayname,
                ROUND(AVG(f.salestotal), 2) AS average_sales
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
            """
    cur.execute(query)
    conn.commit()



# ----------------------------------------------------------------------------
# PERCENTAGE CONTRIBUTION OF EACH PRODUCT TO TOTAL SALES WITHIN ITS CATEGORY
# ----------------------------------------------------------------------------
def percentage_contribution(conn, schema_name='sales_analytics', table_name='percentage_conribution'):
    cur = conn.cursor()
    query = f"""
            CREATE TABLE IF NOT EXISTS {schema_name}.{table_name} AS 
            WITH sales AS(
            SELECT
                f.productkey,
                p.category,
                SUM(f.salestotal) AS total_sales
            FROM
                dbo.factsalesorder f
            JOIN
                dbo.dimproduct p
                ON p.productkey = f.productkey
            GROUP BY
                f.productkey,
                p.category         
            )
            SELECT
                productkey,
                category,
                total_sales,
                SUM(total_sales) OVER (PARTITION BY category ORDER BY category, productkey) AS total_sales_per_category,
                ROUND((total_sales * 100) /  SUM(total_sales) OVER (PARTITION BY category ORDER BY category, productkey), 2)
            FROM
                sales
            """
    cur.execute(query)
    conn.commit()


# ---------------------------------------------------------
# CUSTOMERS WHO PLACED ORDERS IN AT LEAST 3 DIFFERENT YEARS
# ---------------------------------------------------------
def orders_in_three_diff_years(conn, schema_name='sales_analytics', table_name='orders_in_three_diff_years'):
    cur = conn.cursor()
    query = f"""
            CREATE TABLE IF NOT EXISTS {schema_name}.{table_name} AS
            SELECT
                customerkey,
                COUNT(DISTINCT DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))) AS num_order_years
            FROM
                dbo.factsalesorder
            GROUP BY
                customerkey
            HAVING
                COUNT(DISTINCT DATE_PART('year', CAST(CAST(salesorderdatekey AS CHAR(8)) AS DATE))) >= 3
            """
    cur.execute(query)
    conn.commit()


if __name__ == '__main__':
    conn = connection()
    create_schema(conn)
    month_over_month(conn)
    avg_sales_weekday_per_category(conn)
    percentage_contribution(conn)
    orders_in_three_diff_years(conn)
    conn.close()

