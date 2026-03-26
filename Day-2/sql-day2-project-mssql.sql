-- ============================================================
-- SQL Day 2 — Keys & Constraints · MS-SQL Server 2022
-- Practice Queries: Easy · Moderate · Hard
-- ============================================================

-- SETUP: Run this first
USE master;
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'day2_mssql')
    DROP DATABASE day2_mssql;
GO
CREATE DATABASE day2_mssql COLLATE SQL_Latin1_General_CP1_CI_AS;
GO
USE day2_mssql;
GO

CREATE TABLE dbo.countries (
    country_id   INT           IDENTITY(1,1),
    country_code CHAR(2)       NOT NULL,
    country_name NVARCHAR(100) NOT NULL,
    CONSTRAINT pk_countries   PRIMARY KEY CLUSTERED (country_id),
    CONSTRAINT uq_code        UNIQUE (country_code),
    CONSTRAINT uq_cname       UNIQUE (country_name)
);

CREATE TABLE dbo.departments (
    dept_id   INT          IDENTITY(1,1),
    dept_name NVARCHAR(50) NOT NULL,
    location  NVARCHAR(100),
    budget    DECIMAL(15,2) CONSTRAINT df_budget DEFAULT 0.00,
    CONSTRAINT pk_departments PRIMARY KEY CLUSTERED (dept_id),
    CONSTRAINT uq_dept_name   UNIQUE (dept_name),
    CONSTRAINT chk_dept_budget CHECK (budget >= 0)
);

