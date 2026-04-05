# SQL Day 4 — Joins Basics · MS-SQL Server 2022

> **Dialect:** Microsoft SQL Server 2022 (16.x) · T-SQL · Default schema: `dbo`

---

## Topic 1 — Joins: Definition & Types

### Theory
- All four join types natively supported including `FULL OUTER JOIN`
- `USING` clause NOT supported — always use `ON`
- `NATURAL JOIN` NOT supported — always specify columns explicitly
- Old implicit join syntax (`FROM t1, t2 WHERE t1.col=t2.col`) works but use explicit JOINs
- Join hints available: `INNER HASH JOIN`, `INNER LOOP JOIN`, `INNER MERGE JOIN`

### Syntax
```sql
-- INNER JOIN
SELECT e.first_name, d.dept_name
FROM   dbo.employees e
INNER JOIN dbo.departments d ON e.dept_id = d.dept_id;

-- LEFT OUTER JOIN
SELECT e.first_name, ISNULL(d.dept_name, N'No Dept') AS dept
FROM   dbo.employees e
LEFT OUTER JOIN dbo.departments d ON e.dept_id = d.dept_id;

-- RIGHT OUTER JOIN
SELECT e.first_name, d.dept_name
FROM   dbo.employees e
RIGHT OUTER JOIN dbo.departments d ON e.dept_id = d.dept_id;

-- FULL OUTER JOIN (native — MS-SQL supports it!)
SELECT e.first_name, d.dept_name
FROM   dbo.employees e
FULL OUTER JOIN dbo.departments d ON e.dept_id = d.dept_id;

-- Anti-join: employees with NO department
SELECT e.first_name FROM dbo.employees e
LEFT JOIN dbo.departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

-- Find unmatched rows from BOTH tables
SELECT e.first_name, d.dept_name
FROM   dbo.employees e
FULL OUTER JOIN dbo.departments d ON e.dept_id = d.dept_id
WHERE  e.dept_id IS NULL OR d.dept_id IS NULL;
```

---

## Topic 2 — Cross Join (Cartesian Product)

### Theory
- No ON clause — returns m × n rows
- MS-SQL supports `CROSS APPLY` and `OUTER APPLY` which are correlated cross joins

### Syntax
```sql
-- Explicit CROSS JOIN
SELECT e.first_name, p.project_name
FROM   dbo.employees e CROSS JOIN dbo.projects p;

-- Generate numbers using CROSS JOIN
WITH digits AS (
    SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
)
SELECT a.n * 10 + b.n AS num
FROM   digits a CROSS JOIN digits b ORDER BY num;

-- CROSS APPLY: correlated table in FROM (unique MS-SQL feature)
SELECT e.first_name, top_p.project_name
FROM   dbo.employees e
CROSS APPLY (
    SELECT TOP 1 project_name
    FROM   dbo.projects p JOIN dbo.emp_projects ep ON p.project_id=ep.project_id
    WHERE  ep.emp_id = e.emp_id ORDER BY p.budget DESC
) AS top_p;

-- OUTER APPLY: like LEFT JOIN version of CROSS APPLY
SELECT e.first_name, top_p.project_name
FROM   dbo.employees e
OUTER APPLY (
    SELECT TOP 1 project_name FROM dbo.projects p
    JOIN dbo.emp_projects ep ON p.project_id=ep.project_id
    WHERE ep.emp_id=e.emp_id ORDER BY p.budget DESC
) AS top_p;
```

---

## Topic 3 — Self Join (Same Table)

### Theory
- Two aliases for the same table
- `LEFT JOIN` for optional parent (NULLable manager_id)
- Use `a.id < b.id` in WHERE to avoid duplicate pairs in same-table comparisons
- Recursive CTE preferred for deep unlimited hierarchies

### Syntax
```sql
-- Employee + manager name
SELECT e.first_name AS employee, ISNULL(m.first_name, N'Top Level') AS manager
FROM   dbo.employees e
LEFT JOIN dbo.employees m ON e.manager_id = m.emp_id;

-- Same-department pairs
SELECT a.first_name AS emp1, b.first_name AS emp2, d.dept_name
FROM   dbo.employees a
JOIN   dbo.employees b ON a.dept_id = b.dept_id AND a.emp_id < b.emp_id
JOIN   dbo.departments d ON a.dept_id = d.dept_id;

-- Recursive CTE: full org hierarchy
WITH org AS (
    SELECT emp_id, first_name, manager_id, 1 AS depth,
           CAST(first_name AS NVARCHAR(500)) AS path
    FROM   dbo.employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.first_name, e.manager_id, o.depth+1,
           CAST(o.path + N' > ' + e.first_name AS NVARCHAR(500))
    FROM   dbo.employees e JOIN org o ON e.manager_id = o.emp_id
)
SELECT REPLICATE(N'  ', depth-1) + first_name AS org_tree, depth, path
FROM   org ORDER BY path;
```

---

## Topic 4 — Equi Join (Matching Keys)

### Theory
- ON clause using `=` operator
- MS-SQL does NOT support `USING` or `NATURAL JOIN` — always use `ON`
- Check for implicit conversions in ON clause — can kill index use

