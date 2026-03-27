# SQL Day 3 — Advanced Constraints & Triggers · MS-SQL Server 2022

> **Dialect:** Microsoft SQL Server 2022 (16.x) · T-SQL · Default schema: `dbo`

---

## Topic 1 — Triggers

### Theory
- MS-SQL supports **AFTER** (or `FOR`) and **INSTEAD OF** triggers — **no BEFORE triggers**
- Uses virtual tables `INSERTED` and `DELETED` — not NEW/OLD
  - `INSERTED` = new row values (INSERT, UPDATE)
  - `DELETED` = old row values (DELETE, UPDATE)
  - UPDATE = row in both `INSERTED` and `DELETED`
- **Statement-level** by default — fires once even if multiple rows are affected
- **INSTEAD OF** triggers: mainly used on Views to enable INSERT/UPDATE/DELETE on complex views
- `CREATE OR ALTER TRIGGER` — no need to drop first

### Trigger Types
| Type | When | Use Case |
|---|---|---|
| AFTER INSERT | After insert succeeds | Audit, cascade insert |
| AFTER UPDATE | After update succeeds | Audit log, derived column |
| AFTER DELETE | After delete succeeds | Soft delete, archive |
| INSTEAD OF INSERT/UPDATE/DELETE | Replaces DML | DML on complex views |

### Syntax
```sql
-- AFTER trigger (most common)
CREATE OR ALTER TRIGGER dbo.trigger_name
  ON dbo.table_name
  AFTER INSERT, UPDATE, DELETE   -- one or more events
AS
BEGIN
  SET NOCOUNT ON;
  -- INSERTED = new values
  -- DELETED  = old values
  -- For UPDATE: row appears in both
END;
GO

-- INSTEAD OF trigger (on view or table)
CREATE OR ALTER TRIGGER dbo.trg_view_insert
  ON dbo.view_name
  INSTEAD OF INSERT
AS
BEGIN
  SET NOCOUNT ON;
  -- Redirect to actual base table
  INSERT INTO dbo.actual_table (col1, col2)
  SELECT col1, col2 FROM INSERTED;
END;
GO

-- Drop / Disable / Enable
DROP TRIGGER dbo.trigger_name;
DISABLE TRIGGER dbo.trigger_name ON dbo.table_name;
ENABLE  TRIGGER dbo.trigger_name ON dbo.table_name;
DISABLE TRIGGER ALL ON dbo.table_name;   -- all triggers on table
```

### Example — Audit Trigger
```sql
-- Audit log
CREATE TABLE dbo.emp_audit (
    audit_id   INT       IDENTITY(1,1) PRIMARY KEY,
    action     NVARCHAR(10),
    emp_id     INT,
    old_salary DECIMAL(10,2),
    new_salary DECIMAL(10,2),
    changed_at DATETIME2    DEFAULT GETDATE(),
    changed_by NVARCHAR(100) DEFAULT SYSTEM_USER
);

-- AFTER UPDATE/DELETE — handles multi-row DML!
CREATE OR ALTER TRIGGER dbo.trg_emp_audit
  ON dbo.employees
  AFTER UPDATE, DELETE
AS
BEGIN
  SET NOCOUNT ON;
  -- Log salary changes (UPDATE)
  INSERT INTO dbo.emp_audit (action, emp_id, old_salary, new_salary)
  SELECT N'UPDATE', i.emp_id, d.salary, i.salary
  FROM   INSERTED i JOIN DELETED d ON i.emp_id = d.emp_id
  WHERE  i.salary <> d.salary;

  -- Log deletes
  INSERT INTO dbo.emp_audit (action, emp_id, old_salary, new_salary)
  SELECT N'DELETE', d.emp_id, d.salary, NULL
  FROM   DELETED d
  WHERE  NOT EXISTS (SELECT 1 FROM INSERTED WHERE emp_id = d.emp_id);
END;
GO

-- INSTEAD OF trigger — enable UPDATE on a JOIN view
CREATE OR ALTER VIEW dbo.v_emp_dept AS
SELECT e.emp_id, e.first_name, e.salary, d.dept_name
FROM   dbo.employees e JOIN dbo.departments d ON e.dept_id = d.dept_id;
GO

CREATE OR ALTER TRIGGER dbo.trg_v_emp_dept_update
  ON dbo.v_emp_dept
  INSTEAD OF UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE e SET e.salary = i.salary, e.first_name = i.first_name
  FROM dbo.employees e JOIN INSERTED i ON e.emp_id = i.emp_id;
END;
GO
```