CREATE TABLE dbo.employees (
    emp_id     INT            IDENTITY(1,1),
    first_name NVARCHAR(50)   NOT NULL,
    last_name  NVARCHAR(50)   NOT NULL,
    email      NVARCHAR(100)  NOT NULL,
    phone      NVARCHAR(15)   NULL,
    salary     DECIMAL(10,2),
    age        INT,
    status     NVARCHAR(10)   CONSTRAINT df_status DEFAULT N'active',
    dept_id    INT            NULL,
    country_id INT            NULL,
    hire_date  DATE           CONSTRAINT df_hire   DEFAULT GETDATE(),
    created_at DATETIME2      CONSTRAINT df_created DEFAULT GETDATE(),
    CONSTRAINT pk_employees    PRIMARY KEY CLUSTERED (emp_id),
    CONSTRAINT uq_emp_email    UNIQUE (email),
    CONSTRAINT fk_emp_dept     FOREIGN KEY (dept_id)    REFERENCES dbo.departments(dept_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_emp_country  FOREIGN KEY (country_id) REFERENCES dbo.countries(country_id)  ON DELETE SET NULL,
    CONSTRAINT chk_salary      CHECK (salary > 0),
    CONSTRAINT chk_age         CHECK (age BETWEEN 18 AND 65),
    CONSTRAINT chk_emp_status  CHECK (status IN (N'active', N'inactive', N'pending'))
);

CREATE TABLE dbo.projects (
    project_id   INT            IDENTITY(1,1),
    project_name NVARCHAR(100)  NOT NULL,
    budget       DECIMAL(15,2)  CONSTRAINT df_proj_budget DEFAULT 0.00,
    start_date   DATE,
    end_date     DATE,
    CONSTRAINT pk_projects     PRIMARY KEY (project_id),
    CONSTRAINT uq_proj_name    UNIQUE (project_name),
    CONSTRAINT chk_proj_budget CHECK (budget >= 0),
    CONSTRAINT chk_proj_dates  CHECK (end_date > start_date OR end_date IS NULL)
);

CREATE TABLE dbo.emp_projects (
    emp_id     INT          NOT NULL,
    project_id INT          NOT NULL,
    role       NVARCHAR(50) CONSTRAINT df_role DEFAULT N'member',
    joined_at  DATE         CONSTRAINT df_joined DEFAULT GETDATE(),
    CONSTRAINT pk_emp_projects PRIMARY KEY (emp_id, project_id),
    CONSTRAINT fk_ep_emp       FOREIGN KEY (emp_id)     REFERENCES dbo.employees(emp_id) ON DELETE CASCADE,
    CONSTRAINT fk_ep_proj      FOREIGN KEY (project_id) REFERENCES dbo.projects(project_id) ON DELETE CASCADE,
    CONSTRAINT chk_ep_role     CHECK (role IN (N'lead', N'senior', N'member', N'intern'))
);
GO

-- Seed data
INSERT INTO dbo.countries (country_code, country_name) VALUES ('IN',N'India'),('US',N'United States'),('UK',N'United Kingdom');
INSERT INTO dbo.departments (dept_name, location, budget) VALUES (N'Engineering',N'Bangalore',5000000),(N'HR',N'Mumbai',2000000),(N'Finance',N'Delhi',3000000),(N'Marketing',N'Pune',1500000);
INSERT INTO dbo.employees (first_name, last_name, email, phone, salary, age, status, dept_id, country_id)
VALUES
    (N'Alice',N'Sharma', N'alice@co.com',N'9876543210',75000,28,N'active',  1,1),
    (N'Bob',  N'Verma',  N'bob@co.com',  NULL,        62000,35,N'active',  2,1),
    (N'Carol',N'Singh',  N'carol@co.com',N'9123456789',85000,30,N'active',  1,2),
    (N'Dave', N'Kumar',  N'dave@co.com', N'9988776655',55000,40,N'inactive',3,1),
    (N'Eve',  N'Patel',  N'eve@co.com',  NULL,        90000,32,N'active',  1,3);
INSERT INTO dbo.projects (project_name, budget, start_date, end_date) VALUES (N'Alpha',500000,'2024-01-01','2024-06-30'),(N'Beta',300000,'2024-03-01',NULL),(N'Gamma',150000,'2024-07-01','2024-12-31');
INSERT INTO dbo.emp_projects VALUES (1,1,N'lead','2024-01-01'),(1,2,N'senior','2024-03-01'),(2,1,N'member','2024-01-15'),(3,2,N'lead','2024-03-01');
GO

-- ============================================================
-- EASY QUERIES (1–8)
-- ============================================================

-- E1: List all constraint names and types on employees table
SELECT
    cc.name            AS constraint_name,
    cc.type_desc       AS constraint_type,
    cc.is_disabled,
    c.name             AS column_name
FROM   sys.check_constraints cc
LEFT JOIN sys.columns c ON cc.parent_object_id = c.object_id
    AND cc.parent_column_id = c.column_id
WHERE  cc.parent_object_id = OBJECT_ID('dbo.employees')
UNION ALL
SELECT
    kc.name, kc.type_desc, 0, col.name
FROM   sys.key_constraints kc
JOIN   sys.index_columns ic ON kc.unique_index_id = ic.index_id AND kc.parent_object_id = ic.object_id
JOIN   sys.columns col      ON ic.object_id = col.object_id AND ic.column_id = col.column_id
WHERE  kc.parent_object_id = OBJECT_ID('dbo.employees');
GO

-- E2: List all DEFAULT constraint values for employees
SELECT
    dc.name         AS constraint_name,
    c.name          AS column_name,
    dc.definition   AS default_value
FROM   sys.default_constraints dc
JOIN   sys.columns c ON dc.parent_object_id = c.object_id
    AND dc.parent_column_id = c.column_id
WHERE  dc.parent_object_id = OBJECT_ID('dbo.employees');
GO

-- E3: Select all active employees ordered by salary DESC
SELECT emp_id,
       first_name + N' ' + last_name AS full_name,
       salary, status, hire_date
FROM   dbo.employees
WHERE  status = N'active'
ORDER BY salary DESC;

-- E4: Count employees per department including nulls
SELECT
    ISNULL(d.dept_name, N'No Department') AS department,
    COUNT(e.emp_id) AS headcount
FROM   dbo.departments d
LEFT JOIN dbo.employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY headcount DESC;

-- E5: List all unique constraints and their columns
SELECT
    kc.name          AS constraint_name,
    c.name           AS column_name,
    kc.type_desc
FROM   sys.key_constraints kc
JOIN   sys.index_columns ic ON kc.unique_index_id = ic.index_id AND kc.parent_object_id = ic.object_id
JOIN   sys.columns c        ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE  kc.type = 'UQ'
ORDER BY kc.name;

-- E6: Find employees with NULL phone (UNIQUE column with one-NULL rule)
SELECT emp_id, first_name + N' ' + last_name AS name, phone
FROM   dbo.employees WHERE phone IS NULL;

-- E7: List all FK relationships in day2_mssql
SELECT
    OBJECT_NAME(fk.parent_object_id)       AS child_table,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id)       AS fk_column,
    OBJECT_NAME(fk.referenced_object_id)   AS parent_table,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS pk_column,
    fk.delete_referential_action_desc AS on_delete,
    fk.update_referential_action_desc AS on_update
