--------------------------------------------------------------------------------
-- UNIVERSIDAD EL BOSQUE — INGENIERIA DE SISTEMAS
-- Asignatura: Bases de Datos 2
-- Docente: Ing., Esp., M.Ed. Christian Felipe Duarte
--
-- TALLER PL/SQL — PLANTILLA DE ENTREGA
--
-- GRUPO No.: 2
-- INTEGRANTES: 1) Sebastián Pérez Herrera 
--              2) Jhonatan Camilo Lozano Buitrago
--              3) Einny Camyla Poveda Garcia
-- FECHA DE ENTREGA: 03/10/2026
--------------------------------------------------------------------------------
--
-- COMO TRABAJAR
--   1. Ejecute primero, completo, el script 01_esquema_inventario.sql
--   2. Desarrolle cada punto en la seccion correspondiente de este archivo
--   3. No borre los encabezados de cada ejercicio ni cambie los nombres de los
--      objetos solicitados. La revision los busca por nombre: un objeto correcto
--      con otro nombre se califica como no entregado.
--   4. Los esqueletos de la Parte 5 no incluyen la clausula de disparo. Definirla
--      hace parte del ejercicio, de modo que esos bloques no compilan tal como se
--      entregan.
--
-- DISTRIBUCION DEL PUNTAJE                                     Total: 50 puntos
--   Parte 1  Procedimientos almacenados .................  8 puntos
--   Parte 2  Funciones ...................................  8 puntos
--   Parte 3  Cursores .................................... 10 puntos
--   Parte 4  Manejo de excepciones .......................  9 puntos
--   Parte 5  Disparadores ................................ 10 puntos
--   Parte 6  Caso integrador .............................  5 puntos
--
-- CRITERIOS DE EVALUACION
--   Correccion tecnica ....... 40%   El objeto compila y cumple el enunciado
--   Justificacion ............ 40%   Las decisiones de diseno estan argumentadas
--   Analisis operacional ..... 20%   Se anticipa el comportamiento ante
--                                    concurrencia, volumen y error
--
--   Cada objeto debe incluir su justificacion en el espacio marcado. Un ejercicio
--   sin justificacion obtiene como maximo el 40% de su puntaje aunque funcione.
--   Una justificacion que confunde la causa con el efecto no obtiene puntaje.
--   Describir lo que hace el codigo, sin argumentar por que se eligio esa
--   construccion y no otra, equivale a no justificar.
--
-- ENTREGA
--   Este archivo renombrado como TALLER_PLSQL_GRUPO_<n>.sql, junto con un
--   documento que contenga las salidas de DBMS_OUTPUT de cada bloque ejecutado.
--   Ambos archivos deben incluir los nombres de los tres integrantes.
--
-- SUSTENTACION
--   20 minutos por grupo. Los tres integrantes deben poder explicar cualquier
--   parte del codigo, no solamente la que desarrollaron.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON SIZE UNLIMITED

--==============================================================================
-- PARTE 1 — PROCEDIMIENTOS ALMACENADOS                        (8 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 1.1 (2 pts)
-- SP_REGISTRAR_PRODUCTO
-- Registra un producto nuevo. Debe asignar el identificador desde SEQ_PRODUCTO,
-- validar que el precio de venta supere el costo unitario, verificar que la
-- categoria exista y manejar el caso de codigo duplicado. Devuelve el
-- identificador generado.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
Las validaciones se hacen antes de pedir el valor a SEQ_PRODUCTO.NEXTVAL,
porque una secuencia no se revierte y cada rechazo gastaria un numero. El
codigo duplicado no se detecta con un SELECT previo, ya que otra sesion
podria insertarlo entre el SELECT y el INSERT; en su lugar se deja que
decida el indice unico y se captura DUP_VAL_ON_INDEX. El codigo se
normaliza con UPPER y TRIM, p_id_producto queda en NULL hasta que el INSERT
tiene exito, y no se hace COMMIT para que lo decida quien llama.

*/
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_PRODUCTO (
    p_codigo        IN  VARCHAR2,
    p_nombre        IN  VARCHAR2,
    p_id_categoria  IN  NUMBER,
    p_precio        IN  NUMBER,
    p_costo         IN  NUMBER,
    p_stock_minimo  IN  NUMBER DEFAULT 0,
    p_id_producto   OUT NUMBER
) IS

    vv_codigo  VARCHAR2(200) := UPPER(TRIM(p_codigo));
    v_id      PRODUCTO.id_producto%TYPE;
    vn_existe  NUMBER;

BEGIN
    p_id_producto := NULL;
 
    IF vv_codigo IS NULL OR TRIM(p_nombre) IS NULL OR p_id_categoria IS NULL
       OR p_precio IS NULL OR p_costo IS NULL OR NVL(p_stock_minimo, 0) < 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Datos obligatorios ausentes o stock minimo negativo');
    END IF;
 
    IF LENGTH(vv_codigo) > 20 THEN
        RAISE_APPLICATION_ERROR(-20001, 'El codigo excede los 20 caracteres permitidos');
    END IF;
 
    IF p_costo <= 0 OR p_precio <= p_costo THEN
        RAISE_APPLICATION_ERROR(-20001,
            'El precio de venta (' || p_precio || ') debe superar el costo unitario ('
            || p_costo || ')');
    END IF;
 
    SELECT COUNT(*) INTO vn_existe
    FROM   CATEGORIA
    WHERE  id_categoria = p_id_categoria;
 
    IF vn_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'La categoria ' || p_id_categoria || ' no existe');
    END IF;

    v_id := SEQ_PRODUCTO.NEXTVAL;
 
    INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria,
                          precio_unitario, costo_unitario, stock_minimo, activo)
    VALUES (v_id, vv_codigo, TRIM(p_nombre), p_id_categoria,
            p_precio, p_costo, NVL(p_stock_minimo, 0), 'S');
 
        p_id_producto := v_id;
    EXCEPTION

    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Ya existe un producto con el codigo ' || vv_codigo);
END SP_REGISTRAR_PRODUCTO;
/

------------------------------------------------------------------- 1.2 (3 pts)
-- SP_AJUSTAR_STOCK
-- Registra una ENTRADA, SALIDA o AJUSTE de inventario sobre una bodega.
-- Debe actualizar EXISTENCIA e insertar el registro en MOVIMIENTO_INVENTARIO,
-- devolviendo el saldo resultante.
--   * Si la combinacion bodega-producto no existe y el tipo es ENTRADA, crearla
--   * Si el tipo es SALIDA y no existe la combinacion, rechazar la operacion
--   * Una SALIDA nunca puede dejar la existencia en negativo
-- Proteja la lectura de la existencia frente a modificaciones concurrentes.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*

La fila de EXISTENCIA se lee con FOR UPDATE antes de decidir, porque sin el
bloqueo dos SALIDA de 8 unidades sobre un saldo de 10 pasarian ambas la
validacion y una pisaria a la otra; WAIT 10 evita esperar sin limite. Si la
combinacion no existe y el movimiento es ENTRADA se hace el INSERT, y si
otra sesion la creo mientras tanto se relee con bloqueoy se suma, ya 
que un bloqueo no puede proteger una fila que aun no existe. Que una SALIDA 
no deje la existencia en negativo se valida en el procedimiento con un 
mensaje propio y ademas lo respalda el CHECK de la tabla.

*/

CREATE OR REPLACE PROCEDURE SP_AJUSTAR_STOCK (
    p_id_producto  IN  NUMBER,
    p_id_bodega    IN  NUMBER,
    p_tipo         IN  VARCHAR2,
    p_cantidad     IN  NUMBER,
    p_observacion  IN  VARCHAR2 DEFAULT NULL,
    p_saldo_final  OUT NUMBER
) IS

    vv_tipo    VARCHAR2(30) := UPPER(TRIM(p_tipo));
    vn_actual  EXISTENCIA.cantidad%TYPE;
    vn_nuevo   EXISTENCIA.cantidad%TYPE;
    vc_activa  BODEGA.activa%TYPE;
    vn_existe  NUMBER;
    vb_hay_fila BOOLEAN := TRUE;
    vv_obs     MOVIMIENTO_INVENTARIO.observacion%TYPE;
 