---

## Topic 2 — Views

### Theory
- **View**: stored SELECT — no data stored, fetched from base tables on query
- `CREATE OR ALTER VIEW` — no need to drop first (MS-SQL 2022)
- **Indexed View** (= Materialized View): physically stores data; auto-maintained by SQL Server
  - Requires `WITH SCHEMABINDING`, `COUNT_BIG(*)`, schema-qualified table names
  - Creates a unique clustered index → SQL Server auto-maintains on DML
  - No manual REFRESH needed!
- `SCHEMABINDING` — prevents dropping or altering base tables without dropping the view first

### Syntax
```sql
-- Simple view
CREATE OR ALTER VIEW dbo.view_name AS
  SELECT col1, col2 FROM dbo.table WHERE condition;

-- Indexed View (Materialized) — strict requirements
CREATE OR ALTER VIEW dbo.v_dept_stats
WITH SCHEMABINDING AS
  SELECT dept_id,
         COUNT_BIG(*) AS headcount,     -- COUNT_BIG(*) is required
         SUM(salary)  AS total_salary
  FROM   dbo.employees                  -- must use schema.table
  GROUP BY dept_id;
GO
-- Create unique clustered index to materialize
CREATE UNIQUE CLUSTERED INDEX idx_v_dept
  ON dbo.v_dept_stats (dept_id);
-- SQL Server now auto-maintains this on every INSERT/UPDATE/DELETE!

-- Drop
DROP VIEW IF EXISTS dbo.view_name;

-- List views
SELECT name FROM sys.views;
```

### Example
```sql
-- Security view
CREATE OR ALTER VIEW dbo.v_emp_public AS
SELECT emp_id,
       first_name + N' ' + last_name AS full_name,
       dept_id, status
FROM   dbo.employees;

-- Indexed view for department stats
CREATE OR ALTER VIEW dbo.v_dept_headcount
WITH SCHEMABINDING AS
SELECT dept_id,
       COUNT_BIG(*) AS headcount,
       SUM(salary)  AS total_sal,
       COUNT_BIG(CASE WHEN status = N'active' THEN 1 END) AS active_cnt
FROM   dbo.employees
GROUP BY dept_id;
GO
CREATE UNIQUE CLUSTERED INDEX idx_dept_hc ON dbo.v_dept_headcount (dept_id);

-- Query indexed view (SQL Server uses it automatically)
SELECT d.dept_name, v.headcount, v.total_sal
FROM   dbo.v_dept_headcount v
JOIN   dbo.departments d ON v.dept_id = d.dept_id
ORDER BY v.headcount DESC;

-- Forced use of indexed view
SELECT * FROM dbo.v_dept_headcount WITH (NOEXPAND);  -- hints SQL Server to use the index
```

---

## Topic 3 — Identity Column

### Theory
- `IDENTITY(seed, increment)` auto-generates sequential numbers
- `SCOPE_IDENTITY()` — preferred to get last inserted ID (scope-safe)
- `@@IDENTITY` — session-wide, can be affected by triggers (avoid)
- Override identity: `SET IDENTITY_INSERT table ON`
- Reset: `DBCC CHECKIDENT ('table', RESEED, n)`
- `SEQUENCE` object: more flexible than IDENTITY — sharable across tables

### Syntax
```sql
-- IDENTITY(seed, increment)
id INT IDENTITY(1,1)   PRIMARY KEY   -- start 1, step 1
id INT IDENTITY(100,5) PRIMARY KEY   -- start 100, step 5

-- Get last inserted ID
SELECT SCOPE_IDENTITY() AS new_id;   -- preferred!
SELECT @@IDENTITY;                   -- session-wide (avoid)

-- Insert specific value
SET IDENTITY_INSERT dbo.employees ON;
INSERT INTO dbo.employees (emp_id, first_name) VALUES (9999, N'Manual');
SET IDENTITY_INSERT dbo.employees OFF;

-- Reseed (reset next value)
DBCC CHECKIDENT ('dbo.employees', RESEED, 0);   -- next = 1
DBCC CHECKIDENT ('dbo.employees', RESEED, 999); -- next = 1000

-- SEQUENCE object (alternative to IDENTITY)
CREATE SEQUENCE dbo.seq_emp
  START WITH 1 INCREMENT BY 1 MINVALUE 1 NO MAXVALUE NO CYCLE CACHE 20;
SELECT NEXT VALUE FOR dbo.seq_emp;

-- Use sequence as default
CREATE TABLE dbo.orders (
    order_id INT DEFAULT (NEXT VALUE FOR dbo.seq_emp) PRIMARY KEY
);
```

