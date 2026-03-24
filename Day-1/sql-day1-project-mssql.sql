-- ============================================================
--  SQL DAY 1 — DB BASICS PROJECT
--  Dialect: Microsoft SQL Server (T-SQL) 2016+
--  Company HR Database
--  Difficulty: Easy ⭐ | Moderate 🔶 | Hard 🔴
-- ============================================================

-- ══════════════════════════════════════════════════════════════
--  SETUP — Database, Schema, Tables, Data
-- ══════════════════════════════════════════════════════════════

CREATE DATABASE company_hr
  COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE company_hr;
GO

-- Create schemas (MS-SQL supports multiple schemas per DB)
CREATE SCHEMA hr   AUTHORIZATION dbo;
GO
CREATE SCHEMA fin  AUTHORIZATION dbo;
GO

-- Departments
CREATE TABLE hr.departments (
    dept_id   INT            IDENTITY(1,1) PRIMARY KEY,
    dept_name NVARCHAR(50)   NOT NULL UNIQUE,
    location  NVARCHAR(100),
    budget    DECIMAL(15,2)  DEFAULT 0.00
);

-- Employees
CREATE TABLE hr.employees (
    emp_id      INT            IDENTITY(1,1) PRIMARY KEY,
    first_name  NVARCHAR(50)   NOT NULL,
    last_name   NVARCHAR(50)   NOT NULL,
    email       NVARCHAR(100)  NOT NULL CONSTRAINT uq_email UNIQUE,
    hire_date   DATE           NOT NULL,
    job_title   NVARCHAR(80),
    salary      DECIMAL(10,2)  CONSTRAINT chk_salary CHECK (salary > 0),
    dept_id     INT            NULL,
    manager_id  INT            NULL,
    is_active   BIT            DEFAULT 1,
    CONSTRAINT fk_emp_dept    FOREIGN KEY (dept_id)    REFERENCES hr.departments(dept_id) ON DELETE SET NULL,
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES hr.employees(emp_id)
);

-- 1:1 Employee details
CREATE TABLE hr.employee_details (
    detail_id  INT           IDENTITY(1,1) PRIMARY KEY,
    emp_id     INT           NOT NULL CONSTRAINT uq_det_emp UNIQUE,
    city       NVARCHAR(50),
    zip_code   CHAR(10),
    birth_date DATE,
    CONSTRAINT fk_ed_emp FOREIGN KEY (emp_id) REFERENCES hr.employees(emp_id) ON DELETE CASCADE
);

-- Phones (1NF)
CREATE TABLE hr.employee_phones (
    phone_id   INT           IDENTITY(1,1) PRIMARY KEY,
    emp_id     INT           NOT NULL,
    phone_type NVARCHAR(10)  NOT NULL
               CONSTRAINT chk_ph_type CHECK (phone_type IN ('mobile','home','work')),
    phone_no   NVARCHAR(15)  NOT NULL,
    CONSTRAINT fk_ph_emp FOREIGN KEY (emp_id) REFERENCES hr.employees(emp_id) ON DELETE CASCADE
);

-- Projects
CREATE TABLE hr.projects (
    project_id   INT            IDENTITY(1,1) PRIMARY KEY,
    project_name NVARCHAR(100)  NOT NULL,
    start_date   DATE,
    end_date     DATE,
    status       NVARCHAR(20)   DEFAULT 'Active'
                 CONSTRAINT chk_proj_status CHECK (status IN ('Active','Completed','On Hold')),
    budget       DECIMAL(15,2)
);

-- M:N junction
CREATE TABLE hr.employee_projects (
    emp_id       INT          NOT NULL,
    project_id   INT          NOT NULL,
    role         NVARCHAR(50),
    hours_worked INT          DEFAULT 0,
    CONSTRAINT pk_ep  PRIMARY KEY (emp_id, project_id),
    CONSTRAINT fk_ep_emp  FOREIGN KEY (emp_id)     REFERENCES hr.employees(emp_id),
    CONSTRAINT fk_ep_proj FOREIGN KEY (project_id) REFERENCES hr.projects(project_id)
);
GO

-- Sample data
INSERT INTO hr.departments (dept_name, location, budget) VALUES
('IT','Bangalore',5000000),('HR','Mumbai',2000000),
('Finance','Delhi',3500000),('Marketing','Hyderabad',2500000),('Operations','Pune',4000000);