BEGIN
    p_saldo_final := NULL;
 
    IF vv_tipo IS NULL OR vv_tipo NOT IN ('ENTRADA', 'SALIDA', 'AJUSTE') THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Tipo de movimiento invalido: ' || NVL(p_tipo, 'NULL')
            || ' (use ENTRADA, SALIDA o AJUSTE)');
    END IF;
 
    IF p_cantidad IS NULL OR p_cantidad <= 0 OR p_cantidad <> TRUNC(p_cantidad) THEN
        RAISE_APPLICATION_ERROR(-20005, 'La cantidad debe ser un entero positivo');
    END IF;
 
    SELECT COUNT(*) INTO vn_existe FROM PRODUCTO WHERE id_producto = p_id_producto;
    IF vn_existe = 0 THEN
        RAISE_APPLICATION_ERROR(-20006, 'El producto ' || p_id_producto || ' no existe');
    END IF;
 
    SELECT MAX(activa) INTO vc_activa FROM BODEGA WHERE id_bodega = p_id_bodega;
    IF vc_activa IS NULL THEN
        RAISE_APPLICATION_ERROR(-20006, 'La bodega ' || p_id_bodega || ' no existe');
    END IF;
 
    IF vv_tipo = 'ENTRADA' AND vc_activa = 'N' THEN
        RAISE_APPLICATION_ERROR(-20007,
            'La bodega ' || p_id_bodega || ' esta inactiva y no admite entradas');
    END IF;
 
 
    BEGIN
        SELECT cantidad
        INTO   vn_actual
        FROM   EXISTENCIA
        WHERE  id_bodega = p_id_bodega
        AND    id_producto = p_id_producto
        FOR UPDATE WAIT 10;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            vb_hay_fila := FALSE;
    END;
 
    IF NOT vb_hay_fila THEN
        IF vv_tipo <> 'ENTRADA' THEN
            RAISE_APPLICATION_ERROR(-20008,
                'No existe la combinacion bodega ' || p_id_bodega || ' - producto '
                || p_id_producto || '; solo una ENTRADA puede crearla');
        END IF;
        vn_actual := 0;
        vn_nuevo  := p_cantidad;
        BEGIN
            INSERT INTO EXISTENCIA (id_bodega, id_producto, cantidad)
            VALUES (p_id_bodega, p_id_producto, vn_nuevo);
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                SELECT cantidad INTO vn_actual
                FROM   EXISTENCIA
                WHERE  id_bodega = p_id_bodega AND id_producto = p_id_producto
                FOR UPDATE WAIT 10;
                vn_nuevo := vn_actual + p_cantidad;
                UPDATE EXISTENCIA SET cantidad = vn_nuevo
                WHERE  id_bodega = p_id_bodega AND id_producto = p_id_producto;
        END;
    ELSE
        IF vv_tipo = 'ENTRADA' THEN
            vn_nuevo := vn_actual + p_cantidad;
        ELSIF vv_tipo = 'SALIDA' THEN
            IF vn_actual < p_cantidad THEN
                RAISE_APPLICATION_ERROR(-20009,
                    'Stock insuficiente: saldo ' || vn_actual || ', solicitado '
                    || p_cantidad);
            END IF;
            vn_nuevo := vn_actual - p_cantidad;
        ELSE -- AJUSTE: conteo fisico
            vn_nuevo := p_cantidad;
        END IF;
 
        UPDATE EXISTENCIA SET cantidad = vn_nuevo
        WHERE  id_bodega = p_id_bodega AND id_producto = p_id_producto;
    END IF;
 
    IF vv_tipo = 'AJUSTE' THEN
        vv_obs := SUBSTR(NVL(p_observacion, 'Ajuste por conteo fisico')
                 || ' (saldo anterior ' || vn_actual || ' -> nuevo ' || vn_nuevo || ')', 1, 200);
    ELSE
        vv_obs := SUBSTR(p_observacion, 1, 200);
    END IF;
 
    INSERT INTO MOVIMIENTO_INVENTARIO (id_movimiento, id_producto, id_bodega, tipo,
                                       cantidad, observacion)
    VALUES (SEQ_MOVIMIENTO.NEXTVAL, p_id_producto, p_id_bodega, vv_tipo,
            p_cantidad, vv_obs);
 
    p_saldo_final := vn_nuevo;

END SP_AJUSTAR_STOCK;
/

------------------------------------------------------------------- 1.3 (3 pts)
-- SP_CREAR_PEDIDO
-- Crea la cabecera de un pedido en estado BORRADOR y devuelve el identificador
-- generado. Debe rechazar clientes inactivos y clientes sin cupo de credito
-- disponible, con mensajes distinguibles entre si.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
Se valida primero que el cliente exista, luego que este activo y por ultimo
el cupo; si el cupo se evaluara antes, un cliente inactivo apareceria como
sin cupo y los mensajes dejarian de ser distinguibles Cada rechazo imprime su propio
mensaje (CLIENTE NO EXISTE, CLIENTE INACTIVO o SIN CUPO) y deja p_id_pedido
en NULL, de modo que el pedido solo se inserta en el ELSE, cuando ninguna
validacion fallo; no se usa RAISE ni ningun codigo de error numerico. Quien
llama debe revisar que p_id_pedido no sea NULL antes de usarlo. El cupo se
calcula en el propio procedimiento como cupo menos saldo y no con
FN_CUPO_DISPONIBLE, porque esa funcion se crea mas adelante en el archivo,
y el identificador se obtiene con INSERT ... RETURNING.
*/

CREATE OR REPLACE PROCEDURE SP_CREAR_PEDIDO (
    p_id_cliente  IN  NUMBER,
    p_id_pedido   OUT NUMBER
) IS
    vc_activo  CLIENTE.activo%TYPE;
    vn_cupo    NUMBER;

BEGIN
    p_id_pedido := NULL;
 
    SELECT MAX(activo), MAX(cupo_credito - saldo_pendiente)
    INTO   vc_activo, vn_cupo
    FROM   CLIENTE
    WHERE  id_cliente = p_id_cliente;
 
   IF vc_activo IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('CLIENTE NO EXISTE: el cliente ' || p_id_cliente
                             || ' no existe');
    ELSIF vc_activo <> 'S' THEN
        DBMS_OUTPUT.PUT_LINE('CLIENTE INACTIVO: el cliente ' || p_id_cliente
                             || ' esta inactivo y no puede realizar pedidos');
    ELSIF vn_cupo <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('SIN CUPO: el cliente ' || p_id_cliente
                             || ' no tiene cupo de credito disponible');
    ELSE
        INSERT INTO PEDIDO (id_pedido, id_cliente, fecha_pedido, estado, total)
        VALUES (SEQ_PEDIDO.NEXTVAL, p_id_cliente, SYSDATE, 'BORRADOR', 0)
        RETURNING id_pedido INTO p_id_pedido;
    END IF;

END SP_CREAR_PEDIDO;
/


