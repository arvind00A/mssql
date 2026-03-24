# SQL Day 1 — DB Basics · MS-SQL Server 2022 (T-SQL)

> **Dialect:** Microsoft SQL Server 2022 (16.x) · T-SQL · Default schema: `dbo`

---

> **SQL Server 2022 New Features relevant to this topic:**
> - `LEAST()` / `GREATEST()` functions (new in 2022)
> - `DATETRUNC()` function (new in 2022)
> - `IS [NOT] DISTINCT FROM` comparisons (new in 2022)
> - `JSON_ARRAY()` / `JSON_OBJECT()` (new in 2022)
> - **Azure Synapse Link** built-in support
> - `STRING_AGG()` available (since 2017, fully supported in 2022)
> - Improved `GENERATE_SERIES()` function (new in 2022)

## Topic 1 — DBMS vs RDBMS

### Theory
- **DBMS** stores data in any format (files, hierarchical) — no formal relationships
- **RDBMS** stores data in **tables** linked via **PK → FK** — enforces ACID
- MS-SQL Server is Microsoft's enterprise RDBMS using **T-SQL** (Transact-SQL)
- Schema ≠ Database — schemas are **namespaces inside** a database (default: `dbo`)
- Supports **ACID + MVCC** (Multi-Version Concurrency Control)
- Default port: **1433** · DML is **auto-committed** by default
- Unique feature: `DENY` permission overrides `GRANT`

### ACID Properties
| Property | Meaning |
|---|---|
| Atomicity | All or nothing — all DML in a tx succeed or all fail |
| Consistency | DB always moves from valid state to valid state |
| Isolation | Concurrent transactions don't interfere |
| Durability | Committed changes survive crashes |

### Syntax
```sql
-- Create and use database
CREATE DATABASE company_hr
  COLLATE SQL_Latin1_General_CP1_CI_AS;
USE company_hr;
GO

-- List databases
SELECT name FROM sys.databases;
DROP DATABASE company_hr;

-- MS-SQL uses [] for reserved word identifiers
SELECT [name], [salary] FROM [dbo].[employees];
```

### Key Constraints
```sql
PRIMARY KEY   -- UNIQUE + NOT NULL (auto-indexed)
FOREIGN KEY   -- CONSTRAINT fk_name FOREIGN KEY(col) REFERENCES t(col)
NOT NULL      -- value is required
UNIQUE        -- CONSTRAINT uq_name UNIQUE(col)
CHECK(cond)   -- CONSTRAINT chk_name CHECK(col > 0)
DEFAULT val   -- DEFAULT GETDATE() or literal
IDENTITY(1,1) -- auto-generate integer PK
```

---

## Topic 2 — Table (Rows & Columns)

### Theory
- A **Table** (Relation) = rows + columns
- **Row** (Record/Tuple) = one complete data entry
- **Column** (Field/Attribute) = one data type category
- **Primary Key** = uniquely identifies each row — NOT NULL + UNIQUE
- **Foreign Key** = references PK of another table — creates relationship
- Use `NVARCHAR` (not `VARCHAR`) for Unicode string support
- Always name constraints explicitly for easier maintenance

### Data Types
| Category | MS-SQL Type | Notes |
|---|---|---|
| Integer | `INT`, `BIGINT`, `SMALLINT` | Standard integers |
| Decimal | `DECIMAL(p,s)` | Use for money |
| Unicode string | `NVARCHAR(n)` | N prefix = Unicode (preferred) |
| Fixed string | `NCHAR(n)` | Fixed-length Unicode |
| Date | `DATE` | Date only |
| Date+time | `DATETIME2` | More precision than DATETIME |
| Boolean | `BIT` | 0 = false, 1 = true |
| Long text | `NVARCHAR(MAX)` | Up to 2GB |
| UUID | `UNIQUEIDENTIFIER` | GUID type |

### Syntax — CREATE TABLE
```sql
CREATE TABLE employees (
    emp_id      INT            IDENTITY(1,1) PRIMARY KEY,
    first_name  NVARCHAR(50)   NOT NULL,
    last_name   NVARCHAR(50)   NOT NULL,
    email       NVARCHAR(100)  NOT NULL CONSTRAINT uq_email UNIQUE,
    salary      DECIMAL(10,2)  CONSTRAINT chk_sal CHECK (salary > 0),
    hire_date   DATE           DEFAULT GETDATE(),
    is_active   BIT            DEFAULT 1,
    dept_id     INT            NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id)
        REFERENCES dbo.departments(dept_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);
```

