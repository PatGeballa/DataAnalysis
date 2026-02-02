SELECT * 
FROM contractors

SELECT * 
FROM invoices

SELECT * 
FROM projects

SELECT *
FROM workorders

SELECT * 
FROM technicians


---- change rating to 1 decimal place
ALTER TABLE contractors
ALTER COLUMN rating DECIMAL(10,1);
--- Remove negative from workorders
UPDATE workorders
Set hours_worked = 3
Where hours_worked = -3
----- create technician table and tech id
SELECT 
    ROW_NUMBER() OVER (ORDER BY technician_name) AS technician_id,
    technician_name
INTO technicians
FROM (
    SELECT DISTINCT COALESCE(technician, 'Unknown') AS technician_name
    FROM WorkOrders
) t;

SELECT * 
FROM technicians

----- Join all tables for star schema---

SELECT 
    w.workorder_id,
    p.project_id,
    c.contractor_id,
    t.technician_id,
    CAST(w.date AS DATE) AS work_date,
    w.hours_worked,
    w.cost,
    w.status,
    CASE 
        WHEN w.cost < 0 THEN 'NEGATIVE'
        WHEN w.cost = 0 THEN 'ZERO'
        ELSE 'POSITIVE'
    END AS cost_flag
INTO fact_workorders
FROM WorkOrders w
JOIN Projects p 
    ON w.project_id = p.project_id
JOIN Contractors c 
    ON w.contractor_name = c.contractor_name
JOIN technicians t
    ON COALESCE(w.technician, 'Unknown') = t.technician_name;


	CREATE TABLE time (
    date_key INT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    month_name VARCHAR(20),
    quarter VARCHAR(2),
    day INT,
    weekday_name VARCHAR(20)
);

INSERT INTO time (date_key, full_date, year, month, month_name, quarter, day, weekday_name)
SELECT DISTINCT
    CAST(FORMAT(CAST(w.date AS DATE), 'yyyyMMdd') AS INT) AS date_key,
    CAST(w.date AS DATE) AS full_date,
    YEAR(CAST(w.date AS DATE)) AS year,
    MONTH(CAST(w.date AS DATE)) AS month,
    DATENAME(MONTH, CAST(w.date AS DATE)) AS month_name,
    CONCAT('Q', DATEPART(QUARTER, CAST(w.date AS DATE))) AS quarter,
    DAY(CAST(w.date AS DATE)) AS day,
    DATENAME(WEEKDAY, CAST(w.date AS DATE)) AS weekday_name
FROM WorkOrders w;



SELECT * 
FROM contractors

SELECT * 
FROM invoices

SELECT * 
FROM projects

SELECT *
FROM workorders

SELECT * 
FROM technicians

SELECT p.project_name,p.project_id,    COALESCE(w.cost, 0) AS workorder_cost,
    COALESCE(i.amount, 0) AS invoice_amount,
    COALESCE(w.cost, 0) + COALESCE(i.amount, 0) AS total_cost
FROM invoices i
Join projects p 
on i.project_id = p.project_id
Join workorders w
on w.project_id = p.project_id
------Total Cost of Project-----
SELECT 
    p.project_id,
    p.project_name,
    COALESCE(w.workorder_cost, 0) AS workorder_cost,
    COALESCE(i.invoice_amount, 0) AS invoice_amount,
    COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0) AS total_cost
FROM Projects p
JOIN (
    SELECT project_id, SUM(cost) AS workorder_cost
    FROM WorkOrders
    GROUP BY project_id
) w 
ON p.project_id = w.project_id
JOIN (
    SELECT project_id, SUM(amount) AS invoice_amount
    FROM Invoices
    GROUP BY project_id
) i 
ON p.project_id = i.project_id;
----Budget Comparision----
SELECT 
    p.project_name,
    p.budget,
    COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0) AS total_cost,
    (COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0)) - p.budget AS variance,
    CASE 
        WHEN (COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0)) > p.budget 
        THEN 'OVER BUDGET'
        ELSE 'WITHIN BUDGET'
    END AS budget_status
FROM Projects p
LEFT JOIN (
    SELECT project_id, SUM(cost) AS workorder_cost
    FROM WorkOrders
    GROUP BY project_id
) w ON p.project_id = w.project_id
LEFT JOIN (
    SELECT project_id, SUM(amount) AS invoice_amount
    FROM Invoices
    GROUP BY project_id
) i ON p.project_id = i.project_id;

SELECT * 
FROM workorders

SELECT *
FROM fact_workorders

SELECT * 
FROM technicians


----- Count OF WorkOrders Per Technician

SELECT t.technician_name AS Tech,COUNT(f.workorder_id) AS Workorders_Count
FROM fact_workorders f
Join technicians t
on f.technician_id = t.technician_id
Group by t.technician_name
Order by Workorders_Count DESC