--==============================================================================
-- PARTE 2 — FUNCIONES                                         (8 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 2.1 (2 pts)
-- FN_STOCK_DISPONIBLE
-- Retorna la cantidad disponible de un producto. Si se indica bodega, devuelve
-- el saldo de esa bodega; si p_id_bodega llega nulo, el consolidado de todas.
-- Un producto inexistente debe retornar cero y no una excepcion.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se uso SUM con NVL en lugar de un SELECT normal, ya que si el producto no existe,
-- un SELECT normal daria el error NO_DATA_FOUND y el ejercicio pide que
-- devuelva 0, no error,entonces como SUM siempre devuelve una fila  junto al NVL cambia
-- ese NULL por 0 y no nos daria el error.
-- Ademas se hacen dos consultas (IF / ELSE) en vez de una sola porque asi cada
-- caso busca de la forma mas directa y rapida.

CREATE OR REPLACE FUNCTION FN_STOCK_DISPONIBLE (
    p_id_producto IN NUMBER,
    p_id_bodega   IN NUMBER DEFAULT NULL
) RETURN NUMBER IS
    vn_stock NUMBER;
BEGIN
    IF p_id_bodega IS NULL THEN
        SELECT NVL(SUM(cantidad), 0) INTO vn_stock
        FROM   EXISTENCIA
        WHERE  id_producto = p_id_producto;
    ELSE
        SELECT NVL(SUM(cantidad), 0) INTO vn_stock
        FROM   EXISTENCIA
        WHERE  id_producto = p_id_producto
        AND    id_bodega   = p_id_bodega;
    END IF;
    RETURN vn_stock;
END FN_STOCK_DISPONIBLE;
/

SELECT FN_STOCK_DISPONIBLE(1001)    AS stockConsolidado,
       FN_STOCK_DISPONIBLE(1001, 71) AS stocBodega,
       FN_STOCK_DISPONIBLE(1001,2) AS stockBodegaD,
       FN_STOCK_DISPONIBLE(1001,3)    AS stock
FROM   DUAL;
------------------------------------------------------------------- 2.2 (2 pts)
-- FN_CUPO_DISPONIBLE
-- Retorna el cupo de credito disponible del cliente, entendido como cupo menos
-- saldo pendiente. Un cliente inactivo retorna cero y el resultado nunca puede
-- ser negativo.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Con el SELECT INTO se leyo el estado, cupo y saldo del cliente, para
-- tener los tres datos, para el cupo disponible--> cupo - saldo,ademas 
-- se uso un IF que devuelve 0 si el cliente no esta activo y se compara con los valores 
-- de la tabla ( s o n) --> (inactivo o activo)
-- se agrego un segundo IF que deja el resultado en 0 si la resta da llega a ser negativa,
-- Se hace excepcion de NO_DATA_FOUND para devolver 0 si el cliente no existe. 

CREATE OR REPLACE FUNCTION FN_CUPO_DISPONIBLE (
    p_id_cliente IN NUMBER
) RETURN NUMBER IS
    vc_activo  CLIENTE.activo%TYPE;
    vn_cupo    CLIENTE.cupo_credito%TYPE;
    vn_saldo   CLIENTE.saldo_pendiente%TYPE;
    vn_cupo_disp NUMBER;
BEGIN
    SELECT activo, cupo_credito, saldo_pendiente
    INTO   vc_activo, vn_cupo, vn_saldo
    FROM   CLIENTE
    WHERE  id_cliente = p_id_cliente;
    IF vc_activo <> 'S' THEN
        RETURN 0;
    END IF;
    vn_cupo_disp := vn_cupo - vn_saldo;
    IF vn_cupo_disp < 0 THEN
        vn_cupo_disp := 0;
    END IF;
    RETURN vn_cupo_disp;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END FN_CUPO_DISPONIBLE;
/
SELECT id_cliente, activo,
       FN_CUPO_DISPONIBLE(id_cliente) AS cupo_disponible
FROM   CLIENTE
ORDER  BY id_cliente;

------------------------------------------------------------------- 2.3 (3 pts)
-- FN_CALCULAR_DESCUENTO
-- Retorna el VALOR en pesos del descuento aplicable, segun estas reglas
-- acumulables:
--     Monto mayor o igual a 2.000.000 ................. 8%
--     Monto entre 800.000 y 1.999.999 ................. 5%
--     Monto menor a 800.000 ........................... 0%
--     Adicional si el cliente no tiene saldo pendiente . 2%
--     Tope maximo acumulado ........................... 10%
-- La funcion retorna el valor del descuento, no el porcentaje.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
--La logica se planteo en tres fases, la primera utiliza un condicional para asignar el
--valor del porcentaje de descuento inicial dependiendo del en que rango se encuentra el monto,
--suministrado en el parametro p_monto, la segunda fase utiliza una consulta para despues 
-- con un condicional verificar si el cliente suministrado con p_id_cliente no tiene saldo pendiente
--para agregarle al porcentaje de descuento 2% mas, se valida si el porcentaje supera el 10% y si lo supera,
--se establece a 10%, por ultimo la tercera fase a travez del uso de una "regla de 3" se obtiene y se retorna el valor del
--descuento en pesos, ademas se usa la funcion ROUND para redondear el resultado al entero mas cercano.
--Se utiliza tambien el control de la excepcion NO_DATA_FOUND, principalmente por si p_id_cliente no existe en la tabla CLIENTE.

CREATE OR REPLACE FUNCTION FN_CALCULAR_DESCUENTO (
    p_id_cliente IN NUMBER,
    p_monto      IN NUMBER
) RETURN NUMBER 
IS
    vn_porcentaje_descuento NUMBER := 0;
    vn_saldo CLIENTE.saldo_pendiente%TYPE;
    
BEGIN
    
    IF p_monto >= 2000000 THEN
        vn_porcentaje_descuento := 8;
    ELSIF p_monto >= 800000 THEN
        vn_porcentaje_descuento := 5;
    ELSIF p_monto > 0 THEN
        vn_porcentaje_descuento := 0;
    ELSE
        RETURN 0;
    END IF;
    
    SELECT NVL(saldo_pendiente, 0) INTO vn_saldo
    FROM CLIENTE 
    WHERE id_cliente = p_id_cliente;
    IF vn_saldo = 0 THEN vn_porcentaje_descuento := vn_porcentaje_descuento+2;
    END IF;

    IF vn_porcentaje_descuento > 10 THEN
        vn_porcentaje_descuento := 10;
    END IF;
    
    RETURN ROUND(p_monto * (vn_porcentaje_descuento / 100));
    
EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            RETURN ROUND(p_monto * (vn_porcentaje_descuento / 100));
END FN_CALCULAR_DESCUENTO;
/
SHOW ERRORS

SELECT 501 AS id_cliente, 'Constructora Andes SAS' AS nombre_cliente, 2500000 AS monto_prueba, FN_CALCULAR_DESCUENTO(501, 2500000) AS descuento_esperado
FROM DUAL
UNION ALL
SELECT 503, 'Ferreteria La Esquina', 1000000, FN_CALCULAR_DESCUENTO(503, 1000000)
FROM DUAL
UNION ALL
SELECT  503, 'Ferreteria La Esquina', 3000000,  FN_CALCULAR_DESCUENTO(503, 3000000)
FROM DUAL
UNION ALL
SELECT 999, 'Cliente inexistente', 1500000, FN_CALCULAR_DESCUENTO(999, 1500000)
FROM DUAL
UNION ALL
SELECT 506, 'Suministros del Caribe SA', 200000, FN_CALCULAR_DESCUENTO(506, 200000)
FROM DUAL
UNION ALL
SELECT 505, 'Mantenimientos Tecnicos', 200000, FN_CALCULAR_DESCUENTO(505, 200000)
FROM DUAL;

------------------------------------------------------------------- 2.4 (1 pt)
-- Escriba una consulta que liste los clientes activos con su cupo disponible,
-- usando la funcion del punto 2.2, ordenados de mayor a menor.
-- Explique por que una funcion definida por el usuario puede invocarse desde
-- una sentencia SQL y que restriccion debe cumplir para poder hacerlo.
-------------------------------------------------------------------------------
-- RESPUESTA:
-- Esto se puede ya que una funcion almacenada, con parametros IN y un retorno SQL como NUMBER
-- para el motor se vuelve una expresion mas,por lo que la evalua fila por fila
-- pero tiene restriccion en la "PUREZA" por que llamada desde un SELECT la funcion no puede
-- modificar ni controlar la transaccion, si llega a pasar da error  ORA-14551, ademas solo admite parametros IN y tipos SQL 

SELECT c.id_cliente,
       c.nombre,
       FN_CUPO_DISPONIBLE(c.id_cliente) AS cupo_disponible
FROM   CLIENTE c
WHERE  c.activo = 'S'
ORDER  BY cupo_disponible DESC;


--==============================================================================
-- PARTE 3 — CURSORES                                         (10 puntos / 90 min)
--==============================================================================

------------------------------------------------------------------- 3.1 (2 pts)
-- Bloque anonimo que recorra, con un CURSOR EXPLICITO, los productos cuyo stock
-- consolidado este por debajo del stock minimo, e imprima un reporte con codigo,
-- nombre, stock actual, stock minimo y unidades faltantes, mas el total de
-- productos en esa condicion.
-- Debe usar OPEN, FETCH y CLOSE de forma explicita. El ciclo FOR implicito no se
-- acepta en este punto.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se uso la vista V_STOCK_CONSOLIDADO porque ya trae el stock total de cada
-- producto sumando las bodegas, entonces no hay que repetir ese calculo ni
-- hacer una consulta por producto y se une con PRODUCTO solo para excluir los
-- inactivos,ademas se agrego el bloque EXCEPTION si algo falla en medio el cursor
-- no se queda abierto, ni ocupando recursos de la sesion, por eso, si el cursor sigue a
-- abierto, y este se cierra ya despues se vuelve a lanzar el mismo error con RAISE 
-- para que si ejecuta el bloque se vea que algo falloy esto evita que el error desaparezca sin avisar.
DECLARE
    CURSOR c_bajo_minimo IS
        SELECT v.codigo,
               v.producto,
               v.stock_total,
               v.stock_minimo,
               v.stock_minimo - v.stock_total AS faltantes
        FROM   V_STOCK_CONSOLIDADO v
               JOIN PRODUCTO p ON p.id_producto = v.id_producto
        WHERE  p.activo = 'S'
        AND    v.stock_total < v.stock_minimo
        ORDER  BY faltantes DESC, v.codigo;

    r       c_bajo_minimo%ROWTYPE;
    vn_total NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Productos de bajo del stock minimo:');
    DBMS_OUTPUT.PUT_LINE('');
    OPEN c_bajo_minimo;
    LOOP
        FETCH c_bajo_minimo INTO r;
        EXIT WHEN c_bajo_minimo%NOTFOUND;
        vn_total := vn_total + 1;
        DBMS_OUTPUT.PUT_LINE(vn_total || '= ' || r.producto || ', Codigo: ' || r.codigo || ': ' ||
                             'tiene ' || r.stock_total || ' unidades, el minimo es ' ||
                             r.stock_minimo || ' y faltan ' || r.faltantes || '.');
    END LOOP;
    CLOSE c_bajo_minimo;

    DBMS_OUTPUT.PUT_LINE('');
    IF vn_total = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Ningun producto esta por debajo del stock minimo.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('En total hay:  ' || vn_total || ' productos estan de bajo del stock minimo.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        IF c_bajo_minimo%ISOPEN THEN
            CLOSE c_bajo_minimo;
        END IF;
        RAISE;
END;
/
------------------------------------------------------------------- 3.2 (2 pts)
-- Bloque anonimo con un CURSOR PARAMETRIZADO que reciba identificador de cliente
-- y un rango de fechas, y muestre los pedidos CONFIRMADOS de ese cliente en ese
-- rango, con su total y la cantidad de lineas de cada pedido.
-- Pruebelo con el cliente 501 entre 2026-01-01 y 2026-12-31.
-- Los parametros deben declararse en el cursor, no tomarse del alcance del bloque.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
--Se definio el cursor parametrizado sin tomarse variables del alcance del bloque, lo cual
--nos permite encapsular de mejor manera, pero tambien permitir al optimizador reuitlizar el plan de ejecucion
-- que se encuentra en memoria, la consulta del cursor trae 3 columnas, destacando la columna "lineas", que es la cantidad
--de lineas por pedido, se realizar un LEF JOIN entre pedido y detalle_pedido por si existe pedido sin especificar su detalle,
-- se filtra por los requerimientos del ejercicio y en el bloque se llama  el cursor con un iterador FOR, que muestra el resultado del cursor
--

DECLARE
    CURSOR c_pedidos_confirmados_rango_fechas(p_id_cliente NUMBER, p_fecha_inicial DATE, p_fecha_final DATE)IS
        SELECT
            p.id_pedido, p.total, COUNT(d.linea) AS lineas
        FROM PEDIDO p
        LEFT JOIN DETALLE_PEDIDO d 
            ON p.id_pedido = d.id_pedido
        WHERE p.id_cliente = p_id_cliente
            AND UPPER(p.estado) = 'CONFIRMADO'
            AND p.fecha_pedido BETWEEN p_fecha_inicial AND p_fecha_final
        GROUP BY  p.id_pedido, p.total, p.fecha_pedido
        ORDER BY p.fecha_pedido;
        
        vn_cliente_prueba CONSTANT NUMBER :=501;
        vd_fecha_inicio_prueba CONSTANT DATE := DATE'2026-01-01';
        vd_fecha_final_prueba CONSTANT DATE := DATE'2026-12-31';
BEGIN
    
    FOR r IN c_pedidos_confirmados_rango_fechas(vn_cliente_prueba,vd_fecha_inicio_prueba, vd_fecha_final_prueba ) LOOP
        DBMS_OUTPUT.PUT_LINE('Pedido numero: '||RPAD(TO_CHAR(r.id_pedido), 8)|| 'Total: '||RPAD(TO_CHAR(r.total),20)
            ||'Lineas del pedido: '||RPAD(TO_CHAR(r.lineas),20));
    END LOOP;
END;
/
------------------------------------------------------------------- 3.3 (3 pts)
-- Bloque anonimo con un CURSOR FOR UPDATE que recorra los productos de una
-- categoria y ajuste su precio un porcentaje dado, usando WHERE CURRENT OF.
--   * No debe modificar productos inactivos
--   * El precio resultante no puede quedar por debajo del costo mas el margen
--     minimo de la categoria
-- Explique que bloqueo genera FOR UPDATE, cuanto dura, y por que WHERE CURRENT OF
-- es preferible a un UPDATE por clave primaria.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se uso FOR UPDATE para que las filas de PRODUCTO queden bloqueadas mientras se
-- lee el precio y se actualiza, y nadie lo cambie en medio,este bloqueo es de fila
-- no de tabla, se toma al abrir el cursor y dura hasta el COMMIT o ROLLBACK, no
-- hasta cerrar el cursor, entonces otras sesiones pueden consultar esas filas pero no
-- modificarlas por esta razon el bloque termina en ROLLBACK, para el WHERE CURRENT OF 
-- es mejor que un UPDATE por clave primaria porque actualiza justo la fila que el cursor 
-- acaba de leer, sin buscarla otra vez, y asi no se peligra de modificar una fila distinta a la que se queria.
-- Los inactivos se filtran en el cursor, asi que ni se leen ni se bloquean,  si el
-- precio nuevo queda por debajo de costo * (1 + margen/100), el producto no se
-- actualiza.

DECLARE
    c_categoria  CONSTANT CATEGORIA.id_categoria%TYPE := 1;
    c_porcentaje CONSTANT NUMBER := -22;
    v_margen     CATEGORIA.margen_minimo%TYPE;
    vn_nuevo      NUMBER;
    vn_minimo     NUMBER;
    vn_ajustados  NUMBER := 0;
    CURSOR c_productos (p_categoria NUMBER) IS
        SELECT id_producto, codigo, precio_unitario, costo_unitario
        FROM   PRODUCTO
        WHERE  id_categoria = p_categoria
        AND    activo = 'S'
        ORDER  BY id_producto
        FOR UPDATE;
BEGIN
    SELECT margen_minimo INTO v_margen
    FROM   CATEGORIA
    WHERE  id_categoria = c_categoria;
    DBMS_OUTPUT.PUT_LINE('Categoria ' || c_categoria || ',  ajuste: ' ||
        c_porcentaje ||'%,   margen minimo ' || v_margen || '%');
    FOR r IN c_productos(c_categoria) LOOP
        vn_nuevo  := ROUND(r.precio_unitario * (1 + c_porcentaje / 100), 2);
        vn_minimo := r.costo_unitario * (1 + v_margen / 100);

        IF vn_nuevo > vn_minimo THEN
            UPDATE PRODUCTO SET    precio_unitario = vn_nuevo
            WHERE  CURRENT OF c_productos;
            vn_ajustados := vn_ajustados + 1;
            DBMS_OUTPUT.PUT_LINE( r.codigo || ':  ' || r.precio_unitario ||
                ' -> ' || vn_nuevo || '  (minimo permitido ' || ROUND(vn_minimo, 2) || ')');
        END IF;         
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Ajustados: ' || vn_ajustados);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('La categoria ' || c_categoria || ' no existe');
END;
/
ROLLBACK; 

------------------------------------------------------------------- 3.4 (2 pts)
-- SP_LISTAR_MOVIMIENTOS
-- Procedimiento que reciba un identificador de producto y devuelva un
-- SYS_REFCURSOR con los movimientos de inventario de ese producto, ordenados
-- por fecha. Incluya un bloque anonimo que consuma el cursor devuelto y lo cierre.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
--Se utilizo un SP que abre y utiliza un cursor de referencia que busca un producto por su identificador,
-- y devuelve todas las columnas de los movimientos con ese producto,devolviendo el cursor al llamar el SP, permitiendo que unicamente el procedimiento 
--busque los datos, para despues solamente leerlos en el bloque anonimo. en el bloque consumidor se declaran la
--variable del cursor y la variable basada en la tabla MOVIMIENTO_INVENTARIO, cabe aclarar que en la consulta del cursor,
--se seleccionan todas las columnas de la tabla para poder usar la variable de tipo %ROWTYPE, lo que hace el codigo mas limpio.
--por ultimo se hace el llamado al SP y se lee el cursor, para al final del iterador LOOP cerrar el cursor y liberar recursos.

CREATE OR REPLACE PROCEDURE SP_LISTAR_MOVIMIENTOS (
    p_id_producto IN  NUMBER,
    p_cursor      OUT SYS_REFCURSOR
) IS
BEGIN
    OPEN p_cursor FOR 
        SELECT ID_MOVIMIENTO ,ID_PRODUCTO ,ID_BODEGA ,TIPO ,CANTIDAD ,FECHA_MOV ,ID_PEDIDO ,USUARIO_BD ,OBSERVACION  
        FROM MOVIMIENTO_INVENTARIO
            WHERE id_producto = p_id_producto
        ORDER BY fecha_mov;
        
END SP_LISTAR_MOVIMIENTOS;
/
SHOW ERRORS

-- Bloque consumidor:
DECLARE
    c_cursor SYS_REFCURSOR;
    v_movimientos    MOVIMIENTO_INVENTARIO%ROWTYPE;
BEGIN
--id_producto 1001 de prueba
    SP_LISTAR_MOVIMIENTOS(1001, c_cursor);
  
    LOOP
        FETCH c_cursor INTO v_movimientos;
        EXIT WHEN c_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(RPAD(TO_CHAR(v_movimientos.fecha_mov),15) || 'movimiento #: ' ||
            RPAD(To_CHAR(v_movimientos.id_movimiento),5) || ' bodega #: ' || RPAD(v_movimientos.id_bodega,5) ||
            RPAD(v_movimientos.tipo, 10) ||'Cantidad: ' ||RPAD(v_movimientos.cantidad, 5)  || v_movimientos.observacion);
    END LOOP;
    CLOSE c_cursor;
    
END;
/
------------------------------------------------------------------- 3.5 (1 pt)
-- Bloque anonimo que cargue con BULK COLLECT los productos de una categoria en
-- una coleccion y use FORALL para actualizar su stock minimo.
-- Explique que costo concreto elimina esta tecnica y a partir de que volumen
-- empieza a notarse.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
El costo que se evita es el de ir y venir entre el motor de PL/SQL y el de SQL. 
Un ciclo que actualiza fila por fila hace dos viajes por cada
producto, mientras que con BULK COLLECT y FORALL se hacen dos viajes en
total, sin importar cuantas filas haya. Con tres productos la diferencia no
se nota, empieza a verse con miles de filas y pesa mucho con decenas de
miles. Como la coleccion vive en la memoria de la sesion, con tablas muy
grandes conviene procesar por lotes usando LIMIT. El bloque termina en
ROLLBACK para no alterar los datos.
*/
DECLARE
    TYPE t_ids IS TABLE OF PRODUCTO.id_producto%TYPE;
    v_ids t_ids;
BEGIN
    SELECT id_producto
    BULK COLLECT INTO v_ids
    FROM   PRODUCTO
    WHERE  id_categoria = 3
    AND    activo = 'S';
 
    FORALL i IN 1 .. v_ids.COUNT
        UPDATE PRODUCTO
        SET    stock_minimo = CEIL(stock_minimo * 1.10) 
        WHERE  id_producto  = v_ids(i);
 
    DBMS_OUTPUT.PUT_LINE('Productos actualizados: ' || SQL%ROWCOUNT);
    ROLLBACK;
END;
/


--==============================================================================
-- PARTE 4 — MANEJO DE EXCEPCIONES                             (9 puntos / 75 min)
--==============================================================================

------------------------------------------------------------------- 4.1 (2 pts)
-- FN_PRECIO_PRODUCTO
-- Funcion que reciba el CODIGO de un producto y retorne su precio, manejando
-- explicitamente NO_DATA_FOUND y TOO_MANY_ROWS, con retorno de -1 y -2
-- respectivamente, e imprimiendo un mensaje descriptivo en cada caso.
-- Explique en que situacion real se produciria TOO_MANY_ROWS sobre esta tabla,
-- considerando las restricciones que hoy tiene.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se maneja las excepciones NO_DATA_FOUND y TOO_MANY_ROWS de forma explicita 
--sobre una funcion que devuelve el precio de un producto buscandolo por su codigo.
--NO_DATA_FOUND se genera al no encontrar ningun registro al realizar la consulta, TOO_MANY_ROWS se genera 
-- si la consulta devuelve mas de una fila, por lo que para la columna codigo no se puede generar este error,
--ya que codigo tiene un Constraint UNIQUE(ningun codigo se repite), la excepcion puede generarse sobre esta tabla
--si se busca por Id_categoria, precio_unitario, costo_unitario, Stock_minimo o Activo

CREATE OR REPLACE FUNCTION FN_PRECIO_PRODUCTO (
    p_codigo IN VARCHAR2
) RETURN NUMBER IS
    vn_precio producto.precio_unitario%TYPE;
BEGIN
    SELECT precio_unitario INTO vn_precio 
    FROM PRODUCTO 
        WHERE codigo = p_codigo;
    RETURN vn_precio;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No existe el producto con codigo ' || p_codigo);
        RETURN -1;
    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Multiples productos con codigo ' || p_codigo);
        RETURN -2;
END FN_PRECIO_PRODUCTO;
/
SHOW ERRORS

--prueba
DECLARE
    v_resultado NUMBER;
BEGIN
    -- Prueba 1: Producto existente (Debe devolver 45000)
    v_resultado := FN_PRECIO_PRODUCTO('HM-0001');
    DBMS_OUTPUT.PUT_LINE('Precio retornado prueba 1: ' || v_resultado);
    
    -- Prueba 2: Producto inexistente (Debe imprimir error y devolver -1)
    v_resultado := FN_PRECIO_PRODUCTO('XX-9999');
    DBMS_OUTPUT.PUT_LINE('Precio retornado prueba 2: ' || v_resultado);
END;
/

------------------------------------------------------------------- 4.2 (2 pts)
-- SP_VALIDAR_DESPACHO
-- Procedimiento que verifique si puede despacharse una cantidad de un producto
-- desde una bodega. Debe declarar una EXCEPCION PROPIA, levantarla con RAISE
-- cuando la cantidad solicitada supere el disponible, y capturarla en el bloque
-- EXCEPTION.
-- Argumente por que conviene nombrar esa condicion en lugar de resolverla con un
-- condicional.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se declaro una excepcion propia junto con RAISE cuando la cantidad
-- solicitada supera el disponible esta en el bloque EXCEPTION, donde
-- se muestra el mensaje de que no se puede despachar.
-- es mejor asi y no por un condicional por que el nombre que se le da "e_stock_insuficiente" 
-- nos da una una regla que se incumple, el error se detecta en un punto
-- y este se maneja en otro,ademas se distingue de otros errores del
-- sistema que lleguen al mismo bloque, aunque un IF tambien funciona, pero es para una sola validacion, 
-- sin contar que con la excepcion nombrada es mas claro y facil de entender, se maneja por separado.
CREATE OR REPLACE PROCEDURE SP_VALIDAR_DESPACHO (
    p_id_producto IN NUMBER,
    p_id_bodega   IN NUMBER,
    p_cantidad    IN NUMBER
) IS
    e_stock_insuficiente EXCEPTION;
    vn_disponible NUMBER;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE_APPLICATION_ERROR(-20141, 'La cantidad a despachar debe ser mayor que cero');
    END IF;
    vn_disponible := FN_STOCK_DISPONIBLE(p_id_producto, p_id_bodega);
    IF p_cantidad > vn_disponible THEN
        RAISE e_stock_insuficiente;
    END IF;
    DBMS_OUTPUT.PUT_LINE('Se puede despachar.');
EXCEPTION
    WHEN e_stock_insuficiente THEN
        DBMS_OUTPUT.PUT_LINE('No se puede despachar: la cantidad supera el disponible.');
END SP_VALIDAR_DESPACHO;
/
BEGIN
    SP_VALIDAR_DESPACHO(1002, 1, 50);
    SP_VALIDAR_DESPACHO(1001, 1, 500);
    SP_VALIDAR_DESPACHO(1006, 3, 1);
END;
/

------------------------------------------------------------------- 4.3 (2 pts)
-- SP_ANULAR_PEDIDO
-- Procedimiento que anule un pedido, usando RAISE_APPLICATION_ERROR con estos
-- codigos:
--     -20010  el pedido no existe
--     -20011  el pedido ya esta anulado
--     -20012  el pedido tiene mas de 30 dias
-- Explique la diferencia entre RAISE y RAISE_APPLICATION_ERROR, y en que caso el
-- cliente de la base de datos puede distinguirlos.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- Se usa RAISE_APPLICATION_ERROR porque permite crear  errores personalizados,
-- se les asigna un número entre -20000 y -20999 y con un mensaje propio para que 
-- se sepa qué fallo, la diferencia con RAISE a es que RAISE sirve para lanzar excepciones 
-- internas de Oracle o variables de error definido, pero no deja 
-- mandar un mensaje de texto personalizado, el usuario o la app 
-- pueden distinguirlos fácilmente porque con RAISE_APPLICATION_ERROR reciben 
-- el código exacto como el -20011 junto al mensaje en pantalla, mientras 
-- que con un RAISE genérico solo verían un error de código estándar de Oracle.

CREATE OR REPLACE PROCEDURE SP_ANULAR_PEDIDO (
    p_id_pedido IN NUMBER
) IS
    vv_estado PEDIDO.estado%TYPE;
    vd_fecha  PEDIDO.fecha_pedido%TYPE;
BEGIN
    SELECT estado, fecha_pedido INTO vv_estado, vd_fecha
    FROM PEDIDO
        WHERE id_pedido = p_id_pedido;
        
    IF vv_estado = 'ANULADO' THEN
        RAISE_APPLICATION_ERROR(-20011, 'El pedido ya esta anulado');
    END IF;

    IF (SYSDATE - vd_fecha) > 30 THEN
        RAISE_APPLICATION_ERROR(-20012, 'El pedido tiene mas de 30 dias');
    END IF;
    
    UPDATE PEDIDO
    SET estado = 'ANULADO'
    WHERE id_pedido = p_id_pedido;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'No existe el pedido');
END SP_ANULAR_PEDIDO;
/
SHOW ERRORS

BEGIN
    -- Caso 1: Dispara el error -20010 (El pedido 999 no existe en la tabla)
    SP_ANULAR_PEDIDO(999); 
    
    -- Caso 2: Dispara el error -20011 (El pedido 7 ya se encuentra 'ANULADO' desde su creación)
    SP_ANULAR_PEDIDO(7); 
    
    -- Caso 3: Dispara el error -20012 (El pedido 1 es de junio de 2026, tiene más de 30 días)
    SP_ANULAR_PEDIDO(1); 
    
    -- Caso 4: Éxito (El pedido 6 es reciente y está en BORRADOR, por lo que pasará a ANULADO)
    SP_ANULAR_PEDIDO(6); 
END;
/

------------------------------------------------------------------- 4.4 (2 pts)
-- Bloque anonimo que intente insertar un producto con una categoria inexistente
-- y capture el error de integridad referencial asociando ORA-02291 a una
-- excepcion con nombre.
-- Explique que aporta esa asociacion frente a atrapar el error en un manejador
-- generico.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
Oracle no le pone nombre al error ORA-02291, asi que se usa EXCEPTION_INIT
para ligarlo a una excepcion con nombre y poder atraparla de forma directa.
Ese error sale de la clave foranea fk_producto_categoria, que obliga a que
PRODUCTO.id_categoria exista en CATEGORIA.id_categoria; como la categoria
999 no esta en CATEGORIA, Oracle no halla la clave padre y no deja guardar
el producto. Usar la excepcion con nombre es mejor que WHEN OTHERS, porque
OTHERS atrapa cualquier falla y obliga a revisar SQLCODE con un IF para saber cual 
fue, mientras que el manejador nombrado solo responde a esta condicion y deja pasar las demas. 
Por eso TRG_PRODUCTO_BIU_MARGEN no rechaza la categoria inexistente y permite que
sea fk_producto_categoria la que lance el error, y el INSERT usa el id 9999
para no consumir un valor de la secuencia.
*/

DECLARE
    e_categoria_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_categoria_inexistente, -2291);
