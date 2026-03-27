-- ============================================================
-- SQL Day 3 — Advanced Constraints & Triggers · MS-SQL Server 2022
-- Practice Queries: Easy · Moderate · Hard
-- Topics: Triggers · Views · Identity · HAVING vs WHERE · Subquery
-- ============================================================

USE master; GO
IF EXISTS (SELECT name FROM sys.databases WHERE name='day3_mssql') DROP DATABASE day3_mssql; GO
CREATE DATABASE day3_mssql; GO
USE day3_mssql; GO

CREATE TABLE dbo.departments (
    dept_id   INT           IDENTITY(1,1) PRIMARY KEY,
    dept_name NVARCHAR(50)  NOT NULL UNIQUE,
    location  NVARCHAR(100),
    budget    DECIMAL(15,2) CONSTRAINT df_budget DEFAULT 0.00,
    CONSTRAINT chk_budget CHECK (budget >= 0)
);
CREATE TABLE dbo.employees (
    emp_id     INT           IDENTITY(1,1),
    first_name NVARCHAR(50)  NOT NULL,
    last_name  NVARCHAR(50)  NOT NULL,
    email      NVARCHAR(100) NOT NULL,
    salary     DECIMAL(10,2) NOT NULL,
    age        INT,
    status     NVARCHAR(10)  CONSTRAINT df_status DEFAULT N'active',
    dept_id    INT,
    manager_id INT,
    hire_date  DATE          CONSTRAINT df_hire   DEFAULT GETDATE(),
    created_at DATETIME2     CONSTRAINT df_created DEFAULT GETDATE(),
    CONSTRAINT pk_emp    PRIMARY KEY CLUSTERED (emp_id),
    CONSTRAINT uq_email  UNIQUE (email),
    CONSTRAINT chk_sal   CHECK (salary > 0),
    CONSTRAINT chk_age   CHECK (age BETWEEN 18 AND 65),
    CONSTRAINT chk_status CHECK (status IN (N'active',N'inactive',N'pending')),
    CONSTRAINT fk_dept   FOREIGN KEY (dept_id)    REFERENCES dbo.departments(dept_id) ON DELETE SET NULL,
    CONSTRAINT fk_mgr    FOREIGN KEY (manager_id) REFERENCES dbo.employees(emp_id)
);
CREATE TABLE dbo.projects (
    project_id   INT           IDENTITY(1,1) PRIMARY KEY,
    project_name NVARCHAR(100) NOT NULL UNIQUE,
    budget       DECIMAL(15,2) DEFAULT 0,
    start_date   DATE, end_date DATE,
    dept_id      INT REFERENCES dbo.departments(dept_id) ON DELETE SET NULL
);
CREATE TABLE dbo.emp_projects (
    emp_id INT NOT NULL, project_id INT NOT NULL,
    role   NVARCHAR(50) DEFAULT N'member',
    hours  INT          DEFAULT 0,
    CONSTRAINT pk_ep PRIMARY KEY (emp_id, project_id),
    FOREIGN KEY (emp_id)     REFERENCES dbo.employees(emp_id)  ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES dbo.projects(project_id) ON DELETE CASCADE
);
CREATE TABLE dbo.emp_audit (
    audit_id   INT        IDENTITY(1,1) PRIMARY KEY,
    action     NVARCHAR(10),
    emp_id     INT,
    old_salary DECIMAL(10,2), new_salary DECIMAL(10,2),
    old_status NVARCHAR(10),  new_status NVARCHAR(10),
    changed_at DATETIME2  DEFAULT GETDATE(),
    changed_by NVARCHAR(100) DEFAULT SYSTEM_USER
);
GO

