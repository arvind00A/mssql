-- ============================================================
-- SQL Day 5 — Indexes & Optimization · MS-SQL Server 2022
-- Practice Queries: Easy · Moderate · Hard
-- ============================================================
USE master; GO
IF EXISTS (SELECT name FROM sys.databases WHERE name='day5_mssql') DROP DATABASE day5_mssql; GO
CREATE DATABASE day5_mssql; GO
USE day5_mssql; GO

CREATE TABLE dbo.departments (
    dept_id   INT IDENTITY(1,1) CONSTRAINT pk_dept PRIMARY KEY CLUSTERED,
    dept_name NVARCHAR(50) NOT NULL, location NVARCHAR(100)
);
CREATE TABLE dbo.employees (
    emp_id    INT IDENTITY(1,1) CONSTRAINT pk_emp PRIMARY KEY CLUSTERED,
    first_name NVARCHAR(50) NOT NULL, last_name NVARCHAR(50) NOT NULL,
    email     NVARCHAR(100) NOT NULL, salary DECIMAL(10,2) NOT NULL,
    dept_id   INT REFERENCES dbo.departments(dept_id),
    status    NVARCHAR(10) DEFAULT N'active',
    hire_date DATE, age INT
);
CREATE TABLE dbo.orders (
    order_id    INT IDENTITY(1,1) CONSTRAINT pk_ord PRIMARY KEY CLUSTERED,
    customer_id INT NOT NULL, status NVARCHAR(20) NOT NULL DEFAULT N'pending',
    amount      DECIMAL(10,2) NOT NULL, order_date DATE NOT NULL, region NVARCHAR(20)
);
CREATE TABLE dbo.salary_grades (
    grade CHAR(1) PRIMARY KEY, min_salary DECIMAL(10,2), max_salary DECIMAL(10,2), label NVARCHAR(20)
);
GO

INSERT INTO dbo.departments VALUES (N'Engineering',N'Bangalore'),(N'HR',N'Mumbai'),(N'Finance',N'Delhi'),(N'Marketing',N'Pune');
INSERT INTO dbo.employees (first_name,last_name,email,salary,dept_id,status,hire_date,age) VALUES
(N'Alice',N'Sharma',N'alice@co.com',95000,1,N'active','2022-01-15',32),
(N'Bob',N'Verma',N'bob@co.com',72000,1,N'active','2021-06-01',35),
(N'Carol',N'Singh',N'carol@co.com',85000,1,N'active','2023-03-10',28),
(N'Dave',N'Kumar',N'dave@co.com',60000,2,N'inactive','2019-11-20',40),
(N'Eve',N'Patel',N'eve@co.com',110000,3,N'active','2020-07-05',30),
(N'Frank',N'Gupta',N'frank@co.com',78000,2,N'active','2022-09-12',38),
(N'Grace',N'Mehta',N'grace@co.com',92000,1,N'active','2023-01-08',27),
(N'Henry',N'Joshi',N'henry@co.com',55000,4,N'inactive','2018-04-25',45),
(N'Ivy',N'Rao',N'ivy@co.com',88000,3,N'active','2021-12-01',33),
(N'Jack',N'Nair',N'jack@co.com',67000,4,N'active','2022-05-15',29);
INSERT INTO dbo.salary_grades VALUES ('A',0,49999,N'Entry'),('B',50000,74999,N'Mid'),('C',75000,99999,N'Senior'),('D',100000,999999,N'Executive');
-- Generate orders
INSERT INTO dbo.orders (customer_id,status,amount,order_date,region)
SELECT TOP 100 ABS(CHECKSUM(NEWID()))%10+1,
    CHOOSE(ABS(CHECKSUM(NEWID()))%4+1,N'pending',N'shipped',N'delivered',N'cancelled'),
    ROUND(100+RAND()*900,2), DATEADD(DAY,ABS(CHECKSUM(NEWID()))%365,'2024-01-01'),
    CHOOSE(ABS(CHECKSUM(NEWID()))%4+1,N'North',N'South',N'East',N'West')
FROM sys.objects a CROSS JOIN sys.objects b;
GO

-- ── EASY (1–8) ────────────────────────────────────────────────────────────

-- E1: View all indexes on employees
SELECT i.name AS index_name, i.type_desc, i.is_unique, i.is_primary_key,
       c.name AS column_name, ic.key_ordinal, ic.is_descending_key
FROM   sys.indexes i
JOIN   sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id
JOIN   sys.columns c ON ic.object_id=c.object_id AND ic.column_id=c.column_id
WHERE  i.object_id = OBJECT_ID('dbo.employees')
ORDER BY i.index_id, ic.key_ordinal;