BEGIN
  INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria,
                          precio_unitario, costo_unitario)
    VALUES (9999, 'PRUEBA', 'Producto de prueba', 999, 100, 50);
 
    DBMS_OUTPUT.PUT_LINE('Inesperado: el producto se inserto');
    ROLLBACK;
    EXCEPTION
    WHEN e_categoria_inexistente THEN
        DBMS_OUTPUT.PUT_LINE('Integridad referencial: la categoria 999 no existe.');
        DBMS_OUTPUT.PUT_LINE('Detalle del motor: ' || SQLERRM);
END;
/

------------------------------------------------------------------- 4.5 (1 pt)
-- SP_REGISTRAR_ERROR
-- Procedimiento que reciba el origen y registre en LOG_ERRORES el SQLCODE y el
-- SQLERRM actuales. El registro debe persistir aunque la transaccion principal
-- termine en ROLLBACK.
-- Explique por que se requiere esa independencia transaccional y describa un
-- escenario en el que esa misma independencia oculte informacion en lugar de
-- preservarla.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
La independencia transaccional se necesita porque un error normalmente
termina en ROLLBACK, y si el registro del error viviera dentro de esa misma
transaccion se desharia junto con ella, dejando el log vacio justo cuando
mas hace falta. Por eso el procedimiento corre en una transaccion aparte,
de modo que su COMMIT confirma solo el INSERT en LOG_ERRORES y no toca el
trabajo pendiente de quien lo llamo. Esa misma independencia puede ocultar
informacion en un ciclo de reintentos: si una operacion falla dos veces y
la tercera funciona, cada intento fallido queda confirmado en el log aunque
el resultado final sea exitoso, y quien revise LOG_ERRORES solo ve errores
y cree que el proceso fallo cuando en realidad se resolvio. El INSERT toma
SQLCODE y SQLERRM tal como estan al momento de la llamada, y el COMMIT
final es obligatorio porque una transaccion autonoma siempre debe terminar
confirmada o revertida.