SET IDENTITY_INSERT hr.employees ON;
INSERT INTO hr.employees (emp_id,first_name,last_name,email,hire_date,job_title,salary,dept_id,manager_id) VALUES
(1,'Alice','Sharma','alice@co.com','2019-03-15','Senior Developer',95000,1,NULL),
(2,'Bob',  'Verma', 'bob@co.com', '2020-06-01','Developer',72000,1,1),
(3,'Carol','Singh', 'carol@co.com','2021-01-10','HR Manager',68000,2,NULL),
(4,'Dave', 'Kumar', 'dave@co.com', '2018-07-22','CFO',120000,3,NULL),
(5,'Eve',  'Patel', 'eve@co.com',  '2022-04-05','Analyst',65000,3,4),
(6,'Frank','Gupta', 'frank@co.com','2017-11-30','Marketing Head',88000,4,NULL),
(7,'Grace','Nair',  'grace@co.com','2023-02-14','Marketing Exec',55000,4,6),
(8,'Hank', 'Reddy', 'hank@co.com', '2020-09-01','Ops Manager',78000,5,NULL),
(9,'Iris', 'Joshi', 'iris@co.com', '2021-12-01','Developer',70000,1,1),
(10,'Jack','Mehta', 'jack@co.com', '2019-05-20','Sr Analyst',82000,3,4);
SET IDENTITY_INSERT hr.employees OFF;

UPDATE hr.employees SET is_active = 0 WHERE emp_id = 10;

INSERT INTO hr.employee_details (emp_id,city,zip_code,birth_date) VALUES
(1,'Bangalore','560001','1990-05-14'),(2,'Bangalore','560001','1995-08-22'),
(3,'Mumbai','400001','1985-03-10'),(4,'Delhi','110001','1978-12-01');

INSERT INTO hr.employee_phones (emp_id,phone_type,phone_no) VALUES
(1,'mobile','9876543210'),(1,'work','0802345678'),
(2,'mobile','9876543211'),(3,'mobile','9876543212'),(3,'home','02212345678');

SET IDENTITY_INSERT hr.projects ON;
INSERT INTO hr.projects (project_id,project_name,start_date,end_date,status,budget) VALUES
(1,'ERP System','2024-01-01','2024-12-31','Active',8000000),
(2,'Website Redo','2024-03-01','2024-06-30','Active',1500000),
(3,'HR Automation','2023-06-01','2023-12-31','Completed',2000000);
SET IDENTITY_INSERT hr.projects OFF;

INSERT INTO hr.employee_projects VALUES
(1,1,'Tech Lead',320),(2,1,'Developer',280),(9,1,'Developer',300),
(2,2,'Developer',120),(7,2,'Coordinator',80),(3,3,'Owner',200);
GO


-- ══════════════════════════════════════════════════════════════
--  ⭐ EASY QUERIES
-- ══════════════════════════════════════════════════════════════

-- E1: All employees with departments
SELECT
    e.emp_id,
    e.first_name + ' ' + e.last_name  AS full_name,   -- + concat
    e.job_title,
    d.dept_name,
    e.salary
FROM hr.employees e
JOIN hr.departments d ON e.dept_id = d.dept_id
WHERE e.is_active = 1
ORDER BY d.dept_name, e.salary DESC;


-- E2: Count employees per department
SELECT
    d.dept_name,
    COUNT(e.emp_id)        AS headcount,
    ROUND(AVG(e.salary),2) AS avg_salary
FROM hr.departments d
LEFT JOIN hr.employees e ON d.dept_id = e.dept_id AND e.is_active = 1
GROUP BY d.dept_id, d.dept_name
ORDER BY headcount DESC;


-- E3: DDL — Add column and update
ALTER TABLE hr.employees ADD phone NVARCHAR(15) NULL;
UPDATE hr.employees SET phone = N'9999999999' WHERE emp_id = 1;
SELECT emp_id, first_name, phone FROM hr.employees WHERE emp_id = 1;
ALTER TABLE hr.employees DROP COLUMN phone;
GO


-- E4: TCL — Budget transfer
BEGIN TRANSACTION;
  UPDATE hr.departments SET budget = budget - 500000 WHERE dept_id = 2;
  UPDATE hr.departments SET budget = budget + 500000 WHERE dept_id = 1;
  SELECT dept_id, dept_name, budget FROM hr.departments WHERE dept_id IN (1,2);
COMMIT TRANSACTION;


-- E5: VIEW
CREATE OR ALTER VIEW hr.v_active_it AS
SELECT emp_id, first_name + ' ' + last_name AS name, salary
FROM   hr.employees
WHERE  dept_id = 1 AND is_active = 1;
GO

SELECT * FROM hr.v_active_it;


-- E6: Self-referencing — manager report
SELECT
    e.first_name + ' ' + e.last_name  AS employee,
    ISNULL(m.first_name + ' ' + m.last_name, 'No Manager') AS reports_to