-- E2: Check execution plan before any indexes (type=Table Scan = bad)
SET STATISTICS IO ON;
SELECT first_name, salary FROM dbo.employees WHERE dept_id=1 AND status=N'active';
SET STATISTICS IO OFF;

-- E3: Create non-clustered index on dept_id (FK column)
CREATE NONCLUSTERED INDEX idx_emp_dept ON dbo.employees(dept_id);

-- E4: Create unique index on email
CREATE UNIQUE NONCLUSTERED INDEX idx_emp_email ON dbo.employees(email);

-- E5: View all indexes after creation
SELECT name, type_desc, is_unique, is_primary_key
FROM   sys.indexes WHERE object_id=OBJECT_ID('dbo.employees') ORDER BY index_id;

-- E6: Find Heap tables (no clustered index — should rebuild as clustered)
SELECT OBJECT_NAME(object_id) AS heap_table, object_id
FROM   sys.indexes WHERE type=0;  -- type=0 is HEAP

-- E7: Check fragmentation on employees indexes
SELECT i.name, s.avg_fragmentation_in_percent, s.page_count, s.record_count
FROM   sys.dm_db_index_physical_stats(DB_ID(),OBJECT_ID('dbo.employees'),NULL,NULL,'DETAILED') s
JOIN   sys.indexes i ON s.object_id=i.object_id AND s.index_id=i.index_id
WHERE  s.page_count > 0;

-- E8: Non-equi join with salary grades (no special index)
SELECT e.first_name, e.salary, sg.grade, sg.label
FROM   dbo.employees e
JOIN   dbo.salary_grades sg ON e.salary BETWEEN sg.min_salary AND sg.max_salary
ORDER BY e.salary DESC;

-- ── MODERATE (1–6) ────────────────────────────────────────────────────────

-- M1: Covering index with INCLUDE — eliminate key lookup
-- Before: check IO (index seek + key lookup)
SET STATISTICS IO ON;
SELECT first_name, salary FROM dbo.employees WHERE dept_id=1 AND status=N'active';

-- Create covering index
CREATE NONCLUSTERED INDEX idx_dept_status_cover
  ON dbo.employees(dept_id, status)
  INCLUDE (first_name, salary);

-- After: check IO again (should drop to single-digit reads)
SELECT first_name, salary FROM dbo.employees WHERE dept_id=1 AND status=N'active';
SET STATISTICS IO OFF;

-- M2: Filtered index (partial — only active employees)
CREATE NONCLUSTERED INDEX idx_active_dept
  ON dbo.employees(dept_id)
  WHERE status = N'active';
-- Smaller index! Only active rows are indexed.
-- Works for: SELECT ... WHERE dept_id=? AND status=N'active'

-- M3: Index killer — function on column prevents index use
CREATE NONCLUSTERED INDEX idx_hire ON dbo.employees(hire_date);
-- ❌ Bad — YEAR() on column, index NOT used (Execution plan shows: Index Scan or Table Scan)
SELECT * FROM dbo.employees WHERE YEAR(hire_date) = 2022;
-- ✅ Good — range condition, index IS used (seek)
SELECT * FROM dbo.employees WHERE hire_date >= '2022-01-01' AND hire_date < '2023-01-01';

-- M4: Columnstore index for analytics on orders
CREATE NONCLUSTERED COLUMNSTORE INDEX idx_order_cs ON dbo.orders(order_date, amount, status, region);
-- Now aggregate queries are much faster
SET STATISTICS IO ON;
SELECT region, COUNT(*) AS cnt, SUM(amount) AS total, AVG(amount) AS avg_amt
FROM   dbo.orders GROUP BY region;
SET STATISTICS IO OFF;

-- M5: Rebuild vs Reorganize (based on fragmentation level)
-- Simulate fragmentation
DELETE FROM dbo.orders WHERE order_id % 3 = 0;
-- Check fragmentation
SELECT i.name, s.avg_fragmentation_in_percent
FROM   sys.dm_db_index_physical_stats(DB_ID(),OBJECT_ID('dbo.orders'),NULL,NULL,'LIMITED') s
JOIN   sys.indexes i ON s.object_id=i.object_id AND s.index_id=i.index_id
WHERE  s.page_count > 0;
-- < 10%: no action
-- 10-30%: REORGANIZE (online)
ALTER INDEX idx_order_cs ON dbo.orders REORGANIZE;
-- > 30%: REBUILD (online)
ALTER INDEX ALL ON dbo.orders REBUILD WITH (ONLINE=ON);

-- M6: Missing index advisor — SQL Server recommends what to create
SELECT TOP 10
    OBJECT_NAME(mid.object_id) AS table_name,
    migs.avg_total_user_cost * migs.avg_user_impact AS benefit_score,
    mid.equality_columns, mid.inequality_columns, mid.included_columns,
    migs.user_seeks, migs.user_scans