INSERT INTO dbo.departments VALUES (N'Engineering',N'Bangalore',5000000),(N'HR',N'Mumbai',2000000),(N'Finance',N'Delhi',3000000),(N'Marketing',N'Pune',1500000),(N'Operations',N'Chennai',2500000);
INSERT INTO dbo.employees (first_name,last_name,email,salary,age,status,dept_id,manager_id) VALUES
(N'Alice',N'Sharma',N'alice@co.com',95000,32,N'active',1,NULL),(N'Bob',N'Verma',N'bob@co.com',72000,35,N'active',1,1),
(N'Carol',N'Singh',N'carol@co.com',85000,28,N'active',1,1),(N'Dave',N'Kumar',N'dave@co.com',60000,40,N'inactive',2,NULL),
(N'Eve',N'Patel',N'eve@co.com',110000,30,N'active',3,NULL),(N'Frank',N'Gupta',N'frank@co.com',78000,38,N'active',2,4),
(N'Grace',N'Mehta',N'grace@co.com',92000,27,N'active',1,1),(N'Henry',N'Joshi',N'henry@co.com',55000,45,N'inactive',4,NULL),
(N'Ivy',N'Rao',N'ivy@co.com',88000,33,N'active',3,5),(N'Jack',N'Nair',N'jack@co.com',67000,29,N'active',4,8);
INSERT INTO dbo.projects VALUES (N'Apollo',800000,'2024-01-01','2024-06-30',1),(N'Beacon',500000,'2024-03-01',NULL,1),(N'Comet',300000,'2024-05-01','2024-09-30',3),(N'Delta',200000,'2024-07-01','2024-12-31',2),(N'Echo',150000,'2024-02-01','2024-04-30',4);
INSERT INTO dbo.emp_projects VALUES (1,1,N'lead',120),(2,1,N'member',80),(3,1,N'member',60),(1,2,N'lead',40),(3,2,N'senior',30),(7,2,N'member',20),(5,3,N'lead',100),(9,3,N'member',50),(4,4,N'member',30),(6,4,N'lead',60),(8,5,N'member',20),(10,5,N'lead',45);
GO

-- ── TRIGGERS ──────────────────────────────────────────────────────────────
-- AFTER UPDATE/DELETE — handles multi-row DML via INSERTED/DELETED tables
CREATE OR ALTER TRIGGER dbo.trg_emp_audit
  ON dbo.employees AFTER UPDATE, DELETE
AS BEGIN
  SET NOCOUNT ON;
  -- Log salary/status changes on UPDATE
  INSERT INTO dbo.emp_audit (action, emp_id, old_salary, new_salary, old_status, new_status)
  SELECT N'UPDATE', i.emp_id, d.salary, i.salary, d.status, i.status
  FROM INSERTED i JOIN DELETED d ON i.emp_id = d.emp_id
  WHERE i.salary <> d.salary OR i.status <> d.status;
  -- Log DELETEs
  INSERT INTO dbo.emp_audit (action, emp_id, old_salary, old_status)
  SELECT N'DELETE', d.emp_id, d.salary, d.status
  FROM DELETED d WHERE NOT EXISTS (SELECT 1 FROM INSERTED WHERE emp_id = d.emp_id);
END; GO

-- AFTER INSERT — log new hires
CREATE OR ALTER TRIGGER dbo.trg_emp_insert
  ON dbo.employees AFTER INSERT
AS BEGIN
  SET NOCOUNT ON;
  INSERT INTO dbo.emp_audit (action, emp_id, new_salary, new_status)
  SELECT N'INSERT', emp_id, salary, status FROM INSERTED;
END; GO

-- INSTEAD OF trigger on a view (enable UPDATE on JOIN view)
CREATE OR ALTER VIEW dbo.v_emp_dept AS
  SELECT e.emp_id, e.first_name, e.last_name, e.salary, e.status, d.dept_name
  FROM   dbo.employees e LEFT JOIN dbo.departments d ON e.dept_id = d.dept_id; GO

CREATE OR ALTER TRIGGER dbo.trg_v_emp_dept_update
  ON dbo.v_emp_dept INSTEAD OF UPDATE
AS BEGIN
  SET NOCOUNT ON;
  UPDATE e SET e.salary = i.salary, e.status = i.status,
               e.first_name = i.first_name, e.last_name = i.last_name
  FROM dbo.employees e JOIN INSERTED i ON e.emp_id = i.emp_id;
END; GO

-- ── VIEWS ─────────────────────────────────────────────────────────────────
CREATE OR ALTER VIEW dbo.v_emp_public AS
  SELECT emp_id, first_name+N' '+last_name AS full_name, status, dept_id, hire_date
  FROM   dbo.employees; GO