FROM hr.employees e
LEFT JOIN hr.employees m ON e.manager_id = m.emp_id
ORDER BY reports_to, employee;


-- E7: 1NF — employees with phones (STRING_AGG — SQL Server 2017+)
SELECT
    e.first_name + ' ' + e.last_name             AS employee,
    STRING_AGG(ph.phone_type + ': ' + ph.phone_no, ' | ') AS all_phones
FROM hr.employees e
JOIN hr.employee_phones ph ON e.emp_id = ph.emp_id
GROUP BY e.emp_id, e.first_name, e.last_name;


-- E8: TOP N — highest paid employees
SELECT TOP 5
    e.first_name + ' ' + e.last_name AS name,
    d.dept_name, e.salary
FROM hr.employees e
JOIN hr.departments d ON e.dept_id = d.dept_id
WHERE e.is_active = 1
ORDER BY e.salary DESC;


-- ══════════════════════════════════════════════════════════════
--  🔶 MODERATE QUERIES
-- ══════════════════════════════════════════════════════════════

-- M1: Salary stats per dept
SELECT
    d.dept_name,
    COUNT(e.emp_id)           AS headcount,
    MIN(e.salary)             AS min_sal,
    MAX(e.salary)             AS max_sal,
    ROUND(AVG(e.salary),2)    AS avg_sal,
    SUM(e.salary)             AS total_payroll
FROM hr.departments d
LEFT JOIN hr.employees e ON d.dept_id = e.dept_id AND e.is_active = 1
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(e.emp_id) > 0
ORDER BY total_payroll DESC;


-- M2: Above-dept-average salary
SELECT
    e.first_name + ' ' + e.last_name AS full_name,
    d.dept_name, e.salary,
    ROUND(da.avg_sal, 2) AS dept_avg,
    ROUND(e.salary - da.avg_sal, 2) AS above_by
FROM hr.employees e
JOIN hr.departments d ON e.dept_id = d.dept_id
JOIN (
    SELECT dept_id, AVG(salary) AS avg_sal
    FROM hr.employees WHERE is_active = 1
    GROUP BY dept_id
) da ON e.dept_id = da.dept_id
WHERE e.salary > da.avg_sal AND e.is_active = 1
ORDER BY above_by DESC;


-- M3: M:N join — projects and employees
SELECT
    e.first_name + ' ' + e.last_name AS employee,
    d.dept_name, p.project_name,
    ep.role, ep.hours_worked
FROM hr.employees e
JOIN hr.departments d        ON e.dept_id    = d.dept_id
JOIN hr.employee_projects ep ON e.emp_id     = ep.emp_id
JOIN hr.projects p           ON ep.project_id = p.project_id
ORDER BY employee, p.project_name;


-- M4: Stored procedure (T-SQL with TRY/CATCH)
CREATE OR ALTER PROCEDURE hr.GetDeptReport
    @dept_name NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        e.first_name + ' ' + e.last_name    AS name,
        e.job_title, e.salary,
        DATEDIFF(YEAR, e.hire_date, GETDATE()) AS years_exp
    FROM hr.employees e
    JOIN hr.departments d ON e.dept_id = d.dept_id
    WHERE d.dept_name = @dept_name AND e.is_active = 1
    ORDER BY e.salary DESC;
END;
GO

EXEC hr.GetDeptReport @dept_name = N'IT';
EXEC hr.GetDeptReport @dept_name = N'Finance';


-- M5: TCL with SAVE TRANSACTION (MS-SQL savepoint)
BEGIN TRANSACTION;
  BEGIN TRY
    UPDATE hr.employees SET salary = ROUND(salary * 1.10, 2) WHERE dept_id = 1;
    SAVE TRANSACTION after_it_raise;

    UPDATE hr.employees SET salary = ROUND(salary * 1.10, 2) WHERE dept_id = 3;

    -- Check budget
    SELECT d.dept_name, SUM(e.salary) AS payroll
    FROM hr.employees e JOIN hr.departments d ON e.dept_id = d.dept_id
    WHERE e.dept_id IN (1,3) GROUP BY d.dept_name;

    COMMIT TRANSACTION;
  END TRY
  BEGIN CATCH
    ROLLBACK TRANSACTION after_it_raise;
    PRINT 'Finance raise rolled back: ' + ERROR_MESSAGE();
    COMMIT TRANSACTION;
  END CATCH;


-- M6: Pagination with OFFSET/FETCH (SQL Server 2012+)
SELECT
    e.first_name + ' ' + e.last_name AS name,
    e.salary, d.dept_name
