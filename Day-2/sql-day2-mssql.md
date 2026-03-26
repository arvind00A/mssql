# SQL Day 2 — Keys & Constraints · MS-SQL Server 2022

> **Dialect:** Microsoft SQL Server 2022 (16.x) · T-SQL · Default schema: `dbo`

---

## Topic 1 — Constraints: Definition & Types

### Theory
- A **constraint** is a rule enforced by SQL Server on INSERT, UPDATE, and DELETE
- Violations are **automatically rejected** — no application code needed
- Best practice: **always name constraints** — unnamed ones get system-generated names like `UQ__users__ABC123` which are unmanageable
- Can be defined **column-level** (inline) or **table-level** (end of CREATE TABLE)
- Unique MS-SQL feature: `DENY` permission overrides `GRANT` independently of constraints

### 5 Constraint Types
| Abbr | Name | Enforces |
|---|---|---|
| `PK` | Primary Key | Unique + Not Null — identifies each row |
| `UQ` | Unique Key | No duplicate values — allows **one** NULL |
| `FK` | Foreign Key | Referential integrity between tables |
| `CK` | Check | Custom validation rule |
| `DF` | Default | Auto value when column omitted in INSERT |

### Syntax — Adding / Dropping Constraints
```sql
-- Add at CREATE TABLE (column-level)
col_name  datatype  CONSTRAINT name  constraint_type

-- Add at CREATE TABLE (table-level)
CONSTRAINT name  constraint_type (col1, col2)

-- Add to existing table
ALTER TABLE dbo.table ADD CONSTRAINT name type (col);

-- Remove constraint
ALTER TABLE dbo.table DROP CONSTRAINT name;

-- Disable without dropping (FK and CHECK only)
ALTER TABLE dbo.table NOCHECK CONSTRAINT name;
ALTER TABLE dbo.table CHECK   CONSTRAINT name;

-- View constraints
SELECT name, type_desc, is_disabled
FROM   sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.employees');
SELECT name FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID('dbo.employees');
```

---

## Topic 2 — Primary Key (PK)

### Theory
- Uniquely identifies **every row** in a table
- Enforces **UNIQUE + NOT NULL** automatically
- **Only ONE PRIMARY KEY** per table
- By default creates a **clustered index** — use `NONCLUSTERED` to override
- `IDENTITY(seed, increment)` generates surrogate PK values automatically
- Named PK constraint is required to drop or reference the constraint

### Syntax
```sql
-- Inline PK with IDENTITY
emp_id INT IDENTITY(1,1) CONSTRAINT pk_employees PRIMARY KEY

-- Clustered vs Non-Clustered PK
CONSTRAINT pk_emp PRIMARY KEY CLUSTERED (emp_id)
CONSTRAINT pk_emp PRIMARY KEY NONCLUSTERED (emp_id)

-- Composite PK
CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id)

-- Add PK to existing table
ALTER TABLE dbo.employees
  ADD CONSTRAINT pk_employees PRIMARY KEY CLUSTERED (emp_id);

-- Drop PK
ALTER TABLE dbo.employees DROP CONSTRAINT pk_employees;
```

### Example
```sql
CREATE TABLE dbo.employees (
    emp_id     INT           IDENTITY(1,1),
    first_name NVARCHAR(50)  NOT NULL,
    last_name  NVARCHAR(50)  NOT NULL,
    email      NVARCHAR(100) NOT NULL,
    CONSTRAINT pk_employees PRIMARY KEY CLUSTERED (emp_id)
);

-- Composite PK (junction table)
CREATE TABLE dbo.order_items (
    order_id   INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT DEFAULT 1,
    unit_price DECIMAL(8,2),
    CONSTRAINT pk_order_items PRIMARY KEY (order_id, product_id)
);

-- IDENTITY auto-fills — no value needed
INSERT INTO dbo.employees (first_name, last_name, email)
VALUES (N'Alice', N'Sharma', N'alice@co.com');

-- Get the newly inserted PK
SELECT SCOPE_IDENTITY() AS new_emp_id;

-- ❌ FAILS — duplicate PK (if inserted manually)
-- Violation of PRIMARY KEY constraint 'pk_employees'

-- Re-seed IDENTITY (e.g. after delete)
DBCC CHECKIDENT ('dbo.employees', RESEED, 0);
```