*/
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_ERROR (
    p_origen  IN VARCHAR2,
    p_detalle IN VARCHAR2 DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    vn_codigo  NUMBER         := SQLCODE;
    vv_mensaje VARCHAR2(500)  := SUBSTR(SQLERRM, 1, 500);
BEGIN
    INSERT INTO LOG_ERRORES (id_log, origen, codigo_error, mensaje, detalle)
    VALUES (SEQ_LOG.NEXTVAL, p_origen, vn_codigo, vv_mensaje, p_detalle);
    COMMIT;
END SP_REGISTRAR_ERROR;
/
SHOW ERRORS
--==============================================================================
-- PARTE 5 — DISPARADORES                                     (10 puntos / 90 min)
--==============================================================================
-- Los esqueletos de esta parte no incluyen la clausula de disparo. Definirla
-- hace parte del ejercicio.
--==============================================================================

------------------------------------------------------------------- 5.1 (2 pts)
-- TRG_CLIENTE_BI
-- Al insertar un cliente debe asignar el identificador desde SEQ_CLIENTE si
-- llega nulo, convertir el nombre a mayusculas sin espacios sobrantes y forzar
-- el estado activo a 'S' si no se indica.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
--Se utiliza un Trigger BEFORE INSERT que permite utilizar y modificar la variable que llega nueva,junto
--con FOR EACH ROW ya que permite que se ejecute el trigger por cada fila afectada. El TRIGGER verifica
-- asigna un identificador, limpia el nombre y le coloca el estado activo como 'S', todo esto por cada 
--Insercion que se haga, permite grantizar la integridad, principalmente por la asignacion secuencial del
--identificador,Aunque se considera que para estado activo se puede colocar como valor por defecto 's'
--

CREATE OR REPLACE TRIGGER TRG_CLIENTE_BI
    BEFORE INSERT ON CLIENTE
    FOR EACH ROW
BEGIN
    IF :NEW.id_cliente IS NULL THEN 
        :NEW.id_cliente := SEQ_CLIENTE.NEXTVAL;
    END IF;
    
    IF :NEW.nombre IS NOT NULL THEN
        :NEW.nombre := TRIM(UPPER(:NEW.nombre));
    END IF;
    
    IF :NEW.activo IS NULL THEN
        :NEW.ACTIVO := 'S';
    END IF;
END TRG_CLIENTE_BI;
/

--Prueba
INSERT INTO CLIENTE (documento, nombre, ciudad, cupo_credito, saldo_pendiente)
VALUES ('900999888', '   ferreteria el martillo  ', 'Bogota', 5000000, 0);

SELECT id_cliente, documento, nombre, activo 
FROM CLIENTE 
WHERE documento = '900999888';

ROLLBACK;

------------------------------------------------------------------- 5.2 (2 pts)
-- TRG_PRODUCTO_AU_PRECIO
-- Debe registrar en AUDITORIA_PRECIO todo cambio de precio, calculando la
-- variacion porcentual, y dispararse unicamente cuando el precio efectivamente
-- cambie, resolviendo esa condicion con la clausula WHEN y no dentro del cuerpo.
-- Explique la diferencia entre ambas formas.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
-- se uso el WHEN para que se revise el precio antes de activar el trigger, 
-- si el precio no cambio, Oracle ignora el trigger y no 
-- gasta memoria ni procesos lo que si pasaria si se usa un IF 
-- adentro, ademas, calculamos el porcentaje tranquilos porque el precio de un 
-- producto nunca va a ser cero, asi que la división no va a fallar.
--------------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_PRODUCTO_AU_PRECIO
AFTER UPDATE OF precio_unitario ON PRODUCTO
FOR EACH ROW
WHEN (NEW.precio_unitario <> OLD.precio_unitario)
BEGIN
    INSERT INTO AUDITORIA_PRECIO
           (id_auditoria, id_producto, precio_anterior, precio_nuevo,
            variacion_pct, usuario_bd, fecha_cambio)
    VALUES (SEQ_AUDITORIA.NEXTVAL, :OLD.id_producto, :OLD.precio_unitario,
            :NEW.precio_unitario,
            ROUND((:NEW.precio_unitario - :OLD.precio_unitario) / :OLD.precio_unitario * 100, 2),
            USER, SYSDATE);
END TRG_PRODUCTO_AU_PRECIO;
/

UPDATE PRODUCTO SET precio_unitario = 46000 WHERE id_producto = 1001;
UPDATE PRODUCTO SET precio_unitario = precio_unitario WHERE id_producto = 1002;
SELECT id_producto, precio_anterior, precio_nuevo, variacion_pct
FROM   AUDITORIA_PRECIO
ORDER  BY id_auditoria;

ROLLBACK;

------------------------------------------------------------------- 5.3 (2 pts)
-- TRG_PRODUCTO_BIU_MARGEN
-- Debe impedir que se guarde un producto cuyo precio no alcance el margen minimo
-- de su categoria, segun la formula precio >= costo * (1 + margen/100),
-- rechazando la operacion con el error -20020.
-- Considere que debe ocurrir cuando la categoria indicada no existe, y justifique
-- su decision.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
--Se utiliza un Trigger antes de cualquier insercion o actualizacion en la tabla PRODUCTO
--que busca la categoria del producto nuevo y con la formula "precio >= costo * (1 + margen/100)",
--impide que se escriba el producto que no alcance el margen minimo.
-- Si la categoria no existe no se va a generar un error NO_DATA_FOUND ya que el disparador se 
--ejecuta antes de la escritura, por lo que es necesario atrapar la excepcion de forma explicita
--y dar un mensaje de error propio usando RAISE_APPLICATION_ERROR

CREATE OR REPLACE TRIGGER TRG_PRODUCTO_BIU_MARGEN
    BEFORE INSERT OR UPDATE ON PRODUCTO
    FOR EACH ROW
DECLARE 
    v_margen CATEGORIA.margen_minimo%TYPE;
BEGIN
    SELECT margen_minimo INTO v_margen
    FROM CATEGORIA
        WHERE id_categoria = :NEW.id_categoria;
        
    IF :NEW.precio_unitario < (:NEW.costo_unitario * (1 + (v_margen / 100))) THEN
        RAISE_APPLICATION_ERROR(-20020, 'El precio es menor al margen minimo de la categoria '|| v_margen);
    END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20021, 'La categoria indicada no existe');