----

SELECT * 
FROM fact_workorders

SELECT * 
FROM technicians
-----Hours by Tech---
SELECT t.technician_name As Tech,SUM(f.hours_worked) As Total_Hours
FROM fact_workorders f
Join technicians t
on f.technician_id = t.technician_id
Group by t.technician_name
Order by Total_Hours DESC


----Cost Per Hour by Technician

SELECT * FROM technicians
SELECT * FROM fact_workorders

SELECT t.technician_name AS TechName,
SUM(f.cost) AS Total_Cost,
SUM(f.hours_worked) As Total_Hours,
ROUND(SUM(f.cost) / NULLIF(SUM(f.hours_worked), 0), 2) AS Cost_Per_Hour
FROM fact_workorders f
Join technicians t
on f.technician_id = t.technician_id
Group by t.technician_name


----Cost Per Contractor

SELECT * FROM contractors
SELECT * FROM fact_workorders

SELECT c.contractor_name, 
ROUND(SUM(f.cost) / NULLIF(SUM(f.hours_worked), 0),2) AS cost_per_hour,
SUM(f.cost)As Total_Cost,
SUM(f.hours_worked) As Total_Hours
FROM contractors c
Join fact_workorders f
On c.contractor_id = f.contractor_id
Group by c.contractor_name

---- Contractor hourly rate vs cost per hour
SELECT 
    c.contractor_name,
    c.hourly_rate,
    ROUND(SUM(f.cost) / NULLIF(SUM(f.hours_worked), 0),2) AS cost_per_hour,
    ROUND(SUM(f.cost) / NULLIF(SUM(f.hours_worked), 0),2) - c.hourly_rate AS rate_difference
FROM fact_workorders f
JOIN Contractors c
    ON f.contractor_id = c.contractor_id
GROUP BY c.contractor_name, c.hourly_rate;


---- Project DELAY KPI---

SELECT * FROM fact_workorders
SELECT * FROM projects

SELECT project_name,planned_end_date,actual_end_date,
DATEDIFF(day,planned_end_date,actual_end_date) AS Delay,
 CASE 
      WHEN DATEDIFF(day, planned_end_date, actual_end_date) > 0 THEN 'Delayed'
      ELSE 'On Time'
End As Status
FROM projects 
Group by project_name,planned_end_date,actual_end_date

-----Risk Query

SELECT * FROM fact_workorders
SELECT * FROM projects




SELECT 
    p.project_name,
    p.budget,
    SUM(f.cost) AS Total_Cost,
    DATEDIFF(day, p.planned_end_date, p.actual_end_date) AS Delay,
    CASE
        WHEN SUM(f.cost) > p.budget THEN 'Over Budget'
        ELSE 'Within Budget'
    END AS BudgetStatus,
    CASE 
        WHEN DATEDIFF(day, p.planned_end_date, p.actual_end_date) > 0 THEN 'Delayed'
        ELSE 'On Time'
    END AS TimeStatus,
    CASE 
        WHEN DATEDIFF(day, p.planned_end_date, p.actual_end_date) > 0
             AND SUM(f.cost) > p.budget THEN 'High Risk'
        ELSE 'Normal'
    END AS Risk
FROM fact_workorders f
JOIN Projects p
    ON f.project_id = p.project_id
GROUP BY 
    p.project_name,
    p.budget,
    p.planned_end_date,
    p.actual_end_date;

SELECT * FROM invoices


------Final Project Risk Query---
SELECT 
    p.project_name,
    p.budget,
    COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0) AS Total_Cost,
    DATEDIFF(day, p.planned_end_date, p.actual_end_date) AS Delay,
    
    CASE
        WHEN (COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0)) > p.budget 
        THEN 'Over Budget'
        ELSE 'Within Budget'
    END AS BudgetStatus,

    CASE 
        WHEN DATEDIFF(day, p.planned_end_date, p.actual_end_date) > 0 
        THEN 'Delayed'
        ELSE 'On Time'
    END AS TimeStatus,

    CASE 
        WHEN DATEDIFF(day, p.planned_end_date, p.actual_end_date) > 0
             AND (COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0)) > p.budget 
        THEN 'High Risk'
        ELSE 'Normal'
    END AS Risk
FROM Projects p

LEFT JOIN (
    SELECT project_id, SUM(cost) AS workorder_cost
    FROM fact_workorders
    GROUP BY project_id
) w 
ON p.project_id = w.project_id

LEFT JOIN (
    SELECT project_id, SUM(amount) AS invoice_amount
    FROM Invoices   -- your fact-like table
    GROUP BY project_id
) i 
ON p.project_id = i.project_id;