### Example — INSERT & SELECT
```sql
INSERT INTO employees (first_name, last_name, email, salary, dept_id)
VALUES (N'Alice', N'Sharma', N'alice@co.com', 75000, 1);

-- String concat with + operator
SELECT TOP 10
    emp_id,
    first_name + ' ' + last_name AS full_name,    -- + for concat
    salary
FROM   employees
WHERE  salary > 70000
ORDER BY salary DESC;
```

---

## Topic 3 — SQL Commands

### DDL — Data Definition Language
> Operates on **structure**. Auto-committed. Cannot be rolled back.

```sql
CREATE TABLE products (
    id    INT           IDENTITY(1,1) PRIMARY KEY,
    name  NVARCHAR(100) NOT NULL,
    price DECIMAL(8,2)  DEFAULT 0.00
);

ALTER TABLE products ADD           stock_qty INT DEFAULT 0;
ALTER TABLE products ALTER COLUMN  price DECIMAL(10,2);   -- ALTER COLUMN
ALTER TABLE products DROP COLUMN   stock_qty;
EXEC sp_rename 'products', 'items';    -- rename via stored proc
TRUNCATE TABLE products;
DROP TABLE IF EXISTS products;
```

### DML — Data Manipulation Language
> Operates on **data**. Can be rolled back. Auto-committed by default.

```sql
-- INSERT
INSERT INTO employees (first_name, salary, dept_id)
VALUES (N'Alice', 75000, 1);

-- SELECT with TOP
SELECT TOP 10 emp_id, first_name, salary
FROM   employees
WHERE  salary > 60000
ORDER BY salary DESC;

-- UPDATE — always use WHERE!
UPDATE employees
SET    salary = salary * 1.10
WHERE  dept_id = 1;

-- DELETE with OUTPUT — returns deleted rows
DELETE FROM employees
OUTPUT DELETED.emp_id, DELETED.first_name
WHERE  emp_id = 101;
```

### DCL — Data Control Language
> Controls **permissions**. Auto-committed. DENY is unique to MS-SQL.

```sql
GRANT  SELECT, INSERT ON dbo.employees TO john;
GRANT  EXECUTE ON dbo.GetDeptReport TO john;
REVOKE INSERT ON dbo.employees FROM john;
DENY   DELETE ON dbo.employees TO john;   -- explicit block (overrides GRANT)
```

### TCL — Transaction Control Language
> MS-SQL keyword: `BEGIN TRANSACTION`. Savepoint: `SAVE TRANSACTION`.

```sql
BEGIN TRANSACTION;
  UPDATE accounts SET balance = balance - 5000 WHERE id = 1;
  SAVE TRANSACTION after_debit;          -- SAVE TRANSACTION (not SAVEPOINT!)
  UPDATE accounts SET balance = balance + 5000 WHERE id = 2;
COMMIT TRANSACTION;
-- ROLLBACK TRANSACTION after_debit;    (partial undo)

-- TRY/CATCH for error handling
BEGIN TRY
  BEGIN TRANSACTION;
    UPDATE accounts SET balance = balance - 500 WHERE id = 1;
  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  ROLLBACK TRANSACTION;
  PRINT ERROR_MESSAGE();
END CATCH
```

### DDL vs DML vs DCL vs TCL
| Type | Commands | Auto-Commit | Rollback? |
|---|---|---|---|
| DDL | CREATE, ALTER, DROP, TRUNCATE | ✅ Yes | ❌ No |
| DML | SELECT, INSERT, UPDATE, DELETE | ✅ Yes (default) | ✅ Yes (in tx) |
| DCL | GRANT, REVOKE, DENY | ✅ Yes | ❌ No |
| TCL | COMMIT, ROLLBACK, SAVE TRANSACTION | Manual | ✅ Yes |

---

## Topic 4 — Schema

### Theory
- In MS-SQL, a schema is a **namespace inside a database** (not the same as the database itself)
- One database can have multiple schemas: `hr`, `fin`, `dbo`
- Default schema is **`dbo`** (database owner)
- Objects accessed as `schema.table` or `database.schema.table`
- Grant access per schema: `GRANT SELECT ON SCHEMA::name TO user`

