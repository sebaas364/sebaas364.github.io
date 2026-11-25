--Lista el nombre completo de todos los empleados, su puesto, el nombre de su departamento, la ciudad y el país donde trabaja, ordenado por país y luego por apellido.
SELECT
    e.first_name || ' ' || e.last_name AS nombre_completo,
    j.job_title,
    d.department_name,
    l.city,
    c.country_name
FROM HR.EMPLOYEES e
LEFT JOIN HR.JOBS j
    ON e.job_id = j.job_id
LEFT JOIN HR.DEPARTMENTS d
    ON e.department_id = d.department_id
LEFT JOIN HR.LOCATIONS l
    ON d.location_id = l.location_id
LEFT JOIN HR.COUNTRIES c
    ON l.country_id = c.country_id
ORDER BY 
    c.country_name,  
    e.last_name;
    
    

SELECT E.FIRST_NAME AS NOMBRE, 
    E.LAST_NAME AS APELLIDO,
    T.JOB_TITLE AS PUESTO,
    D.DEPARTMENT_NAME AS DEPARTAMENTO,
    C.CITY AS CIUDAD,
    P.COUNTRY_NAME AS PAIS
FROM HR.EMPLOYEES E
LEFT JOIN  HR.JOBS T
ON E.JOB_ID = T.JOB_ID
LEFT JOIN HR.DEPARTMENTS D
ON E.DEPARTMENT_ID = D.DEPARTMENT_ID
LEFT JOIN HR.LOCATIONS C
ON D.LOCATION_ID = C.LOCATION_ID
LEFT JOIN HR.COUNTRIES P
ON C.COUNTRY_ID = P.COUNTRY_ID
ORDER BY
    P.COUNTRY_NAME ASC,
    E.LAST_NAME ASC;
    
    
-- Lista los países que tienen empleados trabajando en más de una ciudad distinta.    
SELECT 
    c.country_name,
    COUNT(DISTINCT  l.city) AS cantidad_empleados
FROM HR.COUNTRIES c
INNER JOIN HR.LOCATIONS l
    ON l.country_id = c.country_id 
INNER JOIN HR.DEPARTMENTS d
    ON l.location_id = d.location_id
INNER JOIN HR.EMPLOYEES e
    ON e.department_id = d.department_id 
GROUP BY c.country_name
HAVING COUNT(DISTINCT l.city)>1;



SELECT 
    *
FROM HR.COUNTRIES c
INNER JOIN HR.LOCATIONS l
    ON l.country_id = c.country_id 
INNER JOIN HR.DEPARTMENTS d
    ON l.location_id = d.location_id
INNER JOIN HR.EMPLOYEES e
    ON e.department_id = d.department_id
WHERE c.country_name LIKE 'Ca%';



--Muestra los empleado que trabajan en un departamento cuyo manager directo, no es el el manager del departamento.
SELECT
   e.first_name,
   e.last_name,
   d.department_name
FROM HR.EMPLOYEES e
LEFT JOIN HR.DEPARTMENTS d
    ON e.department_id = d.department_id
WHERE d.manager_id != e.manager_id OR e.manager_id IS NULL OR d.manager_id IS NULL;

--Obtén el listado de departamentos que no tienen ningún empleado asignado
SELECT
    d.department_name
FROM HR.DEPARTMENTS d
LEFT OUTER JOIN HR.EMPLOYEES e
    ON d.department_id = e.department_id
WHERE e.employee_id IS NULL;


--Encuentra los empleados cuyo salario es superior al salario promedio de su propio departamento.
SELECT
   e.first_name,
   e.last_name,
   e.salary
FROM HR.EMPLOYEES e
INNER JOIN (SELECT
                d.department_id,
                AVG(e.salary) AS promedio_salario
            FROM HR.DEPARTMENTS d
            INNER JOIN HR.EMPLOYEES e
                ON e.department_id = d.department_id
            GROUP BY d.department_id) prom
    ON e.department_id = prom.department_id