END;
/


--Pruebas
-- Caso 1: Falla por categoría inexistente 
-- Intentamos insertar un producto con id_categoria = 99 
INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria, precio_unitario, costo_unitario)
VALUES (2001, 'XX-001', 'Prueba Categoria', 99, 10000, 5000);

-- Caso 2: Falla por precio por debajo del margen (Debe arrojar el error -20020)
-- La categoria 1 tiene un margen del 25%. Costo 10000 + 25% = 12500 mínimo.
-- Intentamos insertarlo a 11000.
INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria, precio_unitario, costo_unitario)
VALUES (2002, 'XX-002', 'Prueba Margen', 1, 11000, 10000);

-- Caso 3: Cumple con todo
-- Costo 10000, Precio 15000, superior a los 12500 exigidos por el margen del 25%.
INSERT INTO PRODUCTO (id_producto, codigo, nombre, id_categoria, precio_unitario, costo_unitario)
VALUES (2003, 'XX-003', 'Prueba Exito', 1, 15000, 10000);

ROLLBACK;

------------------------------------------------------------------- 5.4 (2 pts)
-- TRG_DETALLE_AI_STOCK
-- Al insertar una linea de pedido debe descontar el stock de la bodega indicada
-- y registrar el movimiento de SALIDA correspondiente. Si no hay stock suficiente
-- debe abortar la operacion con el error -20030.
-- Explique por que el momento de disparo que eligio es el correcto y que dejaria
-- de funcionar con el contrario.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
--Se dispara AFTER INSERT porque Oracle verifica PK, FK y CHECK antes de los
-- triggers AFTER ROW, de modo que solo se descuenta stock de lineas ya
-- validadas, con BEFORE correria sobre datos sin validar y una cantidad
-- negativa sumaria stock. El descuento es un solo UPDATE condicionado
-- en cantidad >= :NEW.cantidad, que evita la carrera de un SELECT previo, y si
-- no afecta ninguna fila se aborta con -20030 y Oracle revierte la sentencia
-- completa. No usa SP_AJUSTAR_STOCK porque su firma no recibe id_pedido y la
-- SALIDA debe quedar ligada al pedido en MOVIMIENTO_INVENTARIO.

