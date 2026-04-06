# SQL Day 5 — Indexes & Optimization · MS-SQL Server 2022

> **Dialect:** Microsoft SQL Server 2022 (16.x) · T-SQL · Default schema: `dbo`

---

## Topic 1 — Index: Purpose & Types

### Theory
- An **index** is a B-tree structure (or columnstore/hash) that enables O(log n) row lookups
- SQL Server supports both **clustered** and **non-clustered** indexes
- A table without a clustered index is called a **Heap** — rows stored in no order
- Up to **1 clustered** and **999 non-clustered** indexes per table

### Index Types — MS-SQL 2022
| Type | Syntax | Use Case |
|---|---|---|
| Clustered B-tree | `CREATE CLUSTERED INDEX` | PK, range scans, physical order |
| Non-Clustered B-tree | `CREATE NONCLUSTERED INDEX` | WHERE, JOIN, ORDER BY |
| Unique | `CREATE UNIQUE INDEX` | Uniqueness + fast lookup |
| Composite | `CREATE INDEX (col1, col2)` | Multi-column queries |
| Filtered | `CREATE INDEX ... WHERE` | Subset of rows (partial index) |
| Covering | `CREATE INDEX ... INCLUDE` | Avoid key lookup |
| Columnstore | `CREATE COLUMNSTORE INDEX` | Analytics, OLAP, aggregations |
| Hash | In-memory tables only | Exact equality lookups only |

### Syntax
```sql
-- Clustered (physical row order — 1 per table)
CREATE CLUSTERED INDEX idx_name ON dbo.table_name (column);

-- Non-clustered (most common — up to 999)
CREATE NONCLUSTERED INDEX idx_name ON dbo.table_name (column);

-- Unique non-clustered
CREATE UNIQUE NONCLUSTERED INDEX idx_name ON dbo.table_name (col);

-- Composite with direction
CREATE INDEX idx_name ON dbo.table_name (col1 ASC, col2 DESC);

-- Filtered index (partial — subset of rows)
CREATE INDEX idx_active ON dbo.employees (dept_id)
  WHERE status = N'active';

-- Covering index (INCLUDE non-key columns)
CREATE NONCLUSTERED INDEX idx_name ON dbo.table_name (key_col)
  INCLUDE (col2, col3);

-- Columnstore (analytics — column-based)
CREATE NONCLUSTERED COLUMNSTORE INDEX idx_cs
  ON dbo.orders (order_date, amount, region);

-- View all indexes on a table
SELECT name, type_desc, is_unique, is_primary_key
FROM   sys.indexes WHERE object_id = OBJECT_ID('dbo.employees');
```

---

## Topic 2 — Clustered vs Non-Clustered

### Theory
- **Clustered**: Table rows physically sorted by index key. ONE per table. PK creates clustered by default. Range queries = very fast.
- **Non-Clustered**: Separate B-tree with key + row locator (clustered key or RID for heap). MANY per table.
- **Heap**: Table with no clustered index. Use `SELECT * FROM sys.indexes WHERE type=0` to find heaps.
- **Covering Index**: Non-clustered + INCLUDE columns → entire query from index, no key lookup.

### Syntax
```sql
-- Clustered PK (default when adding PRIMARY KEY)
CREATE TABLE dbo.orders (
    order_id    INT IDENTITY(1,1),
    customer_id INT,
    amount      DECIMAL(10,2),
    CONSTRAINT pk_orders PRIMARY KEY CLUSTERED (order_id)
);

-- Override PK to be NON-CLUSTERED
-- (lets you choose a different clustered index)
CREATE TABLE dbo.t (
    id       INT CONSTRAINT pk_t PRIMARY KEY NONCLUSTERED,
    date_col DATE
);
CREATE CLUSTERED INDEX idx_date ON dbo.t(date_col);

-- Non-clustered (standard)
CREATE NONCLUSTERED INDEX idx_cust ON dbo.orders(customer_id);

-- Covering (INCLUDE avoids key lookup)
CREATE NONCLUSTERED INDEX idx_cust_cover ON dbo.orders(customer_id)
  INCLUDE (amount, order_date);
-- Query: SELECT amount, order_date WHERE customer_id=? → index-only!

-- Find Heap tables (no clustered index)
SELECT OBJECT_NAME(object_id) AS heap_table
FROM   sys.indexes WHERE type = 0;  -- type 0 = HEAP

-- Check fragmentation
SELECT i.name, s.avg_fragmentation_in_percent, s.page_count
FROM   sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.orders'), NULL, NULL, 'LIMITED') s
JOIN   sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
ORDER BY s.avg_fragmentation_in_percent DESC;
```