### Syntax
```sql
-- Standard equi join (always use ON in MS-SQL)
SELECT e.first_name, d.dept_name
FROM   dbo.employees e JOIN dbo.departments d ON e.dept_id = d.dept_id;

-- Multi-table equi join
SELECT e.first_name, d.dept_name, p.project_name, ep.role
FROM   dbo.employees e
JOIN   dbo.departments  d  ON e.dept_id     = d.dept_id
JOIN   dbo.emp_projects ep ON e.emp_id      = ep.emp_id
JOIN   dbo.projects     p  ON ep.project_id = p.project_id
WHERE  e.status = N'active'
ORDER BY d.dept_name, e.first_name;

-- Multi-column equi join
SELECT * FROM dbo.orders o
JOIN dbo.order_items i ON o.order_id = i.order_id AND o.version = i.version;

-- ❌ Implicit conversion kills index:
-- ON e.dept_id = '1'   (int vs varchar → convert → no index)
-- ✅ Always match data types:
-- ON e.dept_id = 1
```

---

## Topic 5 — Non-Equi Join (Range Condition)

### Theory
- ON uses `<`, `>`, `<=`, `>=`, `BETWEEN`, `<>` instead of `=`
- Date overlap: `ON t1.start_date <= t2.end_date AND t1.end_date >= t2.start_date`
- Check execution plan — usually nested loop or hash join

### Syntax
```sql
-- Salary grade assignment
SELECT e.first_name, e.salary, sg.grade, sg.label
FROM   dbo.employees e
JOIN   dbo.salary_grades sg ON e.salary BETWEEN sg.min_salary AND sg.max_salary;

-- Date range overlap
SELECT o.order_id, p.promo_name
FROM   dbo.orders o
JOIN   dbo.promotions p
       ON o.order_date >= p.start_date AND o.order_date <= p.end_date;

-- Find all employees earning less than a specific role
SELECT e.first_name AS employee, lead.first_name AS higher_earner
FROM   dbo.employees e
JOIN   dbo.employees lead ON e.dept_id = lead.dept_id AND e.salary < lead.salary
WHERE  lead.role = N'lead';
```

---

## Topic 6 — Join Optimization

### Key Techniques

```sql
-- 1. Index join columns
CREATE INDEX idx_emp_dept ON dbo.employees(dept_id);
CREATE INDEX idx_ep_emp   ON dbo.emp_projects(emp_id);

-- 2. Covering index (include SELECT columns — avoids key lookup)
CREATE INDEX idx_emp_cover ON dbo.employees(dept_id, status)
  INCLUDE (first_name, salary);

-- 3. Statistics IO + execution plan
SET STATISTICS IO ON;
-- In SSMS: Ctrl+M = Include Actual Execution Plan

-- 4. Join hints
SELECT e.first_name, d.dept_name
FROM   dbo.employees e INNER HASH JOIN dbo.departments d ON e.dept_id=d.dept_id;
-- INNER LOOP JOIN  = nested loop
-- INNER MERGE JOIN = sort-merge
-- INNER HASH JOIN  = hash join

-- 5. Avoid implicit conversion
-- ❌ ON e.dept_id = '1'  → CONVERT kills index!
-- ✅ ON e.dept_id = 1    → uses index

-- 6. NOLOCK hint (dirty reads — use carefully)
SELECT * FROM dbo.employees WITH (NOLOCK) JOIN dbo.departments WITH (NOLOCK)
ON employees.dept_id = departments.dept_id;
```

---

## MS-SQL 2022 Joins Quick Reference

| Feature | Syntax |
|---|---|
| INNER JOIN | `FROM t1 JOIN t2 ON t1.id = t2.fk` |
| LEFT JOIN | `FROM t1 LEFT OUTER JOIN t2 ON ...` |
| FULL OUTER JOIN | ✅ Native: `FROM t1 FULL OUTER JOIN t2 ON ...` |
| CROSS JOIN | `FROM t1 CROSS JOIN t2` |
| CROSS APPLY | `FROM t1 CROSS APPLY (SELECT TOP 1 ... WHERE ...) alias` |
| OUTER APPLY | `FROM t1 OUTER APPLY (SELECT TOP 1 ... WHERE ...) alias` |
| USING clause | ❌ Not supported — always use ON |
| NATURAL JOIN | ❌ Not supported |
| Self Join | `FROM employees e JOIN employees m ON e.mgr_id=m.id` |
| Non-Equi Join | `ON e.salary BETWEEN sg.min AND sg.max` |
| Anti-join | `LEFT JOIN t2 ON ... WHERE t2.id IS NULL` |
| Hash Join hint | `INNER HASH JOIN` |
| Loop Join hint | `INNER LOOP JOIN` |
| Merge Join hint | `INNER MERGE JOIN` |
| Covering index | `CREATE INDEX idx ON t(join_col) INCLUDE (sel_cols)` |
| Statistics IO | `SET STATISTICS IO ON` |
| NOLOCK hint | `FROM t WITH (NOLOCK)` |