### Syntax
```sql
-- Create schemas inside current database
CREATE SCHEMA hr      AUTHORIZATION dbo;
CREATE SCHEMA finance AUTHORIZATION dbo;

-- Create table inside schema
CREATE TABLE hr.employees (
    emp_id INT IDENTITY(1,1) PRIMARY KEY,
    name   NVARCHAR(100)
);
CREATE TABLE finance.invoices (
    invoice_id INT IDENTITY(1,1) PRIMARY KEY,
    amount     DECIMAL(10,2)
);

-- Both can have audit_logs without name conflict
CREATE TABLE hr.audit_logs      (id INT, action NVARCHAR(200));
CREATE TABLE finance.audit_logs (id INT, action NVARCHAR(200));

-- Access with schema prefix
SELECT * FROM hr.employees;
SELECT * FROM finance.invoices;

-- List all schemas
SELECT name FROM sys.schemas;

-- Grant schema-level access
GRANT SELECT ON SCHEMA::hr TO hr_user;
```

---

## Topic 5 — Database Objects

### Theory
| Object | Stores Data? | Purpose |
|---|---|---|
| Table | ✅ Yes | Primary data storage |
| View | ❌ No | Virtual table — abstraction, security |
| Indexed View | ✅ Yes | Materialized view equivalent |
| Stored Procedure | ❌ No | T-SQL logic block — EXEC |
| Table-Valued Function | ❌ No | Returns a result set |
| Trigger | ❌ No | Auto-run on INSERT/UPDATE/DELETE |

### VIEW
```sql
-- MS-SQL uses CREATE OR ALTER (no need to drop first)
CREATE OR ALTER VIEW dbo.v_active_employees AS
SELECT emp_id, first_name, salary
FROM   dbo.employees
WHERE  is_active = 1;

SELECT * FROM dbo.v_active_employees;
DROP VIEW IF EXISTS dbo.v_active_employees;

-- Indexed View (stores data physically — like Materialized View)
CREATE VIEW dbo.dept_summary WITH SCHEMABINDING AS
SELECT dept_id, COUNT_BIG(*) AS headcount, SUM(salary) AS payroll
FROM   dbo.employees
GROUP BY dept_id;
-- Create unique clustered index to materialize it
CREATE UNIQUE CLUSTERED INDEX idx_dept ON dbo.dept_summary(dept_id);
```

### STORED PROCEDURE
> T-SQL: `@param` prefix, `SET NOCOUNT ON`, called with `EXEC`, ends with `GO`.

```sql
CREATE OR ALTER PROCEDURE dbo.GetEmpByDept
    @dept_id INT                          -- @ prefix for all params
AS
BEGIN
    SET NOCOUNT ON;                       -- suppress rowcount messages
    SELECT emp_id, first_name, salary
    FROM   dbo.employees
    WHERE  dept_id = @dept_id
    ORDER BY salary DESC;
END;
GO

-- Call
EXEC dbo.GetEmpByDept @dept_id = 1;
```

---

## Topic 6 — Relationships

### Theory
| Type | Example | FK Location | Key Trick |
|---|---|---|---|
| 1:1 | Employee ↔ Passport | Child table | UNIQUE on FK column |
| 1:N | Department → Employees | Many side | Regular FK |
| M:N | Students ↔ Courses | Junction table | Composite PK + 2 FKs |

> Best practice: **always name constraints** in MS-SQL for easier management.

### Syntax
```sql
-- FK options (all supported in MS-SQL)
CONSTRAINT fk_name FOREIGN KEY (col)
  REFERENCES schema.other_table(pk_col)
  ON DELETE CASCADE    -- ✅ supported
  ON DELETE SET NULL   -- ✅ supported
  ON UPDATE CASCADE    -- ✅ supported

-- Disable FK temporarily
ALTER TABLE t NOCHECK CONSTRAINT fk_name;
ALTER TABLE t CHECK CONSTRAINT fk_name;
-- Check constraint violations
DBCC CHECKCONSTRAINTS('table_name');
```

### Example
```sql
-- 1:1
CREATE TABLE dbo.passports (
    pid    INT IDENTITY(1,1) PRIMARY KEY,
    emp_id INT UNIQUE,                     -- UNIQUE = 1:1!
    pno    NVARCHAR(20),
    CONSTRAINT fk_pass FOREIGN KEY (emp_id)
        REFERENCES dbo.employees(emp_id) ON DELETE CASCADE
);

-- M:N junction table
CREATE TABLE dbo.enrollments (
    student_id  INT,
    course_id   INT,
    grade       CHAR(1),
    CONSTRAINT pk_enroll PRIMARY KEY (student_id, course_id),
    CONSTRAINT fk_stu FOREIGN KEY (student_id)
        REFERENCES dbo.students(student_id),
    CONSTRAINT fk_crs FOREIGN KEY (course_id)
        REFERENCES dbo.courses(course_id)
);
```