FROM   sys.dm_db_missing_index_groups   mig
JOIN   sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle=migs.group_handle
JOIN   sys.dm_db_missing_index_details  mid ON mig.index_handle=mid.index_handle
WHERE  mid.database_id = DB_ID()
ORDER BY benefit_score DESC;

-- ── HARD (1–5) ────────────────────────────────────────────────────────────

-- H1: Full index optimization workflow
-- Step 1: Enable IO stats
SET STATISTICS IO ON;
-- Step 2: Baseline — slow query
SELECT e.first_name, e.salary, d.dept_name
FROM   dbo.employees e JOIN dbo.departments d ON e.dept_id=d.dept_id
WHERE  e.status=N'active' AND e.salary>70000 ORDER BY e.salary DESC;
-- Step 3: Create optimal covering index
CREATE NONCLUSTERED INDEX idx_opt
  ON dbo.employees(status, salary)
  INCLUDE (first_name, dept_id);
-- Step 4: Re-run — compare logical reads
SELECT e.first_name, e.salary, d.dept_name
FROM   dbo.employees e JOIN dbo.departments d ON e.dept_id=d.dept_id
WHERE  e.status=N'active' AND e.salary>70000 ORDER BY e.salary DESC;
SET STATISTICS IO OFF;

-- H2: Find unused indexes (zero seeks since last restart)
SELECT OBJECT_NAME(i.object_id) AS tbl, i.name AS idx_name,
       ISNULL(us.user_seeks,0)   AS seeks,
       ISNULL(us.user_scans,0)   AS scans,
       ISNULL(us.user_updates,0) AS index_writes,
       i.type_desc
FROM   sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
       ON i.object_id=us.object_id AND i.index_id=us.index_id AND us.database_id=DB_ID()
WHERE  i.type_in (1,2)  -- clustered + non-clustered only
  AND  i.is_primary_key = 0
  AND  i.is_unique_constraint = 0
  AND (ISNULL(us.user_seeks,0) + ISNULL(us.user_scans,0)) = 0
ORDER BY ISNULL(us.user_updates,0) DESC;

-- H3: Disable + rebuild index (maintenance window simulation)
ALTER INDEX idx_emp_dept ON dbo.employees DISABLE;
-- Index is now unusable — queries fall back to table scan
SELECT first_name FROM dbo.employees WHERE dept_id=1;
-- Re-enable by rebuilding
ALTER INDEX idx_emp_dept ON dbo.employees REBUILD;
SELECT first_name FROM dbo.employees WHERE dept_id=1;

-- H4: Comprehensive index health report for all tables
SELECT
    OBJECT_NAME(i.object_id)         AS table_name,
    i.name                            AS index_name,
    i.type_desc,
    s.avg_fragmentation_in_percent    AS frag_pct,
    s.page_count,
    ISNULL(us.user_seeks,0)           AS seeks,
    ISNULL(us.user_scans,0)           AS scans,
    ISNULL(us.user_updates,0)         AS writes,
    CASE
        WHEN s.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN s.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
        WHEN ISNULL(us.user_seeks,0)+ISNULL(us.user_scans,0) = 0
             AND ISNULL(us.user_updates,0) > 100 THEN 'CONSIDER DROP'
        ELSE 'OK'
    END AS recommendation
FROM   sys.indexes i
LEFT JOIN sys.dm_db_index_physical_stats(DB_ID(),NULL,NULL,NULL,'LIMITED') s
       ON i.object_id=s.object_id AND i.index_id=s.index_id
LEFT JOIN sys.dm_db_index_usage_stats us
       ON i.object_id=us.object_id AND i.index_id=us.index_id AND us.database_id=DB_ID()
WHERE  i.type > 0  -- exclude heaps
ORDER BY frag_pct DESC NULLS LAST;

-- H5: Leftmost prefix verification — test different query patterns
CREATE INDEX idx_composite ON dbo.employees(dept_id, status, salary);
-- Uses index (dept_id = leftmost)
SELECT * FROM dbo.employees WHERE dept_id=1;
-- Uses index (dept_id + status)
SELECT * FROM dbo.employees WHERE dept_id=1 AND status=N'active';
-- Uses index (all 3 — best case)
SELECT * FROM dbo.employees WHERE dept_id=1 AND status=N'active' AND salary>70000;
-- Does NOT use composite (status alone skips dept_id)
SELECT * FROM dbo.employees WHERE status=N'active';

-- ============================================================
-- CLEANUP
-- ============================================================
-- USE master; DROP DATABASE day5_mssql;
