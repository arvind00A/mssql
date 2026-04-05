-- ============================================================
-- SQL Day 4 — Joins Basics · MS-SQL Server 2022
-- Practice Queries: Easy · Moderate · Hard
-- ============================================================
USE master; GO
IF EXISTS (SELECT name FROM sys.databases WHERE name='day4_mssql') DROP DATABASE day4_mssql; GO
CREATE DATABASE day4_mssql; GO
USE day4_mssql; GO

CREATE TABLE dbo.departments (dept_id INT IDENTITY(1,1) PRIMARY KEY, dept_name NVARCHAR(50) NOT NULL UNIQUE, location NVARCHAR(100), budget DECIMAL(15,2) DEFAULT 0);
CREATE TABLE dbo.employees (
    emp_id INT IDENTITY(1,1) PRIMARY KEY, first_name NVARCHAR(50) NOT NULL, last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE, salary DECIMAL(10,2) NOT NULL, age INT, status NVARCHAR(10) DEFAULT N'active',
    dept_id INT REFERENCES dbo.departments(dept_id), manager_id INT REFERENCES dbo.employees(emp_id),
    hire_date DATE DEFAULT GETDATE()
);
CREATE TABLE dbo.projects (project_id INT IDENTITY(1,1) PRIMARY KEY, project_name NVARCHAR(100) NOT NULL UNIQUE, budget DECIMAL(15,2) DEFAULT 0, start_date DATE, end_date DATE, dept_id INT REFERENCES dbo.departments(dept_id));
CREATE TABLE dbo.emp_projects (emp_id INT NOT NULL REFERENCES dbo.employees(emp_id) ON DELETE CASCADE, project_id INT NOT NULL REFERENCES dbo.projects(project_id) ON DELETE CASCADE, role NVARCHAR(50) DEFAULT N'member', hours INT DEFAULT 0, PRIMARY KEY (emp_id,project_id));
CREATE TABLE dbo.salary_grades (grade CHAR(1) PRIMARY KEY, min_salary DECIMAL(10,2), max_salary DECIMAL(10,2), label NVARCHAR(20));
GO

INSERT INTO dbo.departments VALUES (N'Engineering',N'Bangalore',5000000),(N'HR',N'Mumbai',2000000),(N'Finance',N'Delhi',3000000),(N'Marketing',N'Pune',1500000),(N'Operations',N'Chennai',2500000);
INSERT INTO dbo.employees (first_name,last_name,email,salary,age,status,dept_id,manager_id) VALUES
(N'Alice',N'Sharma',N'alice@co.com',95000,32,N'active',1,NULL),(N'Bob',N'Verma',N'bob@co.com',72000,35,N'active',1,1),
(N'Carol',N'Singh',N'carol@co.com',85000,28,N'active',1,1),(N'Dave',N'Kumar',N'dave@co.com',60000,40,N'inactive',2,NULL),
(N'Eve',N'Patel',N'eve@co.com',110000,30,N'active',3,NULL),(N'Frank',N'Gupta',N'frank@co.com',78000,38,N'active',2,4),
(N'Grace',N'Mehta',N'grace@co.com',92000,27,N'active',1,1),(N'Henry',N'Joshi',N'henry@co.com',55000,45,N'inactive',4,NULL),
(N'Ivy',N'Rao',N'ivy@co.com',88000,33,N'active',3,5),(N'Jack',N'Nair',N'jack@co.com',67000,29,N'active',4,8),
(N'Karen',N'Shah',N'karen@co.com',73000,31,N'active',NULL,NULL);
INSERT INTO dbo.projects VALUES (N'Apollo',800000,'2024-01-01','2024-06-30',1),(N'Beacon',500000,'2024-03-01',NULL,1),(N'Comet',300000,'2024-05-01','2024-09-30',3),(N'Delta',200000,'2024-07-01','2024-12-31',2),(N'Echo',150000,'2024-02-01','2024-04-30',4);
INSERT INTO dbo.emp_projects VALUES (1,1,N'lead',120),(2,1,N'member',80),(3,1,N'member',60),(1,2,N'lead',40),(3,2,N'senior',30),(7,2,N'member',20),(5,3,N'lead',100),(9,3,N'member',50),(4,4,N'member',30),(6,4,N'lead',60),(8,5,N'member',20),(10,5,N'lead',45);
INSERT INTO dbo.salary_grades VALUES ('A',0,49999,N'Entry'),('B',50000,74999,N'Mid'),('C',75000,99999,N'Senior'),('D',100000,999999,N'Executive');
GO