---

## Topic 7 — Normalization

### Why Normalize?
| Anomaly | Problem |
|---|---|
| Insert | Can't add data without adding unrelated data |
| Update | One fact in many rows → inconsistency risk |
| Delete | Deleting one row accidentally removes other info |

### 1NF — First Normal Form
> **Rule:** Atomic values per cell. Unique rows. No repeating groups.

```sql
-- ✅ 1NF: one phone per row
CREATE TABLE dbo.employee_phones (
    emp_id     INT          NOT NULL,
    phone_no   NVARCHAR(15) NOT NULL,
    phone_type NVARCHAR(10)
               CHECK (phone_type IN ('mobile','home','work')),
    CONSTRAINT pk_ph PRIMARY KEY (emp_id, phone_no)
);

-- Aggregate back with STRING_AGG (standard in SQL Server 2022)
SELECT emp_id, STRING_AGG(phone_no, ', ') AS phones
FROM   dbo.employee_phones GROUP BY emp_id;
```

### 2NF — Second Normal Form
> **Rule:** 1NF + **no partial dependency** on composite PK.

```sql
-- ✅ 2NF FIX in T-SQL
CREATE TABLE dbo.students (
    student_id   INT           IDENTITY(1,1) PRIMARY KEY,
    student_name NVARCHAR(100) NOT NULL
);
CREATE TABLE dbo.courses (
    course_id   NVARCHAR(10)  PRIMARY KEY,
    course_name NVARCHAR(100) NOT NULL
);
CREATE TABLE dbo.enrollments (
    student_id INT, course_id NVARCHAR(10), grade CHAR(1),
    CONSTRAINT pk_e PRIMARY KEY (student_id, course_id),
    CONSTRAINT fk_s FOREIGN KEY (student_id)
        REFERENCES dbo.students(student_id),
    CONSTRAINT fk_c FOREIGN KEY (course_id)
        REFERENCES dbo.courses(course_id)
);
```

### 3NF — Third Normal Form
> **Rule:** 2NF + **no transitive dependency**.

```sql
-- ✅ 3NF FIX in T-SQL
CREATE TABLE dbo.zip_codes (
    zip_code CHAR(10)    PRIMARY KEY,
    city     NVARCHAR(50),
    state    NVARCHAR(50)
);
CREATE TABLE dbo.employees (
    emp_id   INT          IDENTITY(1,1) PRIMARY KEY,
    name     NVARCHAR(100),
    zip_code CHAR(10),
    CONSTRAINT fk_zip FOREIGN KEY (zip_code)
        REFERENCES dbo.zip_codes(zip_code)
);

SELECT e.name, z.city, z.state
FROM   dbo.employees e
JOIN   dbo.zip_codes z ON e.zip_code = z.zip_code;
```

### Normal Forms Summary
| Form | Rule Added | Eliminates |
|---|---|---|
| 1NF | Atomic values, unique rows | Multi-valued cells |
| 2NF | No partial dependency on composite PK | Redundancy from partial PKs |
| 3NF | No transitive dependency | Indirect column dependencies |

---

## MS-SQL Quick Reference

| Feature | MS-SQL Syntax |
|---|---|
| Auto-increment PK | `INT IDENTITY(1,1) PRIMARY KEY` |
| String type | `NVARCHAR(n)` (Unicode) |
| Boolean | `BIT` — 0/1 |
| Current date/time | `GETDATE()` or `SYSDATETIME()` |
| Limit rows | `SELECT TOP n` |
| String concat | `a + b` (+ operator) |
| String aggregation | `STRING_AGG(col, ', ')` (available since 2017, standard in 2022) |
| Begin transaction | `BEGIN TRANSACTION` |
| Savepoint | `SAVE TRANSACTION sp_name` |
| Rename table | `EXEC sp_rename 'old', 'new'` |
| Modify column type | `ALTER TABLE t ALTER COLUMN col TYPE` |
| List schemas | `SELECT name FROM sys.schemas` |
| List tables | `SELECT * FROM sys.tables` |
| Explicit permission block | `DENY privilege ON obj TO user` |
| Procedure call | `EXEC schema.proc_name @p = val` |
| Batch separator | `GO` |