CREATE OR REPLACE TRIGGER TRG_DETALLE_AI_STOCK
AFTER INSERT ON DETALLE_PEDIDO
FOR EACH ROW
BEGIN
    UPDATE EXISTENCIA
    SET    cantidad = cantidad - :NEW.cantidad
    WHERE  id_bodega   = :NEW.id_bodega
    AND    id_producto = :NEW.id_producto
    AND    cantidad   >= :NEW.cantidad;
 
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20030,
            'Stock insuficiente en la bodega ' || :NEW.id_bodega || ' para el producto '
            || :NEW.id_producto || ' (solicitado ' || :NEW.cantidad || ')');
    END IF;
 
    INSERT INTO MOVIMIENTO_INVENTARIO (id_movimiento, id_producto, id_bodega, tipo,
                                       cantidad, id_pedido, observacion)
    VALUES (SEQ_MOVIMIENTO.NEXTVAL, :NEW.id_producto, :NEW.id_bodega, 'SALIDA',
            :NEW.cantidad, :NEW.id_pedido,
            'Despacho de pedido ' || :NEW.id_pedido || ' linea ' || :NEW.linea);
END TRG_DETALLE_AI_STOCK;
/

------------------------------------------------------------------- 5.5 (1 pt)
-- TRG_DETALLE_TOTAL
-- Debe recalcular el total de la cabecera del pedido despues de cualquier
-- insercion, actualizacion o borrado de sus lineas.
-- Documente el error que obtiene en su primer intento, en que momento aparece,
-- y como lo resuelve la construccion que finalmente utilizo.
-- Este punto no se califica sin esa explicacion.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*El primer intento fue un trigger de fila con SELECT SUM(subtotal) sobre
DETALLE_PEDIDO. El error no aparece alcompilar sino en ejecucion, cuando se dispara la primera 
fila, porque untrigger de fila no puede consultar la tabla 
que la sentencia esta modificando ya que se encuentra en un estado intermedio.
La solucion final no consulta DETALLE_PEDIDO y ajusta PEDIDO.total con la
diferencia que aporta cada fila. En un INSERT suma el subtotal nuevo, en un
DELETE resta el subtotal borrado y en un UPDATE resta el valor viejo y suma el
nuevo. Como solo modifica PEDIDO, que no es la tabla mutante, el error no se
presenta. El trigger no hace COMMIT ni ROLLBACK para que el total se confirme
o se deshaga junto con las lineas.
*/

CREATE OR REPLACE TRIGGER TRG_DETALLE_TOTAL
AFTER INSERT OR UPDATE OR DELETE ON DETALLE_PEDIDO
FOR EACH ROW
BEGIN
    IF INSERTING OR UPDATING THEN
        UPDATE PEDIDO SET total = NVL(total, 0) + NVL(:NEW.subtotal, 0)
        WHERE  id_pedido = :NEW.id_pedido;
    END IF;
    IF DELETING OR UPDATING THEN
        UPDATE PEDIDO SET total = NVL(total, 0) - NVL(:OLD.subtotal, 0)
        WHERE  id_pedido = :OLD.id_pedido;
    END IF;
 
END TRG_DETALLE_TOTAL;
/
------------------------------------------------------------------- 5.6 (1 pt)
-- TRG_V_STOCK_IO
-- Debe permitir actualizar el precio y el stock minimo del producto a traves de
-- la vista V_STOCK_CONSOLIDADO.
-- Explique por que esa vista no es actualizable de forma directa.
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
La vista suma el stock de cada producto en las bodegas, por lo que una fila de 
la vista no corresponde a una sola fila de una tabla base yel motor no sabe 
donde aplicar el cambio, de modo que rechaza el UPDATE directo.
Por eso se usa un trigger INSTEAD OF, que solo existe sobre vistas, es siempre
de fila y reemplaza la sentencia original. Su cuerpo traduce el cambio de
precio y stock minimo a la tabla PRODUCTO, localizando la fila por el
id_producto de la vista. Al actualizar PRODUCTO se siguen aplicando los
triggers de margen y de auditoria de precio. Cualquier otra columna de la
vista, como el stock consolidado, no se actualiza y su cambio se ignora.
*/
CREATE OR REPLACE TRIGGER TRG_V_STOCK_IO
INSTEAD OF UPDATE ON V_STOCK_CONSOLIDADO
FOR EACH ROW
BEGIN
    UPDATE PRODUCTO
    SET    precio_unitario = :NEW.precio_unitario,
           stock_minimo    = :NEW.stock_minimo
    WHERE  id_producto     = :OLD.id_producto;
END TRG_V_STOCK_IO;
/


--==============================================================================
-- PARTE 6 — CASO INTEGRADOR                                   (5 puntos / 45 min)
--==============================================================================