---

## Topic 3 — Index Commands: Create, Drop, Rebuild

### Syntax — CREATE INDEX
```sql
-- Non-clustered (default)
CREATE INDEX idx_name ON dbo.table_name (column);

-- Clustered (1 per table!)
CREATE CLUSTERED INDEX idx_name ON dbo.table_name (column);

-- Unique non-clustered
CREATE UNIQUE NONCLUSTERED INDEX idx_name ON dbo.table_name (col);

-- Composite (key column order matters)
CREATE INDEX idx_name ON dbo.table_name (col1 ASC, col2 DESC);

-- Covering (INCLUDE for non-key SELECT columns)
CREATE NONCLUSTERED INDEX idx_name ON dbo.table_name (key_col)
  INCLUDE (select_col1, select_col2);

-- Filtered (WHERE clause = partial index)
CREATE INDEX idx_name ON dbo.table_name (col)
  WHERE status = N'active';

-- Columnstore (analytics)
CREATE NONCLUSTERED COLUMNSTORE INDEX idx_cs
  ON dbo.fact_sales (sale_date, amount, region_id);

-- Online build (no table lock!)
CREATE INDEX idx_name ON dbo.table_name (col) WITH (ONLINE = ON);
```

### Syntax — DROP INDEX
```sql
-- Drop named index
DROP INDEX idx_name ON dbo.table_name;

-- Drop multiple
DROP INDEX idx1 ON dbo.t, idx2 ON dbo.t;

-- Drop PK constraint (drops clustered index too)
ALTER TABLE dbo.table_name DROP CONSTRAINT pk_name;

-- Disable without dropping (can be re-enabled by rebuild)
ALTER INDEX idx_name ON dbo.table_name DISABLE;
```

### Syntax — Rebuild & Reorganize
```sql
-- REBUILD (full — offline by default)
ALTER INDEX idx_name ON dbo.employees REBUILD;

-- REBUILD online (no lock — Enterprise/Developer edition)
ALTER INDEX idx_name ON dbo.employees REBUILD WITH (ONLINE = ON);

-- Rebuild all indexes on a table
ALTER INDEX ALL ON dbo.employees REBUILD;

-- REORGANIZE (online, low resource — for 10-30% fragmentation)
ALTER INDEX idx_name ON dbo.employees REORGANIZE;

-- Update statistics (without rebuild)
UPDATE STATISTICS dbo.employees;
UPDATE STATISTICS dbo.employees idx_name;  -- specific index

-- Check fragmentation (avg > 30% → REBUILD, 10-30% → REORGANIZE)
SELECT i.name, s.avg_fragmentation_in_percent, s.page_count
FROM   sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.employees'),
       NULL, NULL, 'SAMPLED') s
JOIN   sys.indexes i ON s.object_id=i.object_id AND s.index_id=i.index_id
WHERE  s.avg_fragmentation_in_percent > 0
ORDER BY s.avg_fragmentation_in_percent DESC;
```

---

## Topic 4 — Index Strategy: Selection & Covering Index

### Leftmost Prefix Rule
```sql
-- CREATE INDEX idx ON t(a, b, c)
WHERE a = ?                       -- ✅ uses idx (a)
WHERE a = ? AND b = ?             -- ✅ uses idx (a+b)
WHERE a = ? AND b = ? AND c = ?   -- ✅ uses idx (a+b+c)
WHERE a = ? AND b > ?             -- ✅ uses idx, range on b
WHERE b = ?                       -- ❌ leftmost prefix skipped!
WHERE c = ? AND b = ?             -- ❌ a is missing
```