-- ── EASY (1–8) ────────────────────────────────────────────────────────────
-- E1: INNER JOIN
SELECT e.emp_id, e.first_name, e.salary, d.dept_name
FROM   dbo.employees e INNER JOIN dbo.departments d ON e.dept_id=d.dept_id ORDER BY d.dept_name;

-- E2: LEFT JOIN — all employees, NULL if no dept
SELECT e.first_name, ISNULL(d.dept_name,N'No Department') AS dept_name
FROM   dbo.employees e LEFT JOIN dbo.departments d ON e.dept_id=d.dept_id;

-- E3: LEFT JOIN IS NULL — employees with NO department (anti-join)
SELECT e.first_name FROM dbo.employees e
LEFT JOIN dbo.departments d ON e.dept_id=d.dept_id WHERE d.dept_id IS NULL;

-- E4: RIGHT JOIN — all departments, employee count
SELECT d.dept_name, COUNT(e.emp_id) AS headcount
FROM   dbo.employees e RIGHT JOIN dbo.departments d ON e.dept_id=d.dept_id
GROUP BY d.dept_id, d.dept_name ORDER BY headcount DESC;

-- E5: FULL OUTER JOIN — all employees + all departments
SELECT e.first_name, d.dept_name
FROM   dbo.employees e FULL OUTER JOIN dbo.departments d ON e.dept_id=d.dept_id
ORDER BY d.dept_name, e.first_name;

-- E6: CROSS JOIN — all employee × project combinations
SELECT TOP 15 e.first_name AS employee, p.project_name
FROM   dbo.employees e CROSS JOIN dbo.projects p ORDER BY e.first_name;

-- E7: Non-equi join — salary grade
SELECT e.first_name, e.salary, sg.grade, sg.label
FROM   dbo.employees e
JOIN   dbo.salary_grades sg ON e.salary BETWEEN sg.min_salary AND sg.max_salary
ORDER BY e.salary DESC;

-- E8: FULL OUTER JOIN — find unmatched on both sides
SELECT e.first_name, d.dept_name
FROM   dbo.employees e FULL OUTER JOIN dbo.departments d ON e.dept_id=d.dept_id
WHERE  e.dept_id IS NULL OR d.dept_id IS NULL;

-- ── MODERATE (1–6) ────────────────────────────────────────────────────────
-- M1: Self join — employee + manager
SELECT e.emp_id, e.first_name AS employee, e.salary,
       ISNULL(m.first_name,N'Top Level') AS manager, m.salary AS mgr_salary
FROM   dbo.employees e LEFT JOIN dbo.employees m ON e.manager_id=m.emp_id ORDER BY e.emp_id;

-- M2: Self join — higher earners than their manager
SELECT e.first_name AS employee, e.salary, m.first_name AS manager, m.salary AS mgr_sal
FROM   dbo.employees e JOIN dbo.employees m ON e.manager_id=m.emp_id WHERE e.salary>m.salary;

-- M3: 3-table join
SELECT e.first_name, d.dept_name, p.project_name, ep.role, ep.hours
FROM   dbo.employees e
JOIN   dbo.departments  d  ON e.dept_id=d.dept_id
JOIN   dbo.emp_projects ep ON e.emp_id=ep.emp_id
JOIN   dbo.projects     p  ON ep.project_id=p.project_id
WHERE  e.status=N'active' ORDER BY d.dept_name, e.first_name;

-- M4: LEFT JOIN — dept project count including 0
SELECT d.dept_name, COUNT(p.project_id) AS project_count, ISNULL(SUM(p.budget),0) AS total_budget
FROM   dbo.departments d LEFT JOIN dbo.projects p ON d.dept_id=p.dept_id
GROUP BY d.dept_id, d.dept_name ORDER BY project_count DESC;

-- M5: CROSS APPLY — top project per employee
SELECT e.first_name, top_p.project_name, top_p.budget
FROM   dbo.employees e
CROSS APPLY (
    SELECT TOP 1 p.project_name, p.budget
    FROM   dbo.projects p JOIN dbo.emp_projects ep ON p.project_id=ep.project_id
    WHERE  ep.emp_id=e.emp_id ORDER BY p.budget DESC
) AS top_p;