------------------------------------------------------------------- 6.1 (5 pts)
-- PKG_VENTAS
-- Construya un PAQUETE que exponga el procedimiento SP_FACTURAR_PEDIDO, el cual,
-- para un pedido en estado BORRADOR, debe:
--
--   1. Validar que el pedido exista y este en BORRADOR
--   2. Recorrer sus lineas con un cursor y acumular el subtotal
--   3. Calcular el descuento con FN_CALCULAR_DESCUENTO
--   4. Validar contra FN_CUPO_DISPONIBLE que el cliente tenga cupo suficiente
--   5. Actualizar el total del pedido y cambiar su estado a CONFIRMADO
--   6. Incrementar el saldo pendiente del cliente
--   7. Usar SAVEPOINT y revertir parcialmente ante cualquier fallo, registrando
--      el error con SP_REGISTRAR_ERROR
--   8. Devolver por parametros OUT el total facturado y el descuento aplicado
--
-- Firma esperada:
--   PKG_VENTAS.SP_FACTURAR_PEDIDO(p_id_pedido IN NUMBER,
--                                 p_total     OUT NUMBER,
--                                 p_descuento OUT NUMBER)
-------------------------------------------------------------------------------
-- JUSTIFICACION:
/*
El procedimiento se apoya en lo ya construido: el descuento sale de
FN_CALCULAR_DESCUENTO, el cupo de FN_CUPO_DISPONIBLE y los errores se registran
con SP_REGISTRAR_ERROR, sin repetir su logica, el descuento se calcula antes de
subir el saldo, porque la funcion da un 2% extra a quien no tiene deuda y la
propia factura se lo quitaria, entonces el cupo se compara con el total neto, 
que es lo que realmente se suma al saldo, ademas el stock no se toca,
porque TRG_DETALLE_AI_STOCK ya lo descuenta al insertar cada linea.

El SAVEPOINT va al inicio: si algo falla, el ROLLBACK TO SAVEPOINT deshace solo
lo que hizo este procedimiento y no el trabajo pendiente de quien lo llama despues se 
guard el error y se relanza con RAISE para que quien llama sepa que no se facturo, 
en concurrencia se bloquean el pedido y el cliente con FOR UPDATE WAIT 10,
siempre en ese orden, para que dos sesiones no facturen el mismo pedido ni pasen
ambas la validacion de cupo con el mismo saldo, pero si el bloqueo no se consigue en
10 segundos, el error se registra y se relanza sin dejar cambios a medias.
*/
CREATE OR REPLACE PACKAGE PKG_VENTAS IS
    PROCEDURE SP_FACTURAR_PEDIDO (
        p_id_pedido IN  NUMBER,
        p_total     OUT NUMBER,
        p_descuento OUT NUMBER
    );
 
END PKG_VENTAS;
/
CREATE OR REPLACE PACKAGE BODY PKG_VENTAS IS
 
    PROCEDURE SP_FACTURAR_PEDIDO (
        p_id_pedido IN  NUMBER,
        p_total     OUT NUMBER,
        p_descuento OUT NUMBER
    ) IS
        vn_id_cliente  PEDIDO.id_cliente%TYPE;
        vv_estado      PEDIDO.estado%TYPE;
        vn_bloqueo     CLIENTE.id_cliente%TYPE;
        vn_subtotal    NUMBER      := 0;
        vn_lineas      PLS_INTEGER := 0;
        vn_descuento   NUMBER;
        vn_total       NUMBER;
        vn_cupo        NUMBER;
 
        CURSOR c_lineas (cp_id_pedido NUMBER) IS
            SELECT linea, subtotal
            FROM   DETALLE_PEDIDO
            WHERE  id_pedido = cp_id_pedido
            ORDER  BY linea;
    BEGIN
        SAVEPOINT sp_facturar;
 
        p_total     := NULL;
        p_descuento := NULL;
 
        BEGIN
            SELECT id_cliente, estado
            INTO   vn_id_cliente, vv_estado
            FROM   PEDIDO
            WHERE  id_pedido = p_id_pedido
            FOR UPDATE WAIT 10;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20040,
                    'El pedido ' || NVL(TO_CHAR(p_id_pedido), 'NULL') || ' no existe');
        END;
 
        IF vv_estado <> 'BORRADOR' THEN
            RAISE_APPLICATION_ERROR(-20041,
                'El pedido ' || p_id_pedido || ' esta en estado ' || vv_estado
                || '; solo se puede facturar un BORRADOR');
        END IF;
 
        SELECT id_cliente
        INTO   vn_bloqueo
        FROM   CLIENTE
        WHERE  id_cliente = vn_id_cliente
        FOR UPDATE WAIT 10;
 
        FOR r IN c_lineas(p_id_pedido) LOOP
            vn_subtotal := vn_subtotal + r.subtotal;
            vn_lineas   := vn_lineas + 1;
        END LOOP;
 
        IF vn_lineas = 0 THEN
            RAISE_APPLICATION_ERROR(-20042,
                'El pedido ' || p_id_pedido || ' no tiene lineas para facturar');
        END IF;
 
        vn_descuento := FN_CALCULAR_DESCUENTO(vn_id_cliente, vn_subtotal);
        vn_total     := vn_subtotal - vn_descuento;
 
        -- 4. Cupo suficiente para el total neto
        vn_cupo := FN_CUPO_DISPONIBLE(vn_id_cliente);
        IF vn_total > vn_cupo THEN
            RAISE_APPLICATION_ERROR(-20043,
                'Cupo insuficiente para el cliente ' || vn_id_cliente
                || ': disponible ' || vn_cupo || ', requerido ' || vn_total);
        END IF;
 
        UPDATE PEDIDO
        SET    total  = vn_total,
               estado = 'CONFIRMADO'
        WHERE  id_pedido = p_id_pedido;
 
        UPDATE CLIENTE
        SET    saldo_pendiente = saldo_pendiente + vn_total
        WHERE  id_cliente = vn_id_cliente;
 
        p_total     := vn_total;
        p_descuento := vn_descuento;
 
    EXCEPTION

        WHEN OTHERS THEN
            ROLLBACK TO SAVEPOINT sp_facturar;
            SP_REGISTRAR_ERROR('PKG_VENTAS.SP_FACTURAR_PEDIDO',
                               'Pedido ' || NVL(TO_CHAR(p_id_pedido), 'NULL'));
            RAISE;
    END SP_FACTURAR_PEDIDO;
 
END PKG_VENTAS;
/
SHOW ERRORS
 
-- PRUEBAS

DECLARE
    vt_inicio TIMESTAMP := SYSTIMESTAMP;
    vn_total  NUMBER;
    vn_desc   NUMBER;
    vn_saldo  CLIENTE.saldo_pendiente%TYPE;
 
    PROCEDURE probar (p_caso VARCHAR2, p_pedido NUMBER) IS
    BEGIN
        PKG_VENTAS.SP_FACTURAR_PEDIDO(p_pedido, vn_total, vn_desc);
        DBMS_OUTPUT.PUT_LINE(p_caso || ': facturado, total ' || vn_total
                             || ', descuento ' || vn_desc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(p_caso || ': ' || SUBSTR(SQLERRM, INSTR(SQLERRM, ': ') + 2));
    END probar;
BEGIN
    INSERT INTO DETALLE_PEDIDO (id_pedido, linea, id_producto, id_bodega, cantidad, precio_unitario, subtotal)
    VALUES (6, 1, 1004, 1, 5, 320000, 1600000);
    INSERT INTO DETALLE_PEDIDO (id_pedido, linea, id_producto, id_bodega, cantidad, precio_unitario, subtotal)
    VALUES (6, 2, 1001, 1, 10, 45000, 450000);

    probar('Caso 1 (pedido 6)', 6);
    SELECT saldo_pendiente INTO vn_saldo FROM CLIENTE WHERE id_cliente = 501;
    DBMS_OUTPUT.PUT_LINE('   saldo del cliente 501 ahora: ' || vn_saldo);

    probar('Caso 2 (pedido 999)', 999);
 
    probar('Caso 3 (pedido 1)', 1);

    INSERT INTO PEDIDO (id_pedido, id_cliente, fecha_pedido, estado, total)
    VALUES (9001, 502, SYSDATE, 'BORRADOR', 0);
    INSERT INTO DETALLE_PEDIDO (id_pedido, linea, id_producto, id_bodega, cantidad, precio_unitario, subtotal)
    VALUES (9001, 1, 1004, 2, 1, 320000, 320000);
    probar('Caso 4 (pedido 9001)', 9001);

    INSERT INTO PEDIDO (id_pedido, id_cliente, fecha_pedido, estado, total)
    VALUES (9002, 503, SYSDATE, 'BORRADOR', 0);
    probar('Caso 5 (pedido 9002)', 9002);

    FOR l IN (SELECT codigo_error, detalle
              FROM   LOG_ERRORES
              WHERE  origen = 'PKG_VENTAS.SP_FACTURAR_PEDIDO'
              AND    fecha_log >= vt_inicio
              ORDER  BY id_log) LOOP
        DBMS_OUTPUT.PUT_LINE('   log: ' || l.codigo_error || ' - ' || l.detalle);
    END LOOP;

    ROLLBACK;
END;
/
 
-- Limpieza opcional del log de pruebas, despues de capturar la salida
-- (LOG_ERRORES viene vacia en el esquema original)
-- DELETE FROM LOG_ERRORES WHERE origen = 'PKG_VENTAS.SP_FACTURAR_PEDIDO';
-- COMMIT;
 

--==============================================================================
-- FIN DE LA PLANTILLA
--==============================================================================
