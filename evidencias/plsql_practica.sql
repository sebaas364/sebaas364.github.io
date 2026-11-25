SET SERVEROUTPUT ON;

-- EJERCICIO 1
--Crea un bloque anónimo de PL/SQL con un cursor explicito que traiga los empleados del departamento 80 
--y muestre su nombre completo, cargo y salario.y lo clasifique comparando su salario con el 
--promedio del departamento: "ALTO" si gana más del 120% del promedio, "MEDIO" si está entre el 80% y el 120%, y "BAJO" si gana menos del 80%.
--Además presenta un resumen con la cantidad de empleados por categoría.

DECLARE
  CURSOR cur_empleados_depto80 IS 
    SELECT 
        e.first_name || ' ' || e.last_name AS nombre,
        j.job_title,
        e.salary
    FROM   employees e
    JOIN   jobs j ON j.job_id = e.job_id
    WHERE  e.department_id = 80
    ORDER  BY e.salary DESC;

  v_emp        cur_empleados_depto80%ROWTYPE;
  vn_promedio  NUMBER;
  vv_categoria VARCHAR2(10);
  vn_altos     NUMBER := 0;
  vn_medios    NUMBER := 0;
  vn_bajos     NUMBER := 0;
BEGIN
  
  SELECT AVG(salary) INTO vn_promedio
  FROM   employees
  WHERE  department_id = 80;

  DBMS_OUTPUT.PUT_LINE('Salario promedio: ' || ROUND(vn_promedio, 2));

  OPEN cur_empleados_depto80;
  LOOP
    FETCH cur_empleados_depto80 INTO v_emp;
    EXIT WHEN cur_empleados_depto80%NOTFOUND;

    IF v_emp.salary > vn_promedio * 1.2 THEN
      vv_categoria := 'ALTO';
      vn_altos := vn_altos + 1;
    ELSIF v_emp.salary >= vn_promedio * 0.8 THEN
      vv_categoria := 'MEDIO';
      vn_medios := vn_medios + 1;
    ELSE
      vv_categoria := 'BAJO';
      vn_bajos := vn_bajos + 1;
    END IF;

    DBMS_OUTPUT.PUT_LINE( RPAD(v_emp.nombre, 22) || RPAD(v_emp.job_title, 18) || 
    LPAD(v_emp.salary, 7) || '  ' || vv_categoria);
  END LOOP;
  CLOSE cur_empleados_depto80;

  DBMS_OUTPUT.PUT_LINE('ALTO: ' || vn_altos || ' | MEDIO: ' || vn_medios || ' | BAJO: ' || vn_bajos);
END;
/

-- EJERCICIO 2
--Crea un procedimiento sp_subir_salario con parametros p_emp_id, p_porcentaje 
--que aumente el salario de un empleado según el porcentaje indicado. 
--Debe validar los datos de entrada, respetar el tope del puesto.
CREATE OR REPLACE PROCEDURE sp_subir_salario (
    p_emp_id     IN employees.employee_id%TYPE,
    p_porcentaje IN NUMBER
) IS
    vn_salario_actual employees.salary%TYPE;
    vn_max_salary     jobs.max_salary%TYPE;
    vn_nuevo_salario  NUMBER;
BEGIN
    IF p_porcentaje IS NULL OR p_porcentaje <= 0 OR p_porcentaje >= 100 THEN
        RAISE_APPLICATION_ERROR(-20001, 'El porcentaje debe ser mayor a 0 y menor a 100%');
    END IF;

    SELECT e.salary, j.max_salary
    INTO   vn_salario_actual, vn_max_salary
    FROM   employees e
    JOIN   jobs j ON j.job_id = e.job_id
    WHERE  e.employee_id = p_emp_id;

    vn_nuevo_salario := ROUND(vn_salario_actual * (1 + p_porcentaje / 100), 2);

    IF vn_nuevo_salario > vn_max_salary THEN
        DBMS_OUTPUT.PUT_LINE('El aumento supera el máximo del puesto, se ajusta al máximo: ' || vn_max_salary);
        vn_nuevo_salario := vn_max_salary;
    END IF;

    UPDATE employees
    SET    salary = vn_nuevo_salario
    WHERE  employee_id = p_emp_id;

    DBMS_OUTPUT.PUT_LINE('Empleado ' || p_emp_id || ': ' || vn_salario_actual || ' -> ' || vn_nuevo_salario);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'El empleado ' || p_emp_id || ' no existe.');