---

## Topic 3 — Unique Key (UQ)

### Theory
- Ensures **no two rows have the same value** in the constrained column(s)
- **Allows NULL** — but MS-SQL allows **only ONE NULL** per unique column (NULLs treated as equal)
- **Multiple UNIQUE constraints** per table are allowed
- Creates a **non-clustered index** by default (can be `UNIQUE CLUSTERED`)
- To allow **multiple NULLs**: use a **filtered unique index** with `WHERE col IS NOT NULL`
- Unique to MS-SQL: `ON DELETE SET DEFAULT` FK action (not available in other RDBMS)

### Syntax
```sql
-- Inline (column-level) — always name it!
email NVARCHAR(100) CONSTRAINT uq_email UNIQUE

-- Table-level
CONSTRAINT uq_email     UNIQUE (email)
CONSTRAINT uq_emp_phone UNIQUE (emp_id, phone_no)   -- composite

-- Clustered UNIQUE
CONSTRAINT uq_email UNIQUE CLUSTERED (email)

-- Allow multiple NULLs — filtered unique index
CREATE UNIQUE INDEX uq_phone_notnull
  ON dbo.users(phone) WHERE phone IS NOT NULL;

-- Add / Drop
ALTER TABLE dbo.users ADD CONSTRAINT uq_email UNIQUE (email);
ALTER TABLE dbo.users DROP CONSTRAINT uq_email;
```

### Example
```sql
CREATE TABLE dbo.users (
    user_id  INT           IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(50)  NOT NULL,
    email    NVARCHAR(100) NOT NULL,
    phone    NVARCHAR(15)  NULL,
    CONSTRAINT uq_username UNIQUE (username),
    CONSTRAINT uq_email    UNIQUE (email)
);

-- ✅ Different emails — OK
INSERT INTO dbo.users (username, email) VALUES (N'alice', N'alice@co.com');
INSERT INTO dbo.users (username, email) VALUES (N'bob',   N'bob@co.com');

-- ❌ FAILS — duplicate email
-- Violation of UNIQUE KEY constraint 'uq_email'

-- MS-SQL: only ONE NULL per unique column
INSERT INTO dbo.users (username, email, phone) VALUES (N'carol', N'carol@co.com', NULL);
-- ❌ This would fail: second NULL in same unique column
-- INSERT INTO dbo.users (username, email, phone) VALUES (N'dave', N'dave@co.com', NULL);

-- Workaround: filtered index allows multiple NULLs
CREATE UNIQUE INDEX uq_phone ON dbo.users(phone) WHERE phone IS NOT NULL;
-- Now multiple NULLs are allowed in phone
```

---

## Topic 4 — Foreign Key (FK)

### Theory
- Column in **child table** references PK/UQ of **parent table**
- Enforces **Referential Integrity** — child FK value must exist in parent
- **Can be NULL** (optional relationship)
- MS-SQL unique action: **`ON DELETE SET DEFAULT`** — sets FK to its DEFAULT value
- Always **name FK constraints** — use `CONSTRAINT fk_name FOREIGN KEY`
- `NOCHECK` disables FK without dropping it (useful for bulk loads)

### ON DELETE / ON UPDATE Actions (MS-SQL)
| Action | Behaviour |
|---|---|
| `CASCADE` | Auto delete/update child rows |
| `SET NULL` | Set FK to NULL |
| `NO ACTION` | Block parent operation (default) |
| `SET DEFAULT` | Set FK to its DEFAULT value ✅ (MS-SQL unique!) |

> ✅ MS-SQL supports **ON UPDATE CASCADE**

### Syntax
```sql
-- Table-level FK (always name it)
CONSTRAINT fk_name FOREIGN KEY (child_col)
  REFERENCES dbo.parent_table(parent_pk)
  ON DELETE CASCADE
  ON UPDATE CASCADE

-- SET DEFAULT (unique to MS-SQL)
dept_id INT DEFAULT 0,
CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id)
  REFERENCES dbo.departments(dept_id)
  ON DELETE SET DEFAULT    -- dept_id reverts to 0 on parent delete

-- Add / Drop
ALTER TABLE dbo.orders
  ADD CONSTRAINT fk_orders_cust
  FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id);
ALTER TABLE dbo.orders DROP CONSTRAINT fk_orders_cust;

-- Disable / Enable FK
ALTER TABLE dbo.orders NOCHECK CONSTRAINT fk_orders_cust;
ALTER TABLE dbo.orders CHECK   CONSTRAINT fk_orders_cust;

-- Check for FK violations
DBCC CHECKCONSTRAINTS('dbo.employees');
```