FROM   sys.foreign_keys fk
JOIN   sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
ORDER BY child_table;

-- E8: Verify CHECK constraints catch invalid data (test chk_age)
-- This should succeed:
BEGIN TRY
    INSERT INTO dbo.employees (first_name, last_name, email, salary, age, status, dept_id, country_id)
    VALUES (N'Test', N'Valid', N'valid@co.com', 50000, 25, N'active', 1, 1);
    PRINT 'Valid insert succeeded';
END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE();
END CATCH;
-- This should fail:
BEGIN TRY
    INSERT INTO dbo.employees (first_name, last_name, email, salary, age, status, dept_id, country_id)
    VALUES (N'Test', N'Invalid', N'invalid@co.com', 50000, 15, N'active', 1, 1);
    PRINT 'Should not reach here';
END TRY
BEGIN CATCH
    PRINT 'Caught: ' + ERROR_MESSAGE();  -- CHECK constraint chk_age violated
END CATCH;
GO


-- ============================================================
-- MODERATE QUERIES (1–6)
-- ============================================================

-- M1: Add a named DEFAULT constraint to an existing column
ALTER TABLE dbo.employees
  ADD CONSTRAINT df_emp_status DEFAULT N'pending' FOR status;
-- Check it was added
SELECT name, definition FROM sys.default_constraints
WHERE  parent_object_id = OBJECT_ID('dbo.employees') AND name = 'df_emp_status';
GO

-- M2: Test ON DELETE SET NULL — cascade behaviour
PRINT 'Before delete: dept_id for Bob = ' + CAST((SELECT TOP 1 dept_id FROM dbo.employees WHERE email = N'bob@co.com') AS NVARCHAR);
DELETE FROM dbo.departments WHERE dept_name = N'HR';
PRINT 'After delete:  dept_id for Bob = ' + ISNULL(CAST((SELECT TOP 1 dept_id FROM dbo.employees WHERE email = N'bob@co.com') AS NVARCHAR), 'NULL');
GO

-- M3: Demonstrate ON DELETE SET DEFAULT (unique MS-SQL feature)
CREATE TABLE dbo.emp_status_log (
    log_id    INT        IDENTITY(1,1) PRIMARY KEY,
    emp_id    INT        DEFAULT 0,    -- DEFAULT = 0 (unknown)
    action    NVARCHAR(50),
    logged_at DATETIME2  DEFAULT GETDATE()
);
-- Note: ON DELETE SET DEFAULT is only for FK — demonstrated conceptually:
-- If emp_id FK referenced employees with ON DELETE SET DEFAULT,
-- emp_id would revert to 0 when the employee is deleted.
GO

-- M4: Add NOCHECK constraint — skip existing data validation
ALTER TABLE dbo.employees
  WITH NOCHECK ADD CONSTRAINT chk_salary_hi CHECK (salary < 200000);
-- Verify it's marked as not trusted
SELECT name, is_not_trusted, is_disabled
FROM   sys.check_constraints
WHERE  parent_object_id = OBJECT_ID('dbo.employees') AND name = 'chk_salary_hi';
GO

-- M5: Disable and re-enable a FK constraint
ALTER TABLE dbo.emp_projects NOCHECK CONSTRAINT fk_ep_emp;
-- Now can insert emp_id that doesn't exist (dangerous!)
INSERT INTO dbo.emp_projects VALUES (999, 1, N'member', GETDATE());
ALTER TABLE dbo.emp_projects CHECK CONSTRAINT fk_ep_emp;
-- Check for orphan rows
SELECT ep.emp_id FROM dbo.emp_projects ep
LEFT JOIN dbo.employees e ON ep.emp_id = e.emp_id
WHERE e.emp_id IS NULL;
-- Clean up
DELETE FROM dbo.emp_projects WHERE emp_id = 999;
GO

-- M6: Use FILTERED UNIQUE INDEX for multiple NULLs
-- Drop old unique on phone (only allowed one NULL)
CREATE UNIQUE INDEX uq_phone_notnull
  ON dbo.employees(phone) WHERE phone IS NOT NULL;