### Index Selection Rules
```sql
-- ✅ Index these:
-- 1. WHERE equality columns first, then inequality
CREATE INDEX idx ON t(status, hire_date);   -- WHERE status=? AND hire_date>?

-- 2. FK join columns
CREATE INDEX idx_emp ON emp_projects(emp_id);

-- 3. Columns in ORDER BY (matches index order)
CREATE INDEX idx ON orders(customer_id, order_date);

-- Index killers — these bypass index:
WHERE YEAR(order_date) = 2024           -- ❌ function on column
WHERE amount * 1.1 > 110                -- ❌ expression on column
WHERE ISNULL(status, N'x') = N'active'  -- ❌ function on column
-- Fix:
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01'  -- ✅
WHERE amount > 100                                               -- ✅
WHERE status = N'active' OR status IS NULL                       -- ✅
```

### Covering Index (MS-SQL Best Practice)
```sql
-- Query: SELECT first_name, salary FROM emp WHERE dept_id=1 AND status=N'active'
-- Without covering: Index Seek (idx) → Key Lookup (table) = 2 reads
-- With covering: Index Seek (covering) = 1 read

CREATE NONCLUSTERED INDEX idx_dept_cover
  ON dbo.employees(dept_id, status)      -- key cols (WHERE)
  INCLUDE (first_name, salary);          -- non-key cols (SELECT)

-- SET STATISTICS IO ON to see logical reads
SET STATISTICS IO ON;
SELECT first_name, salary FROM dbo.employees
WHERE dept_id = 1 AND status = N'active';
-- Without idx: logical reads = 1000s
-- With covering: logical reads = few pages ✅

-- Missing index advisor (SQL Server recommends indexes)
SELECT TOP 20
    mid.statement AS table_name,
    migs.avg_total_user_cost * migs.avg_user_impact AS benefit,
    mid.equality_columns, mid.inequality_columns, mid.included_columns
FROM   sys.dm_db_missing_index_groups   mig
JOIN   sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle=migs.group_handle
JOIN   sys.dm_db_missing_index_details  mid ON mig.index_handle=mid.index_handle
ORDER BY benefit DESC;

-- Find unused indexes (zero seeks = probably can be dropped)
SELECT OBJECT_NAME(i.object_id) AS tbl, i.name AS idx_name,
       ISNULL(us.user_seeks,0) AS seeks, ISNULL(us.user_scans,0) AS scans,
       ISNULL(us.user_updates,0) AS writes
FROM   sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
       ON i.object_id=us.object_id AND i.index_id=us.index_id AND us.database_id=DB_ID()
WHERE  i.type > 0  -- not heaps
  AND  ISNULL(us.user_seeks,0) + ISNULL(us.user_scans,0) = 0
ORDER BY ISNULL(us.user_updates,0) DESC;  -- most writes, zero reads = drop!
```

---

## MS-SQL 2022 Indexes Quick Reference

| Feature | Syntax / Notes |
|---|---|
| Clustered (max 1) | `CREATE CLUSTERED INDEX idx ON dbo.t(col)` |
| Non-clustered (max 999) | `CREATE NONCLUSTERED INDEX idx ON dbo.t(col)` |
| Unique | `CREATE UNIQUE NONCLUSTERED INDEX` |
| Filtered (partial) | `CREATE INDEX ... WHERE condition` |
| Covering | `CREATE INDEX (key) INCLUDE (non_key_cols)` |
| Columnstore | `CREATE NONCLUSTERED COLUMNSTORE INDEX` |
| Online build | `CREATE INDEX ... WITH (ONLINE=ON)` |
| Drop index | `DROP INDEX idx ON dbo.table` |
| Disable | `ALTER INDEX idx ON t DISABLE` |
| Rebuild offline | `ALTER INDEX idx ON t REBUILD` |
| Rebuild online | `ALTER INDEX idx ON t REBUILD WITH (ONLINE=ON)` |
| Rebuild all | `ALTER INDEX ALL ON t REBUILD` |
| Reorganize | `ALTER INDEX idx ON t REORGANIZE` |
| Update stats | `UPDATE STATISTICS dbo.table` |
| View indexes | `SELECT * FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.t')` |
| Fragmentation | `sys.dm_db_index_physical_stats(...)` |
| Missing index advisor | `sys.dm_db_missing_index_details` |
| Unused index finder | `sys.dm_db_index_usage_stats` |
| IO stats | `SET STATISTICS IO ON` |
| EXPLAIN | Actual Execution Plan (SSMS Ctrl+M) |
| Heap detection | `sys.indexes WHERE type=0` |
| Auto FK index | ✅ Auto-created |