### Example
```sql
CREATE TABLE dbo.departments (
    dept_id   INT          IDENTITY(1,1) PRIMARY KEY,
    dept_name NVARCHAR(50) NOT NULL
);

CREATE TABLE dbo.employees (
    emp_id  INT           IDENTITY(1,1) PRIMARY KEY,
    name    NVARCHAR(100) NOT NULL,
    dept_id INT           NULL,
    CONSTRAINT fk_emp_dept FOREIGN KEY (dept_id)
        REFERENCES dbo.departments(dept_id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

INSERT INTO dbo.departments (dept_name) VALUES (N'IT'), (N'HR');
INSERT INTO dbo.employees (name, dept_id) VALUES (N'Alice', 1);  -- ✅

-- ❌ FAILS — dept 99 doesn't exist
-- INSERT INTO dbo.employees (name, dept_id) VALUES (N'Bob', 99);
-- FK constraint violation
```

---

## Topic 5 — Check Constraint (CK)

### Theory
- Enforces a **custom Boolean condition** on column values
- **NULL bypasses CHECK** — NULL column = constraint not evaluated (passes)
- Can reference **any column in the same table**
- **Cannot reference other tables** or call non-deterministic functions (`GETDATE()`, `RAND()`)
- `WITH NOCHECK` skips validation of existing data when adding CHECK constraint
- Disable temporarily with `NOCHECK CONSTRAINT`

### Syntax
```sql
-- Column-level
age    INT            CONSTRAINT chk_age    CHECK (age BETWEEN 18 AND 65)
salary DECIMAL(10,2)  CONSTRAINT chk_sal    CHECK (salary > 0)
status NVARCHAR(10)   CONSTRAINT chk_status CHECK (status IN (N'active', N'inactive', N'pending'))

-- Table-level (multi-column)
CONSTRAINT chk_dates CHECK (end_date > start_date OR end_date IS NULL)

-- Add: validates existing data (default)
ALTER TABLE dbo.employees ADD CONSTRAINT chk_sal CHECK (salary > 0);

-- Add: skip validation of existing rows
ALTER TABLE dbo.employees WITH NOCHECK
  ADD CONSTRAINT chk_sal CHECK (salary > 0);

-- Disable / Enable
ALTER TABLE dbo.employees NOCHECK CONSTRAINT chk_sal;
ALTER TABLE dbo.employees CHECK   CONSTRAINT chk_sal;

-- Drop
ALTER TABLE dbo.employees DROP CONSTRAINT chk_sal;
```

### Example
```sql
CREATE TABLE dbo.products (
    product_id INT            IDENTITY(1,1) PRIMARY KEY,
    name       NVARCHAR(100)  NOT NULL,
    price      DECIMAL(10,2)  NOT NULL CONSTRAINT chk_price CHECK (price > 0),
    stock      INT            DEFAULT 0   CONSTRAINT chk_stock CHECK (stock >= 0),
    discount   DECIMAL(5,2)   DEFAULT 0   CONSTRAINT chk_discount CHECK (discount BETWEEN 0 AND 100),
    status     NVARCHAR(10)   CONSTRAINT chk_status CHECK (status IN (N'active', N'draft', N'discontinued')),
    CONSTRAINT chk_disc_lt_price CHECK (discount < price)
);

-- ✅ Valid
INSERT INTO dbo.products (name, price, stock, status)
VALUES (N'Laptop', 999.99, 50, N'active');

-- ❌ FAILS — price <= 0
-- INSERT INTO dbo.products (name, price) VALUES (N'Phone', -100);
-- CHECK constraint 'chk_price' is violated

-- NULL bypasses check
INSERT INTO dbo.products (name, price) VALUES (N'Mouse', 25.99);
-- stock = NULL → check NOT evaluated → passes
```

---

## Topic 6 — Default Constraint (DF)