### Example
```sql
CREATE TABLE dbo.products (
    product_id   INT            IDENTITY(1000, 1) PRIMARY KEY,
    product_name NVARCHAR(100)  NOT NULL,
    price        DECIMAL(10,2)  NOT NULL
);

INSERT INTO dbo.products (product_name, price)
VALUES (N'Laptop', 999.99), (N'Mouse', 29.99);
SELECT SCOPE_IDENTITY() AS last_id;   -- 1001

-- Check current identity info
DBCC CHECKIDENT ('dbo.products', NORESEED);   -- shows current seed

-- Override identity
SET IDENTITY_INSERT dbo.products ON;
INSERT INTO dbo.products (product_id, product_name, price) VALUES (9999, N'Special', 1.00);
SET IDENTITY_INSERT dbo.products OFF;
```

---

## Topic 4 — SQL Clauses: HAVING vs WHERE

### Theory
- **WHERE** — filters rows BEFORE GROUP BY — cannot use aggregate functions
- **HAVING** — filters groups AFTER GROUP BY — can use `COUNT()`, `AVG()`, etc.
- MS-SQL: cannot use SELECT column aliases in HAVING — must repeat the expression
- `ROLLUP`, `CUBE`, `GROUPING SETS` available for multi-level aggregation

### Syntax
```sql
-- WHERE + GROUP BY + HAVING
SELECT dept_id, COUNT(*) AS cnt, AVG(salary) AS avg_sal
FROM   dbo.employees
WHERE  status = N'active'              -- row filter (before)
GROUP BY dept_id
HAVING COUNT(*) >= 2                   -- group filter (after)
   AND AVG(salary) > 60000;

-- ❌ Cannot use alias in HAVING
-- HAVING avg_sal > 60000   -- error!
-- ✅ Must repeat the expression
-- HAVING AVG(salary) > 60000

-- ROLLUP: subtotals and grand total
SELECT ISNULL(dept_id, -1) AS dept, COUNT(*), SUM(salary)
FROM   dbo.employees GROUP BY ROLLUP(dept_id);

-- GROUPING SETS: explicit combinations
SELECT dept_id, status, COUNT(*)
FROM   dbo.employees
GROUP BY GROUPING SETS ((dept_id), (status), (dept_id, status), ());
```

### Example
```sql
-- Departments with 2+ active employees, avg salary > 50k
SELECT d.dept_name,
       COUNT(e.emp_id)  AS headcount,
       AVG(e.salary)    AS avg_salary,
       MAX(e.salary)    AS max_salary
FROM   dbo.employees e
JOIN   dbo.departments d ON e.dept_id = d.dept_id
WHERE  e.status = N'active'
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(e.emp_id) >= 2
   AND AVG(e.salary) > 50000
ORDER BY AVG(e.salary) DESC;   -- must repeat AVG, no alias!

-- Duplicate emails finder
SELECT email, COUNT(*) AS occurrences
FROM   dbo.employees
GROUP BY email
HAVING COUNT(*) > 1;

-- ROLLUP for salary report with subtotals
SELECT ISNULL(d.dept_name, N'GRAND TOTAL') AS dept,
       COUNT(e.emp_id) AS headcount,
       SUM(e.salary)   AS total_salary
FROM   dbo.employees e
JOIN   dbo.departments d ON e.dept_id = d.dept_id
GROUP BY ROLLUP(d.dept_name);
```

---

## Topic 5 — Subquery (Nested Query)

### Theory
- Full subquery support in T-SQL
- `CROSS APPLY` / `OUTER APPLY` — MS-SQL's equivalent of LATERAL JOIN (correlated FROM subquery)
- Prefer `NOT EXISTS` over `NOT IN` — `NOT IN` with NULLs returns 0 rows!
- CTEs (`WITH`) preferred for readability over deeply nested subqueries