-- Now multiple NULL phones work
INSERT INTO dbo.employees (first_name, last_name, email, salary, age, status, dept_id, country_id)
VALUES (N'Frank', N'Null', N'frank@co.com', 50000, 28, N'active', 1, 1);
-- Frank also has NULL phone — now allowed!
GO


-- ============================================================
-- HARD QUERIES (1–5)
-- ============================================================

-- H1: Self-referencing FK (org chart / hierarchy)
CREATE TABLE dbo.org_chart (
    emp_id     INT           IDENTITY(1,1),
    name       NVARCHAR(100) NOT NULL,
    manager_id INT           NULL,
    level_no   INT           DEFAULT 1,
    CONSTRAINT pk_org     PRIMARY KEY (emp_id),
    CONSTRAINT fk_manager FOREIGN KEY (manager_id)
        REFERENCES dbo.org_chart(emp_id)
        ON DELETE NO ACTION,   -- cannot cascade self-ref
    CONSTRAINT chk_level  CHECK (level_no BETWEEN 1 AND 10)
);
INSERT INTO dbo.org_chart (name, manager_id, level_no) VALUES (N'CEO',NULL,1);
INSERT INTO dbo.org_chart (name, manager_id, level_no) VALUES (N'VP Eng',1,2);
INSERT INTO dbo.org_chart (name, manager_id, level_no) VALUES (N'Dev Lead',2,3);
SELECT o.name, m.name AS reports_to, o.level_no
FROM   dbo.org_chart o
LEFT JOIN dbo.org_chart m ON o.manager_id = m.emp_id
ORDER BY o.level_no;
GO

-- H2: Constraint audit — find all check constraints and their definitions
SELECT
    t.name                     AS table_name,
    cc.name                    AS constraint_name,
    cc.definition              AS rule,
    cc.is_not_trusted          AS skipped_existing_data,
    cc.is_disabled
FROM   sys.check_constraints cc
JOIN   sys.tables t ON cc.parent_object_id = t.object_id
ORDER BY t.name, cc.name;
GO

-- H3: Find tables with no PRIMARY KEY (data integrity risk)
SELECT t.name AS table_without_pk
FROM   sys.tables t
WHERE  t.type = 'U'
  AND  NOT EXISTS (
       SELECT 1 FROM sys.key_constraints kc
       WHERE  kc.parent_object_id = t.object_id AND kc.type = 'PK'
  )
ORDER BY t.name;
GO

-- H4: Demonstrate DBCC CHECKCONSTRAINTS to find violations
-- Insert with NOCHECK to bypass
ALTER TABLE dbo.employees NOCHECK CONSTRAINT chk_age;
INSERT INTO dbo.employees (first_name, last_name, email, salary, age, status, dept_id, country_id)
VALUES (N'Young', N'Kid', N'young@co.com', 50000, 15, N'active', 1, 1);
ALTER TABLE dbo.employees CHECK CONSTRAINT chk_age;
-- Find the violation using DBCC
DBCC CHECKCONSTRAINTS('dbo.employees');
-- Clean up
DELETE FROM dbo.employees WHERE email = N'young@co.com';
GO

-- H5: Script to generate a constraint summary report for the whole database
SELECT
    t.name                              AS table_name,
    SUM(CASE WHEN kc.type='PK' THEN 1 ELSE 0 END) AS pk_count,
    SUM(CASE WHEN kc.type='UQ' THEN 1 ELSE 0 END) AS uq_count,
    COUNT(DISTINCT fk.name)             AS fk_count,
    COUNT(DISTINCT cc.name)             AS ck_count,
    COUNT(DISTINCT dc.name)             AS df_count
FROM   sys.tables t
LEFT JOIN sys.key_constraints  kc ON kc.parent_object_id = t.object_id
LEFT JOIN sys.foreign_keys     fk ON fk.parent_object_id = t.object_id
LEFT JOIN sys.check_constraints cc ON cc.parent_object_id = t.object_id
LEFT JOIN sys.default_constraints dc ON dc.parent_object_id = t.object_id
GROUP BY t.name
ORDER BY t.name;
GO

-- ============================================================
-- CLEANUP
-- ============================================================
-- USE master; DROP DATABASE day2_mssql;