FROM hr.employees e
JOIN hr.departments d ON e.dept_id = d.dept_id
WHERE e.is_active = 1
ORDER BY e.salary DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;   -- page 1
-- OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY;   -- page 2


-- ══════════════════════════════════════════════════════════════
--  🔴 HARD QUERIES
-- ══════════════════════════════════════════════════════════════

-- H1: Recursive CTE — org hierarchy
WITH OrgTree AS (
    SELECT emp_id,
           first_name + ' ' + last_name AS name,
           job_title, manager_id, 0 AS lvl,
           CAST(first_name + ' ' + last_name AS NVARCHAR(500)) AS path
    FROM hr.employees WHERE manager_id IS NULL

    UNION ALL

    SELECT e.emp_id,
           e.first_name + ' ' + e.last_name,
           e.job_title, e.manager_id, ot.lvl+1,
           CAST(ot.path + N' → ' + e.first_name + ' ' + e.last_name AS NVARCHAR(500))
    FROM hr.employees e
    JOIN OrgTree ot ON e.manager_id = ot.emp_id
)
SELECT REPLICATE(N'  ', lvl) + name AS org_chart, job_title, lvl
FROM OrgTree ORDER BY path;


-- H2: Window functions — salary rank
SELECT
    d.dept_name,
    e.first_name + ' ' + e.last_name           AS employee,
    e.salary,
    RANK()      OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS dept_rank,
    ROUND(e.salary - AVG(e.salary) OVER (PARTITION BY e.dept_id), 2) AS vs_avg,
    ROUND(e.salary * 100.0 / SUM(e.salary) OVER (PARTITION BY e.dept_id), 1) AS pct_payroll,
    LAG(e.salary)  OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS next_higher,
    LEAD(e.salary) OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS next_lower
FROM hr.employees e
JOIN hr.departments d ON e.dept_id = d.dept_id
WHERE e.is_active = 1
ORDER BY d.dept_name, dept_rank;


-- H3: 3NF — zip code extraction
CREATE TABLE IF NOT EXISTS hr.zip_codes (
    zip_code CHAR(10)    PRIMARY KEY,
    city     NVARCHAR(50),
    state    NVARCHAR(50)
);

INSERT INTO hr.zip_codes VALUES
('560001','Bangalore','Karnataka'),
('400001','Mumbai','Maharashtra'),
('110001','Delhi','Delhi');

SELECT e.first_name + ' ' + e.last_name AS name, z.city, z.state
FROM hr.employee_details ed
JOIN hr.employees e  ON ed.emp_id   = e.emp_id
JOIN hr.zip_codes z  ON ed.zip_code = z.zip_code;


-- H4: PIVOT — employees per department as columns
SELECT *
FROM (
    SELECT d.dept_name, e.emp_id
    FROM hr.employees e
    JOIN hr.departments d ON e.dept_id = d.dept_id
    WHERE e.is_active = 1
) src
PIVOT (
    COUNT(emp_id) FOR dept_name IN ([IT],[HR],[Finance],[Marketing],[Operations])
) AS pvt;


-- H5: Full report view with all joins
CREATE OR ALTER VIEW hr.v_employee_full AS
SELECT
    e.emp_id,
    e.first_name + ' ' + e.last_name              AS full_name,
    e.job_title, e.salary, e.hire_date,
    DATEDIFF(YEAR, e.hire_date, GETDATE())         AS years_service,
    d.dept_name, d.location,
    ISNULL(m.first_name + ' ' + m.last_name,'Top') AS manager,
    ed.city,
    COUNT(DISTINCT ep.project_id)                  AS project_count,
    ISNULL(SUM(ep.hours_worked), 0)                AS total_hours,
    CASE
        WHEN e.salary >= 90000 THEN 'Senior'
        WHEN e.salary >= 70000 THEN 'Mid'
        ELSE 'Junior'
    END AS band,
    e.is_active
FROM hr.employees e
JOIN hr.departments d             ON e.dept_id    = d.dept_id
LEFT JOIN hr.employees m          ON e.manager_id = m.emp_id
LEFT JOIN hr.employee_details ed  ON e.emp_id     = ed.emp_id
LEFT JOIN hr.employee_projects ep ON e.emp_id     = ep.emp_id
GROUP BY e.emp_id, e.first_name, e.last_name, e.job_title, e.salary, e.hire_date,
         d.dept_name, d.location, m.first_name, m.last_name, ed.city, e.is_active;
GO

SELECT dept_name, full_name, band, project_count, total_hours
FROM hr.v_employee_full WHERE is_active = 1 ORDER BY dept_name, salary DESC;