CREATE OR ALTER VIEW dbo.v_active_employees AS
  SELECT e.emp_id, e.first_name, e.last_name, e.salary, e.age, d.dept_name, d.location
  FROM   dbo.employees e LEFT JOIN dbo.departments d ON e.dept_id = d.dept_id
  WHERE  e.status = N'active'; GO

-- Indexed View (auto-maintained Materialized View)
CREATE OR ALTER VIEW dbo.v_dept_summary
WITH SCHEMABINDING AS
  SELECT e.dept_id,
         COUNT_BIG(*)    AS headcount,
         SUM(e.salary)   AS total_sal,
         COUNT_BIG(CASE WHEN e.status=N'active' THEN 1 END) AS active_cnt
  FROM   dbo.employees e
  GROUP BY e.dept_id; GO
CREATE UNIQUE CLUSTERED INDEX idx_v_dept ON dbo.v_dept_summary (dept_id); GO


-- ============================================================
-- EASY QUERIES (1–8)
-- ============================================================

-- E1: List all triggers in day3_mssql
SELECT t.name AS trigger_name, OBJECT_NAME(t.parent_id) AS table_name,
       t.type_desc, t.is_disabled
FROM   sys.triggers t ORDER BY table_name;

-- E2: Fire insert trigger — add new employee
INSERT INTO dbo.employees (first_name, last_name, email, salary, age, status, dept_id)
VALUES (N'New', N'Hire', N'newhire@co.com', 55000, 26, N'active', 1);
SELECT TOP 3 * FROM dbo.emp_audit ORDER BY audit_id DESC;

-- E3: Fire update trigger — give Alice a raise
UPDATE dbo.employees SET salary = 100000 WHERE emp_id = 1;
SELECT * FROM dbo.emp_audit WHERE emp_id = 1;

-- E4: Query security view (no salary column)
SELECT TOP 5 * FROM dbo.v_emp_public;

-- E5: Query active employees view
SELECT dept_name, first_name, last_name, salary
FROM   dbo.v_active_employees ORDER BY salary DESC;

-- E6: WHERE vs HAVING — departments with avg salary > 70k
SELECT dept_id, COUNT(*) AS cnt, AVG(salary) AS avg_sal
FROM   dbo.employees
WHERE  status = N'active'           -- row filter
GROUP BY dept_id
HAVING AVG(salary) > 70000          -- group filter
ORDER BY avg_sal DESC;

-- E7: Scalar subquery — employees above company average
SELECT first_name, salary,
       (SELECT AVG(salary) FROM dbo.employees WHERE status=N'active') AS company_avg
FROM   dbo.employees
WHERE  status = N'active'
  AND  salary > (SELECT AVG(salary) FROM dbo.employees WHERE status=N'active')
ORDER BY salary DESC;

-- E8: IDENTITY info
SELECT IDENT_CURRENT('dbo.employees') AS current_identity,
       IDENT_SEED('dbo.employees')    AS seed,
       IDENT_INCR('dbo.employees')    AS increment;


-- ============================================================
-- MODERATE QUERIES (1–6)
-- ============================================================

-- M1: UPDATE through INSTEAD OF trigger on the view
UPDATE dbo.v_emp_dept SET salary = 98000, status = N'active'
WHERE  emp_id = 3;
SELECT * FROM dbo.emp_audit WHERE emp_id = 3 ORDER BY audit_id DESC;

-- M2: Indexed View — verify auto-maintained stats
SELECT v.dept_id, d.dept_name, v.headcount, v.total_sal, v.active_cnt
FROM   dbo.v_dept_summary v WITH (NOEXPAND)  -- force indexed view
JOIN   dbo.departments d ON v.dept_id = d.dept_id
ORDER BY v.headcount DESC;

-- M3: Override IDENTITY — insert specific emp_id
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (emp_id, first_name, last_name, email, salary, age, status, dept_id)
VALUES (9999, N'Special', N'User', N'special@co.com', 99999, 30, N'active', 1);
SET IDENTITY_INSERT dbo.employees OFF;
-- Verify
SELECT emp_id, first_name, salary FROM dbo.employees WHERE emp_id = 9999;