-- M6: OUTER APPLY — all employees, NULL if no project
SELECT e.first_name, ISNULL(top_p.project_name,N'No Projects') AS top_project
FROM   dbo.employees e
OUTER APPLY (
    SELECT TOP 1 project_name FROM dbo.projects p
    JOIN dbo.emp_projects ep ON p.project_id=ep.project_id
    WHERE ep.emp_id=e.emp_id ORDER BY p.budget DESC
) AS top_p;

-- ── HARD (1–5) ────────────────────────────────────────────────────────────
-- H1: Create indexes + check execution plan
CREATE INDEX idx_emp_dept   ON dbo.employees(dept_id);
CREATE INDEX idx_emp_status ON dbo.employees(status);
CREATE INDEX idx_ep_emp     ON dbo.emp_projects(emp_id);
GO
SET STATISTICS IO ON;
SELECT e.first_name, d.dept_name, COUNT(ep.project_id) AS proj_cnt
FROM   dbo.employees e
JOIN   dbo.departments  d  ON e.dept_id=d.dept_id
LEFT JOIN dbo.emp_projects ep ON e.emp_id=ep.emp_id
WHERE  e.status=N'active'
GROUP BY e.emp_id, e.first_name, d.dept_name ORDER BY proj_cnt DESC;

-- H2: CTE + JOIN — above dept average with salary grade
WITH dept_avg AS (SELECT dept_id, AVG(salary) AS avg_sal FROM dbo.employees WHERE status=N'active' GROUP BY dept_id)
SELECT e.first_name, e.salary, d.dept_name, ROUND(da.avg_sal,2) AS dept_avg,
       ROUND(e.salary-da.avg_sal,2) AS above_by, sg.grade
FROM   dbo.employees e
JOIN   dbo.departments   d  ON e.dept_id=d.dept_id
JOIN   dept_avg          da ON e.dept_id=da.dept_id
JOIN   dbo.salary_grades sg ON e.salary BETWEEN sg.min_salary AND sg.max_salary
WHERE  e.status=N'active' AND e.salary>da.avg_sal ORDER BY above_by DESC;

-- H3: Recursive CTE — org tree
WITH org AS (
    SELECT emp_id, first_name, manager_id, salary, 1 AS depth,
           CAST(first_name AS NVARCHAR(500)) AS path
    FROM   dbo.employees WHERE manager_id IS NULL AND status=N'active'
    UNION ALL
    SELECT e.emp_id, e.first_name, e.manager_id, e.salary, o.depth+1,
           CAST(o.path+N' > '+e.first_name AS NVARCHAR(500))
    FROM   dbo.employees e JOIN org o ON e.manager_id=o.emp_id WHERE e.status=N'active'
)
SELECT REPLICATE(N'  ',depth-1)+first_name AS org_chart, depth, salary, path
FROM   org ORDER BY path;

-- H4: ROLLUP on multi-table join
SELECT ISNULL(d.dept_name,N'ALL') AS dept,
       ISNULL(sg.grade,N'ALL')    AS grade,
       COUNT(e.emp_id)            AS headcount,
       AVG(e.salary)              AS avg_salary
FROM   dbo.employees e
JOIN   dbo.departments   d  ON e.dept_id=d.dept_id
JOIN   dbo.salary_grades sg ON e.salary BETWEEN sg.min_salary AND sg.max_salary
GROUP BY ROLLUP(d.dept_name, sg.grade) ORDER BY dept, grade;

-- H5: Non-equi + FULL OUTER — complete salary-grade report including empty grades
SELECT sg.grade, sg.label, COUNT(e.emp_id) AS employee_count,
       AVG(ep.hours) AS avg_proj_hours
FROM   dbo.salary_grades sg
LEFT JOIN dbo.employees e ON e.salary BETWEEN sg.min_salary AND sg.max_salary AND e.status=N'active'
LEFT JOIN dbo.emp_projects ep ON e.emp_id=ep.emp_id
GROUP BY sg.grade, sg.label ORDER BY sg.grade;

-- CLEANUP: USE master; DROP DATABASE day4_mssql;