### Theory
- Auto-fills a column with a **fallback value** when omitted from INSERT
- MS-SQL best practice: **name every DEFAULT constraint** — `CONSTRAINT df_name DEFAULT val`
- Allows functions: `GETDATE()`, `SYSDATETIME()`, `NEWID()`, `SUSER_SNAME()`
- Inserting **explicit NULL overrides the default**
- Use `DEFAULT` keyword in VALUES list to explicitly invoke the default
- Named defaults can be referenced and dropped by name

### Syntax
```sql
-- Named defaults (recommended in MS-SQL)
is_active  TINYINT        CONSTRAINT df_is_active  DEFAULT 1
status     NVARCHAR(10)   CONSTRAINT df_status     DEFAULT N'active'
created_at DATETIME2      CONSTRAINT df_created    DEFAULT GETDATE()
guid_col   UNIQUEIDENTIFIER CONSTRAINT df_guid     DEFAULT NEWID()

-- Add default to existing column
ALTER TABLE dbo.orders
  ADD CONSTRAINT df_status DEFAULT N'pending' FOR status;

-- Drop default
ALTER TABLE dbo.orders DROP CONSTRAINT df_status;

-- Use DEFAULT keyword explicitly in INSERT
INSERT INTO dbo.orders (customer_id, status)
VALUES (1, DEFAULT);   -- status = 'pending'
```

### Example
```sql
CREATE TABLE dbo.orders (
    order_id     INT            IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT            NOT NULL,
    status       NVARCHAR(15)   CONSTRAINT df_status  DEFAULT N'pending',
    total_amount DECIMAL(10,2)  CONSTRAINT df_total   DEFAULT 0.00,
    is_paid      BIT            CONSTRAINT df_paid    DEFAULT 0,
    created_at   DATETIME2      CONSTRAINT df_created DEFAULT GETDATE(),
    guid_ref     UNIQUEIDENTIFIER CONSTRAINT df_guid  DEFAULT NEWID()
);

-- Only required column — rest use defaults
INSERT INTO dbo.orders (customer_id) VALUES (42);
SELECT status, total_amount, is_paid FROM dbo.orders;
-- status=N'pending', total_amount=0.00, is_paid=0, guid_ref=auto-UUID

-- Explicit DEFAULT keyword
INSERT INTO dbo.orders (customer_id, status) VALUES (43, DEFAULT);
-- status = N'pending'

-- Explicit NULL overrides default
INSERT INTO dbo.orders (customer_id, status) VALUES (44, NULL);
-- status = NULL (not N'pending')
```

---

## MS-SQL 2022 Keys & Constraints Quick Reference

| Feature | Syntax |
|---|---|
| Surrogate PK | `INT IDENTITY(1,1) PRIMARY KEY` |
| Named PK (clustered) | `CONSTRAINT pk_name PRIMARY KEY CLUSTERED (col)` |
| Composite PK | `CONSTRAINT pk PRIMARY KEY (col1, col2)` |
| Unique | `CONSTRAINT uq_name UNIQUE (col)` |
| Multiple NULLs in UQ | Filtered: `CREATE UNIQUE INDEX ON t(col) WHERE col IS NOT NULL` |
| Named FK | `CONSTRAINT fk FOREIGN KEY (col) REFERENCES dbo.t(pk)` |
| ON DELETE SET DEFAULT | ✅ Unique to MS-SQL |
| ON UPDATE CASCADE | ✅ Supported |
| Disable FK | `ALTER TABLE t NOCHECK CONSTRAINT fk_name` |
| Check constraint | `CONSTRAINT chk CHECK (col > 0)` |
| Skip existing data | `WITH NOCHECK ADD CONSTRAINT` |
| Named default | `CONSTRAINT df_name DEFAULT val` |
| Add default to existing | `ALTER TABLE t ADD CONSTRAINT df DEFAULT val FOR col` |
| Current timestamp | `DEFAULT GETDATE()` or `DEFAULT SYSDATETIME()` |
| Random UUID | `DEFAULT NEWID()` |
| Check FK violations | `DBCC CHECKCONSTRAINTS('dbo.table')` |
| Re-seed identity | `DBCC CHECKIDENT ('dbo.table', RESEED, 0)` |
| Multiple NULLs in UQ | ❌ Only ONE null allowed (use filtered index) |