### Syntax
```sql
-- Scalar subquery
SELECT name, salary,
       (SELECT AVG(salary) FROM dbo.employees) AS company_avg
FROM   dbo.employees;

-- IN subquery
SELECT * FROM dbo.employees
WHERE dept_id IN (SELECT dept_id FROM dbo.departments WHERE location = N'Bangalore');

-- NOT EXISTS (NULL-safe — always prefer over NOT IN)
SELECT dept_name FROM dbo.departments d
WHERE NOT EXISTS (SELECT 1 FROM dbo.employees e WHERE e.dept_id = d.dept_id);

-- CROSS APPLY: correlated subquery in FROM
SELECT e.first_name, top_p.project_name, top_p.budget
FROM   dbo.employees e
CROSS APPLY (
    SELECT TOP 1 p.project_name, p.budget
    FROM   dbo.projects p
    JOIN   dbo.emp_projects ep ON p.project_id = ep.project_id
    WHERE  ep.emp_id = e.emp_id
    ORDER BY p.budget DESC
) AS top_p;

-- OUTER APPLY: like LEFT JOIN (includes employees with no projects)
SELECT e.first_name, top_p.project_name
FROM   dbo.employees e
OUTER APPLY (
    SELECT TOP 1 project_name FROM dbo.projects p
    JOIN dbo.emp_projects ep ON p.project_id = ep.project_id
    WHERE ep.emp_id = e.emp_id ORDER BY p.budget DESC
) AS top_p;

-- CTE (preferred for readability)
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_sal FROM dbo.employees GROUP BY dept_id
)
SELECT e.first_name, e.salary, d.avg_sal
FROM   dbo.employees e JOIN dept_avg d ON e.dept_id = d.dept_id
WHERE  e.salary > d.avg_sal;
```

### Example — Interview Patterns
```sql
-- Employees earning above company average
SELECT emp_id, first_name, salary
FROM   dbo.employees
WHERE  salary > (SELECT AVG(salary) FROM dbo.employees);

-- 2nd highest salary
SELECT MAX(salary) AS second_highest
FROM   dbo.employees
WHERE  salary < (SELECT MAX(salary) FROM dbo.employees);

-- Nth highest salary (CTE + DENSE_RANK)
WITH ranked AS (
    SELECT DISTINCT salary,
           DENSE_RANK() OVER (ORDER BY salary DESC) AS rnk
    FROM dbo.employees
)
SELECT salary FROM ranked WHERE rnk = 3;

-- ⚠️ NOT IN with NULL is dangerous!
-- If any employee has dept_id = NULL:
-- SELECT dept_name FROM departments WHERE dept_id NOT IN (SELECT dept_id FROM employees);
-- Returns EMPTY SET even if some depts have no employees!
-- ✅ Always use NOT EXISTS instead:
SELECT dept_name FROM dbo.departments d
WHERE NOT EXISTS (SELECT 1 FROM dbo.employees e WHERE e.dept_id = d.dept_id);
```

---

## MS-SQL 2022 Day 3 Quick Reference

| Feature | Syntax / Notes |
|---|---|
| AFTER trigger | `AFTER INSERT, UPDATE, DELETE` |
| INSTEAD OF trigger | `INSTEAD OF INSERT` — on views or tables |
| BEFORE trigger | ❌ Not supported — use INSTEAD OF |
| Row access | `INSERTED` (new) / `DELETED` (old) tables |
| Statement-level | ✅ Default — handles multi-row DML at once |
| Create/replace trigger | `CREATE OR ALTER TRIGGER` |
| Disable trigger | `DISABLE TRIGGER name ON table` |
| Simple view | `CREATE OR ALTER VIEW dbo.v AS SELECT ...` |
| Indexed View | `WITH SCHEMABINDING` + `CREATE UNIQUE CLUSTERED INDEX` |
| Force indexed view | `SELECT * FROM v WITH (NOEXPAND)` |
| Auto-maintained MV | ✅ SQL Server auto-maintains Indexed Views |
| Identity | `INT IDENTITY(seed, increment)` |
| Get last ID | `SCOPE_IDENTITY()` (preferred) |
| Override identity | `SET IDENTITY_INSERT table ON/OFF` |
| Reseed | `DBCC CHECKIDENT ('table', RESEED, n)` |
| Sequence object | `CREATE SEQUENCE` + `NEXT VALUE FOR` |
| Alias in HAVING | ❌ Must repeat expression |
| ROLLUP | `GROUP BY ROLLUP(col1, col2)` |
| GROUPING SETS | `GROUP BY GROUPING SETS ((c1),(c2),())` |
| CROSS APPLY | Correlated subquery in FROM clause |
| OUTER APPLY | Like LEFT JOIN version of CROSS APPLY |
| NOT IN vs NOT EXISTS | Always use `NOT EXISTS` — safer with NULLs |