END sp_subir_salario;
/

-- EJERCICIO 3
--Crea una función fn_costo_empleado que reciba un employee_id y 
--devuelva la ganancia anual del empleado, es decir, 
--su salario por 12 más la comisión (si tiene), más un 10% adicional si lleva más de 15 años en la empresa. 
--Si el empleado no existe, debe devolver NULL en lugar de lanzar un error.

CREATE OR REPLACE FUNCTION fn_costo_empleado(p_employee_id EMPLOYEES.employee_id%TYPE)
RETURN NUMBER
IS
vn_salario    employees.salary%TYPE;
  vn_comision   employees.commission_pct%TYPE;
  vd_fecha      employees.hire_date%TYPE;
  vn_antiguedad NUMBER;
  vn_costo      NUMBER;
BEGIN
  SELECT salary, NVL(commission_pct, 0), hire_date
  INTO   vn_salario, vn_comision, vd_fecha
  FROM   employees
  WHERE  employee_id = p_employee_id;

  vn_antiguedad := MONTHS_BETWEEN(SYSDATE, vd_fecha) / 12;

  vn_costo := vn_salario * 12 * (1 + vn_comision);

  IF vn_antiguedad > 15 THEN
    vn_costo := vn_costo * 1.10;
  END IF;

  RETURN ROUND(vn_costo, 2);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/


SELECT employee_id,
       first_name || ' ' || last_name AS nombre,
       salary,
       commission_pct,
       fn_costo_empleado(employee_id) AS costo_anual
FROM   employees
WHERE  department_id = 80


-- EJERCICIO 4
--Crea una tabla auditoria_salarios (con id, employee_id,
--usuario, fecha, salario_anterior, salario_nuevo y tipo de cambio) y un trigger
--trg_audit_salario que, cada vez que se actualice el salario de un empleado, registre el cambio ahí.
--Además, el trigger debe impedir que el salario baje: si el nuevo salario es menor al anterior, 
--debe cancelar la operación con un error personalizado. Si el aumento supera el 20%, el tipo de cambio debe quedar como 
--'AUMENTO GRANDE', y de lo contrario como 'AUMENTO NORMAL'.

CREATE TABLE auditoria_salarios (
  id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id      NUMBER(6)     NOT NULL,
  usuario          VARCHAR2(30)  NOT NULL,
  fecha            DATE          DEFAULT SYSDATE NOT NULL,
  salario_anterior NUMBER(8,2),
  salario_nuevo    NUMBER(8,2),
  tipo_cambio      VARCHAR2(20)
);

CREATE OR REPLACE TRIGGER trg_audit_salario
BEFORE UPDATE OF salary ON employees FOR EACH ROW
DECLARE
  vv_tipo auditoria_salarios.tipo_cambio%TYPE;
BEGIN
    IF :NEW.salary < :OLD.salary THEN
        RAISE_APPLICATION_ERROR(-20010,'No se permite bajar el salario del empleado ');
    END IF;

    IF :NEW.salary > :OLD.salary * 1.20 THEN
        vv_tipo := 'AUMENTO GRANDE';
    ELSE
        vv_tipo := 'AUMENTO NORMAL';
    END IF;

    INSERT INTO auditoria_salarios (employee_id, usuario, fecha, salario_anterior, salario_nuevo, tipo_cambio)
    VALUES (:OLD.employee_id, USER, SYSDATE, :OLD.salary, :NEW.salary, vv_tipo);
END;
/