----- % of High Risk Projects----

SELECT * FROM fact_workorders
SELECT * FROM invoices
SELECT * FROM projects
SELECT * FROM workorders


SELECT
    COUNT(*) AS number_of_projects,
    SUM(CASE 
            WHEN DATEDIFF(day, p.planned_end_date, p.actual_end_date) > 0
             AND (COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0)) > p.budget
            THEN 1 ELSE 0
        END) AS number_high_risk,
    CAST(
        100.0 * SUM(CASE 
                        WHEN DATEDIFF(day, p.planned_end_date, p.actual_end_date) > 0
                         AND (COALESCE(w.workorder_cost, 0) + COALESCE(i.invoice_amount, 0)) > p.budget
                        THEN 1 ELSE 0
                    END)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS high_risk_percentage
FROM Projects p
JOIN (
    SELECT project_id, SUM(cost) AS workorder_cost
    FROM fact_workorders
    GROUP BY project_id
) w ON p.project_id = w.project_id
JOIN (
    SELECT project_id, SUM(amount) AS invoice_amount
    FROM Invoices
    GROUP BY project_id
) i ON p.project_id = i.project_id;

--------- Unpaid Invoice% ------

SELECT * FROM contractors
SELECT * FROM fact_workorders
SELECT * FROM invoices

SELECT
    SUM(CASE WHEN paid_status = 'Unpaid' THEN amount ELSE 0 END) AS unpaid_amount,
    CAST(
        100.0 * SUM(CASE WHEN paid_status = 'Unpaid' THEN amount ELSE 0 END)
        / NULLIF(SUM(amount), 0)
        AS DECIMAL(5,2)
    ) AS unpaid_percentage
FROM Invoices;

-----Unpaid Invoice% CTE----
WITH totals AS (
    SELECT
        SUM(amount) AS total_amount,
        SUM(CASE WHEN paid_status = 'Unpaid' THEN amount ELSE 0 END) AS unpaid_amount
    FROM Invoices
)
SELECT
    unpaid_amount,
    CAST(100.0 * unpaid_amount / NULLIF(total_amount, 0) AS DECIMAL(5,2)) AS unpaid_percentage
FROM totals;

--------

SELECT * FROM invoices

With unpaid AS (
SELECT Count(invoice_id)AS Total_Invoice,
SUM(CASE WHEN paid_status = 'Unpaid' THEN 1 ELSE 0 END) As unpaid_count
FROM invoices)

SELECT unpaid_count,NULLIF(SUM((unpaid_count/Total_Invoice)*100),2) As Unpaid_rate
FROM unpaid
Group by unpaid_count

---------unpaid----
WITH unpaid AS (
    SELECT 
        COUNT(invoice_id) AS total_invoices,
        SUM(CASE WHEN paid_status = 'Unpaid' THEN 1 ELSE 0 END) AS unpaid_count
    FROM Invoices
)
SELECT 
    unpaid_count,
    CAST(
        100.0 * unpaid_count / NULLIF(total_invoices, 0)
        AS DECIMAL(5,2)
    ) AS unpaid_percent
FROM unpaid;


------Contractor unpaid percent

SELECT * FROM contractors
SELECT * FROM invoices

WITH unpaid AS (
    SELECT 
        contractor_name,
        COUNT(invoice_id) AS total_invoices,
        SUM(CASE WHEN paid_status = 'Unpaid' THEN 1 ELSE 0 END) AS unpaid_count
    FROM Invoices
    GROUP BY contractor_name
)
SELECT 
    c.contractor_name,
    u.total_invoices,
    u.unpaid_count,
    CAST(100.0 * u.unpaid_count / NULLIF(u.total_invoices, 0) AS DECIMAL(5,2)) AS unpaid_percent
FROM Contractors c
JOIN unpaid u
    ON u.contractor_name = c.contractor_name
ORDER BY unpaid_percent DESC, u.total_invoices DESC;


---Overdue Cash Risk by Contractor----

SELECT * FROM contractors
SELECT * FROM invoices


WITH contractor_invoice AS (
    SELECT
        contractor_name,
        SUM(amount) AS total_invoice_amount,
        SUM(CASE WHEN paid_status = 'Unpaid' THEN amount ELSE 0 END) AS unpaid_amount
    FROM Invoices
    GROUP BY contractor_name
)
SELECT
    contractor_name,
    total_invoice_amount,
    unpaid_amount,
    CAST(100.0 * unpaid_amount / NULLIF(total_invoice_amount, 0) AS DECIMAL(5,2)) AS unpaid_percent
FROM contractor_invoice
ORDER BY unpaid_percent DESC, total_invoice_amount DESC;


-------


SELECT * 
FROM fact_workorders

SELECT * 
FROM invoices