-- M4: NOT EXISTS vs NOT IN (NULL safety)
-- Safe: NOT EXISTS
SELECT dept_name FROM dbo.departments d
WHERE  NOT EXISTS (SELECT 1 FROM dbo.employees e WHERE e.dept_id = d.dept_id AND e.status = N'active');
-- Potentially unsafe: NOT IN with NULLs
-- SELECT dept_name FROM dbo.departments WHERE dept_id NOT IN (SELECT dept_id FROM dbo.employees WHERE dept_id IS NULL);

-- M5: CROSS APPLY — top-earning employee per department
SELECT d.dept_name, top_e.first_name, top_e.salary
FROM   dbo.departments d
CROSS APPLY (
    SELECT TOP 1 first_name, salary
    FROM   dbo.employees WHERE dept_id = d.dept_id AND status = N'active'
    ORDER BY salary DESC
) AS top_e;

-- M6: OUTER APPLY — all departments, NULL if no employees
SELECT d.dept_name, ISNULL(top_e.first_name, N'No employees') AS top_earner,
       top_e.salary
FROM   dbo.departments d
OUTER APPLY (
    SELECT TOP 1 first_name, salary
    FROM   dbo.employees WHERE dept_id = d.dept_id AND status = N'active'
    ORDER BY salary DESC
) AS top_e;


-- ============================================================
-- HARD QUERIES (1–5)
-- ============================================================

-- H1: CTE — employees earning above their department average
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_sal FROM dbo.employees WHERE status=N'active' GROUP BY dept_id
)
SELECT e.first_name, e.salary, d.dept_name,
       ROUND(da.avg_sal,2) AS dept_avg,
       ROUND(e.salary - da.avg_sal, 2) AS above_by
FROM   dbo.employees e
JOIN   dbo.departments d  ON e.dept_id = d.dept_id
JOIN   dept_avg        da ON e.dept_id = da.dept_id
WHERE  e.status = N'active' AND e.salary > da.avg_sal
ORDER BY above_by DESC;

-- H2: Recursive CTE — org hierarchy
WITH org_tree AS (
    SELECT emp_id, first_name, manager_id, 1 AS depth,
           CAST(first_name AS NVARCHAR(500)) AS path
    FROM   dbo.employees WHERE manager_id IS NULL AND status = N'active'
    UNION ALL
    SELECT e.emp_id, e.first_name, e.manager_id, ot.depth+1,
           CAST(ot.path + N' → ' + e.first_name AS NVARCHAR(500))
    FROM   dbo.employees e JOIN org_tree ot ON e.manager_id = ot.emp_id
    WHERE  e.status = N'active'
)
SELECT REPLICATE(N'  ', depth-1) + first_name AS org_chart, depth, path
FROM   org_tree ORDER BY path;

-- H3: Nth highest salary with DENSE_RANK
WITH ranked AS (
    SELECT DISTINCT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM dbo.employees WHERE status = N'active'
)
SELECT salary, rnk FROM ranked WHERE rnk IN (2, 3) ORDER BY rnk;

-- H4: ROLLUP — salary report with subtotals and grand total
SELECT ISNULL(d.dept_name, N'GRAND TOTAL') AS dept,
       ISNULL(e.status,   N'ALL STATUSES') AS status,
       COUNT(e.emp_id)  AS headcount,
       SUM(e.salary)    AS total_salary,
       AVG(e.salary)    AS avg_salary
FROM   dbo.employees e
JOIN   dbo.departments d ON e.dept_id = d.dept_id
GROUP BY ROLLUP(d.dept_name, e.status)
ORDER BY dept, status;

-- H5: Complex subquery + HAVING — find duplicates
SELECT email, COUNT(*) AS cnt FROM dbo.employees GROUP BY email HAVING COUNT(*) > 1;
-- Projects where members average > 40 hours
SELECT p.project_name, COUNT(ep.emp_id) AS members,
       AVG(ep.hours) AS avg_hours, SUM(ep.hours) AS total_hours
FROM   dbo.projects p JOIN dbo.emp_projects ep ON p.project_id = ep.project_id
GROUP BY p.project_id, p.project_name
HAVING COUNT(ep.emp_id) >= 2 AND AVG(ep.hours) > 40
ORDER BY avg_hours DESC;

-- ============================================================
-- CLEANUP
-- ============================================================
-- USE master; DROP DATABASE day3_mssql;