WHERE e.salary > prom.promedio_salario;
            
            
/*            
SELECT
    d.department_id,
    AVG(e.salary) AS promedio_salario
FROM HR.DEPARTMENTS d
INNER JOIN HR.EMPLOYEES e
    ON e.department_id = d.department_id
GROUP BY d.department_id;
*/
SELECT
    *
FROM HR.DEPARTMENTS d
LEFT OUTER JOIN HR.EMPLOYEES e
    ON d.department_id = e.department_id
WHERE e.employee_id IS NULL;



--Taller repaso 
--6.1  Verificación de casos borde del esquema
SELECT
    'empleado sin jefe' AS caso_borde,
    count(*) AS empleados_afectados,
    'Un empleado sin jefe (probablemente dueño de la compañia)' AS descripcion
FROM HR.EMPLOYEES e
WHERE e.manager_id  IS NULL
UNION ALL
SELECT
    'empleado sin departamento' AS caso_borde,
    count(*) AS empleados_afectados,
    ' ' AS descripcion
FROM HR.EMPLOYEES e
WHERE e.department_id  IS NULL
UNION ALL
SELECT
    'empleados sin comisión' AS caso_borde,
    count(*) AS empleados_afectados,
    ' ' AS descripcion
FROM HR.EMPLOYEES e
WHERE e.commission_pct IS NULL
UNION ALL
SELECT
    ' departamentos sin empleados' AS caso_borde,
    count(*) AS empleados_afectados,
    'Departamentos sin empleados asignados ' AS descripcion
FROM HR.DEPARTMENTS d
LEFT JOIN HR.EMPLOYEES e
ON e.department_id = d.department_id
WHERE e.employee_id IS NULL;


--6.2 Inventario completo de departamentos
SELECT
    d.department_id, 
    d.department_name,
    l.city,
    c.country_name,
    COUNT(e.employee_id) AS employee_count,
    NVL(AVG(e.salary),0) AS avg_salary
FROM HR.DEPARTMENTS d
LEFT JOIN HR.EMPLOYEES e
    ON e.department_id = d.department_id
INNER JOIN HR.LOCATIONS l
    ON d.location_id = l.location_id
INNER JOIN HR.COUNTRIES c
    ON l.country_id = c.country_id
GROUP BY d.department_id, d.department_name, l.city, c.country_name ;
    
    
-- 6.3 Cadena de mando
SELECT 
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    j.job_title,
    e.manager_id,
    m.first_name || ' ' || m.last_name AS manager_name,
    d.department_name
FROM HR.employees e
INNER JOIN HR.jobs j ON e.job_id = j.job_id
LEFT JOIN HR.employees m ON m.employee_id = e.manager_id
LEFT JOIN HR.departments d ON d.department_id = e.department_id
ORDER BY e.employee_id; 

--6.4 Contraste entre la condición en ON y la condición en WHERE

-- Filtrando con "ON"Resultado 36
SELECT COUNT(*)
FROM   departments d
LEFT JOIN employees e
       ON e.department_id = d.department_id
      AND e.salary > 10000;

-- Filtrando con "WHERE" Resultado 15
SELECT COUNT(*)
FROM departments d
LEFT JOIN employees e
       ON e.department_id = d.department_id
WHERE  e.salary > 10000;

-- 6.6 Agregación con filtrado de grupos
SELECT 
    d.department_id,
    d.department_name,
    COUNT(*) AS employee_count,
    ROUND(AVG(e.salary), 2) AS avg_salary,
    MIN(e.salary) AS min_salary,
    MAX(e.salary) AS max_salary,
    SUM(e.salary) AS salary_mass,
    COUNT(CASE WHEN e.hire_date > DATE '2005-01-01' THEN 1 END) AS empleados_recientes
FROM   HR.employees e
JOIN   HR.departments d ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name
HAVING COUNT(*) > 5 AND AVG(e.salary) > 6000
ORDER BY d.department_id;

