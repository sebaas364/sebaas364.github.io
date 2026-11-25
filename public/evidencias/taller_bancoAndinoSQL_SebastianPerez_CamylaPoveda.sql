-- =====================================================================
-- Bases de Datos 2 · Taller integrador — Banco Andino
-- 01_sesion_A.sql        >>>  CONEXIÓN A  <<<   (cajero A)
--
-- NO ejecute este archivo de corrido. Cada bloque dice PASO n:
-- ejecútelo con Ctrl+Enter cuando le toque, alternando con la conexión B.
--
-- ANTES DE EMPEZAR, verifique:
--   1. Autocommit APAGADO
--      Herramientas > Preferencias > Base de datos > Avanzado > Autoconfirmar
--      (debe estar DESMARCADO)
--   2. Dos CONEXIONES distintas, no dos hojas sobre la misma conexión.
-- =====================================================================

SELECT 'CONEXIÓN A' AS ventana, SYS_CONTEXT('USERENV','SID') AS sid FROM dual;


-- #####################################################################
-- EJERCICIO 1.1 — El retiro que se pierde (actualización perdida)
--
-- Escenario: el mismo cliente retira por el cajero automático mientras
-- su empresa le hace un débito automático. Las dos operaciones leen el
-- saldo, restan en memoria y escriben el resultado. Es lo que hace la
-- mayoría del código que ustedes van a encontrar en producción.
--
-- Cuenta 1001, saldo inicial 1.000.000.
-- #####################################################################

-- PASO 1  (A)  Estado inicial
SELECT id_cuenta, saldo, saldo_retenido, version
  FROM cuenta WHERE id_cuenta = 1001;
--> Anote el SALDO. Debe ser 1.000.000.

-- PASO 2  (A)  "El cajero" leyó 1.000.000 y calculó 1.000.000 - 300.000
UPDATE cuenta SET saldo = 700000 WHERE id_cuenta = 1001;
--  NO confirme todavía.

-- ... vaya a la conexión B, PASO 3 ...

-- PASO 5  (A)  Confirmo mi retiro de 300.000
COMMIT;

-- ... conexión B, PASO 6 ...

-- PASO 8  (A)  ¿Cuánto saldo quedó?
SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta = 1001;
--
--  PREGUNTA 1.1 — Salieron 300.000 (A) más 200.000 (B) = 500.000 de
--  1.000.000. Deberían quedar 500.000. ¿Cuántos quedan? ¿Quién "ganó"?
--  ¿Hubo algún error, alguna advertencia, algún registro de que algo
--  salió mal?


--  Respuesta: No, quedan 800.000, ya que la parte B hizo update de ultimas, por lo cual
--  el resultado va a ser el que B haya dicho en este caso 800.000.
--  No hay error o advertencia ya que realmente todo se manejo de forma valida, para la base de datos
--  todo se realizo de forma adecuada.
--  frente a la situación gana el cliente ya que nunca se desconto o se resto la cantidad real, peride el banco.


--  PREGUNTA 1.2 — El bloqueo de fila SÍ funcionó: B esperó a que A
--  confirmara. Explique entonces por qué el banco perdió dinero de todos
--  modos.


--  RESPUESTA: Esto sucede ya que el bloqueo evita que se escriba al mismo tiempo, pero al momento de realizarlo ambos leyeron el valor incial
--  Al leer el valor antes de confirmar un cambio, todo se realizo en base a ese, en pocas palabras A y B empezaron, A y B leyeron lo mismo,
--  A actualizo pero B tambien actualizo sobre el valor leido y reemplazo lo que A habia hecho.


--  PREGUNTA 1.3 — En un marketplace este error vende una unidad de más.
--  En un banco, ¿de quién es la plata que se acaba de crear de la nada,
--  y quién la va a reclamar?


--  RESPUESTA: Los 300.000 que no aparecnieron del retiro de A nunca llegaron a descontarse del saldo final,
--  es dinero que el banco cree que ya no tiene el cliente, pero que el cliente si tiene,  es el
--  banco el que pierde esa plata y es el banco quien debe ir a reclamar 

-- #####################################################################
-- EJERCICIO 1.2 — Defensa pesimista: SELECT ... FOR UPDATE
-- #####################################################################

-- PASO 1  (A)  Dejo la cuenta en un valor conocido
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta = 1001;
COMMIT;

-- PASO 2  (A)  Leo Y bloqueo en la misma operación
SELECT id_cuenta, saldo
  FROM cuenta
 WHERE id_cuenta = 1001
   FOR UPDATE;

-- ... conexión B, PASO 3 ...

-- PASO 5  (A)  Descuento mis 300.000 y libero
UPDATE cuenta SET saldo = saldo - 300000 WHERE id_cuenta = 1001;
COMMIT;

-- ... conexión B, PASO 6 ...

-- PASO 8  (A)  Resultado
SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta = 1001;
--
--  PREGUNTA 1.4 — Ahora sí quedan 500.000. ¿Qué dos cosas cambiaron
--  respecto al ejercicio anterior? (pista: una es el FOR UPDATE, la otra
--  está dentro del UPDATE mismo)


--  Si, en el For UPDATE del paso 2 cambio,, ya que hace que A tome el bloqueo de la fila en el momento de leer, no cuando se esta escribiendo
--  lo que nos dice que B queda bloqueado desde el el SELECT FOR UPDATE, ya que este asegura que los datos no cambien entre el momento en que se lee y el momento en que se actualiza
--  y en el UPDATE, se esta realizando una cuenta "- 200000" no se esta escribiendo el valor de uan, por lo cual se va a realizar sobre el valor que haya no sobre uno fijo


--  PREGUNTA 1.5 — ¿Cuál fue el precio que se pagó por esta seguridad?
--  Piense en una cuenta empresarial de recaudo que recibe cientos de
--  consignaciones por minuto.


--  Como tal afecta directamente el tiempo de espera, ya que mientras se bloquea una fila y se quiera hacer un cambio o algo se debe
--  esperar por lo que queda bloquead, ahora si nos sucede esto con cientos de consignaciones, se genera un bloqueo en cascada, y la posibiladad de haber interbloqueos.


-- #####################################################################
-- EJERCICIO 1.3 — Defensa optimista: columna de versión
--
-- Nadie bloquea nada. El choque se detecta al escribir.
-- #####################################################################

-- PASO 1  (A)  Reinicio
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta = 1001;
COMMIT;

-- PASO 2  (A)  Leo el saldo y la versión.  NO bloqueo nada.
SELECT id_cuenta, saldo, version FROM cuenta WHERE id_cuenta = 1001;
--> Anote la versión que ve. Debe ser 0.

-- ... conexión B, PASO 3: lee lo mismo y escribe PRIMERO ...

-- PASO 5  (A)  Intento escribir con la versión que leí
UPDATE cuenta
   SET saldo   = saldo - 300000,
       version = version + 1
 WHERE id_cuenta = 1001
   AND version   = 0;              -- <-- la versión que leí en el PASO 2
COMMIT;
--
--  Mire el mensaje: ¿cuántas filas actualizó?

-- PASO 6  (A)
SELECT id_cuenta, saldo, version FROM cuenta WHERE id_cuenta = 1001;
--
--  PREGUNTA 1.6 — Su UPDATE afectó 0 filas. ¿Qué debe hacer la
--  aplicación en ese momento, y qué NO debe hacer nunca?

--  RESPUESTA: se debe volver a realizar el conteo de filas y reintentar, si no hay un cambio informar que hubo un error o choque, pero no se debe 
--  ignorar el resultado y asumir que todo salio adecuadamenre


--  PREGUNTA 1.7 — Compare las dos defensas. ¿En qué producto del banco
--  usaría la pesimista y en cuál la optimista? Justifique con el nivel
--  de contención esperado, no con opiniones.


--  RESPUESTA: FOR UPDATE es mejor cuando se espera alta contencion sobre el mismo registro
--  pero las transacciones son cortas:
--  por ejemplo, el saldo de una cuenta transaccional de uso frecuente,
--  donde es más barato esperar un poco que reintentar constantemente.
--  mientras la otra version conviene cuando la contención es baja y cuando hay pasos 
--  intermedios largos (ej. el usuario revisa datos en pantalla antes de confirmar)
--  durante los cuales sería absurdo mantener un bloqueo abierto, esto quiere decir que ahi no es viable bloquear
--  "por si acaso" un recurso que probablemente nadie mas va a tocar.

-- #####################################################################
-- EJERCICIO 1.4 — Repartir la cola de compensación: SKIP LOCKED
--
-- Dos procesos de compensación toman transferencias de la misma cola.
-- No pueden procesar la misma dos veces, y no pueden quedarse esperando
-- el uno al otro: la ventana de compensación se cierra a una hora fija.
-- #####################################################################

-- PASO 1  (A)  Tomo 5 tareas y las marco como mías
SELECT id_tarea, id_transferencia
  FROM tarea_compensacion
 WHERE estado = 'PENDIENTE'
   AND ROWNUM <= 5
   FOR UPDATE SKIP LOCKED;
--  Nota de sintaxis: aquí se usa ROWNUM y no FETCH FIRST ... ROWS ONLY.
--  Oracle implementa FETCH FIRST como una vista en línea, y combinarlo
--  con FOR UPDATE devuelve ORA-02014. Para una cola de trabajo ROWNUM es
--  además lo correcto: no importa CUÁLES cinco tareas toma, importa que
--  sean cinco libres y que nadie más las tenga.
--> Anote los id_tarea que le tocaron.  NO confirme todavía.

-- ... conexión B, PASO 2: pide 5 tareas y recibe OTRAS distintas ...

-- PASO 3  (A)  Marco las mías como compensadas y libero
UPDATE tarea_compensacion
   SET estado = 'COMPENSADA', tomada_por = 'PROCESO_A', fecha_toma = SYSTIMESTAMP
 WHERE id_tarea IN (1,2,3,4,5);      -- <-- reemplace por los ids que le tocaron
COMMIT;

-- PASO 5  (A)  Verificación conjunta
SELECT tomada_por, COUNT(*) AS tareas
  FROM tarea_compensacion WHERE estado = 'COMPENSADA'
 GROUP BY tomada_por;
--
--  PREGUNTA 1.8 — ¿Qué habría pasado sin SKIP LOCKED? Describa los dos
--  comportamientos posibles según se use FOR UPDATE simple o NOWAIT.


--  RESPUESTA: Con FOR UPDATE simple el proceso b se quedaria esperando indefinidamente que A libere las filas bloqueadas,
--  con FOR UPDATE NOWAIT, b como tal no espera recibe  el error ORA-00054: resource busy, por lo que la consulta se debera reintentar despues.


--  PREGUNTA 1.9 — En una compensación real, procesar dos veces la misma
--  transferencia significa mover la plata dos veces. ¿Qué le garantiza
--  SKIP LOCKED que no le garantizaría un reparto hecho en la aplicación
--  con un "WHERE MOD(id,2) = 0" para un proceso y "= 1" para el otro?


--  El SKIP LOCKED lo que garantiza es que las tareas que se reparten están efectivamente libres en ese instante
--  no se toma una fila que otro porceso este usando o tenga bloqueada,

-- #####################################################################
-- EJERCICIO 1.5 — El bloqueo que nadie espera: FK sin índice
--
-- NOTIFICACION.ID_TRANSFERENCIA es llave foránea hacia TRANSFERENCIA
-- y NO está indexada.
-- #####################################################################

-- PASO 1  (A)  Registro la notificación de la transferencia 900001.
--   NO confirmo.
INSERT INTO notificacion (id_notificacion, id_transferencia, canal, enviada)
VALUES (9000001, 900001, 'SMS', 'S');

-- ... conexión B, PASO 2: intenta borrar la transferencia 900005, que no
--     tiene ninguna notificación ni ningún movimiento, y se queda esperando ...

-- PASO 3  (A)  Mientras B espera, mire el bloqueo.
--   TX = bloqueo de fila.  TM = bloqueo de TABLA.
SELECT l.sid, l.type,
       DECODE(l.lmode, 0,'ninguno',1,'null',2,'RS',3,'RX',4,'S',5,'SRX',6,'X') AS tiene,
       DECODE(l.request,0,'-',1,'null',2,'RS',3,'RX',4,'S',5,'SRX',6,'X')      AS pide
  FROM v$lock l JOIN v$session s ON s.sid = l.sid
 WHERE s.username = USER AND l.type IN ('TX','TM');
--> Si no tiene permisos sobre V$, el docente lo proyecta.

-- PASO 4  (A)  Libero
COMMIT;

-- PASO 6  (A)  Creo el índice que faltaba
CREATE INDEX ix_notif_transferencia ON notificacion (id_transferencia);

-- PASO 7  (A)  Repitan los pasos 1 y 2. Ahora B NO se bloquea.
--
--  PREGUNTA 1.10 — Explique por qué Oracle toma un bloqueo de TABLA sobre
--  el hijo cuando se borra un padre y la FK no está indexada.


--  RESPUESTA:  Al borrar un padre, Oracle debe verificar que ningun hijo
--  lo referencie, para no violar la integrida, si la FK del hijo no
--  esta indexada, no hay forma rapida de hacer esa búsqueda asi que tocaria
--  recorrer toda la tabla hijo, por lo cual mientras dura esa verificacion,
--  Oracle bloquea la TABLA hijo completa en vez de solo una fila: es su
--  forma de evitar que aparezcan hijos nuevos que invaliden el borrado
--  mientras este está en curso.


--  PREGUNTA 1.11 — Revise el esquema completo del Banco Andino. ¿Qué
--  OTRAS llaves foráneas están sin índice? ¿Cuáles de ellas son realmente
--  un problema en este negocio y cuáles no? Justifique pensando en qué
--  se borra y qué no se borra nunca en un banco.


--  RESPUESTA: En general, una FK sin indice es un problema real cuando la tabla hija participa en DELETE
--  o UPDATE frecuentes sobre la clave del padre, por ejemplo, transferencias o notificaciones ligadas 
--  a operaciones que sí se llegan a cancelar o corregir, no es un problema en tablas que solo se
--  insertan y nunca se borran ni se modifican, como el histórico de movimientos de un banco, donde el 
--  padre nunca se toca después de creado.


-- #####################################################################
-- EJERCICIO 1.6 — Interbloqueo: las dos transferencias cruzadas
--
-- Este es el caso clásico de la banca, y no es hipotético: ocurre todos
-- los días. Dos clientes se transfieren plata mutuamente al mismo tiempo.
-- #####################################################################

-- Antes de empezar, deje las dos cuentas en un valor conocido
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta IN (1001, 1002);
COMMIT;

-- PASO 1  (A)  Transferencia de la 1001 a la 1002: primero debito el origen
UPDATE cuenta SET saldo = saldo - 50000 WHERE id_cuenta = 1001;

-- ... conexión B, PASO 2: hace la transferencia inversa, 1002 -> 1001,
--     y debita PRIMERO la 1002 ...

-- PASO 3  (A)  Ahora acredito el destino: la cuenta 1002, que B ya tiene
UPDATE cuenta SET saldo = saldo + 50000 WHERE id_cuenta = 1002;
--> Me quedo esperando.

-- ... conexión B, PASO 4: pide la 1001, que yo tengo -> ciclo cerrado ...

--> En segundos, UNA de las dos recibe:
--     ORA-00060: deadlock detected while waiting for resource

ROLLBACK;
--
--  PREGUNTA 1.12 — Oracle abortó UNA sentencia, no la transacción
--  completa. ¿En qué estado queda la sesión víctima y qué debe hacer?
--  ¿Qué pasa si la aplicación asume que Oracle deshizo todo?


--  RESPUESTA. La sesión víctima recibe el error ORA-00060, pero solo
--  se aborta esa sentencia, la transacción sigue abierta con los
--  cambios anteriores sin confirmar, la aplicacion debe capturar ese
--  error y hacer ROLLBACK ella misma, se asume que Oracle ya deshizo
--  todo y sigue adelante sin hacerlo, la transacción puede quedar
--  abierta bloqueando recursos, o confirmarse por error con datos
--  incompletos.


--  PREGUNTA 1.13 — Escriba la regla de diseño, en una frase, que habría
--  hecho imposible este interbloqueo. Después dígala en términos de
--  código: ¿qué línea concreta hay que agregar antes de los dos UPDATE?


--  RESPUESTA: Se podria siempre bloquear los recursos en un mismo orden,
--  sin importar cual sea el origen y cual el destino, por ejemplo,
--  siempre por id_cuenta de menor a mayor tipo en codigo: antes de los dos
--  UPDATE, agregar una validacion que ordene las cuentas (ej. si
--  id_origen > id_destino, intercambiarlas) para que ambas
--  transacciones toquen primero la misma cuenta, sin importar el
--  sentido de la transferencia.



-- =====================================================================
-- Bases de Datos 2 · Taller integrador — Banco Andino
-- 02_indices.sql   Índices y optimización de consultas
--
-- IMPORTANTE: de aquí en adelante trabajen en UNA SOLA CONEXIÓN.
-- La pareja comparte el mismo esquema, y dos personas creando índices o
-- insertando en la misma tabla al mismo tiempo se bloquean entre sí.
-- Uno maneja el teclado, los dos discuten y anotan.
--
-- Ejecute bloque por bloque con Ctrl+Enter.
-- =====================================================================

SET TIMING ON
SET LINESIZE 200
SET PAGESIZE 1000

-- ---------------------------------------------------------------------
-- CÓMO VAMOS A MEDIR
--
-- En SQL Developer tiene tres herramientas. Úselas todas:
--
--   F10  Explain Plan   -> el plan que el optimizador PIENSA usar.
--                          No ejecuta la consulta. Es una estimación.
--   F6   Autotrace      -> ejecuta la consulta y muestra el plan REAL
--                          más las estadísticas de sesión.
--   F5   Run Script     -> para los bloques con SET TIMING.
--
-- Las dos cifras que importan:
--   COST            estimación del optimizador (sirve para comparar)
--   consistent gets bloques leídos de verdad (esta es la que no miente)
--
-- También puede pedir el plan por texto, así:
-- ---------------------------------------------------------------------

EXPLAIN PLAN FOR
SELECT COUNT(*) FROM transferencia WHERE estado = 'APLICADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));


-- #####################################################################
-- EJERCICIO 2.1 — El informe de la Superintendencia
--
-- Todos los meses hay que reportar el valor y el número de
-- transferencias efectivamente aplicadas del mes anterior.
-- #####################################################################

-- PASO 1  Ejecute la consulta y mida
SELECT COUNT(*)          AS operaciones,
       SUM(valor)        AS valor_total,
       ROUND(AVG(valor)) AS ticket_promedio
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

-- PASO 2  Vea el plan
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor)
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS +PREDICATE'));
--
--  ANOTE:  operación = TABLE ACCESS FULL   COST = 377   filas = 5427

--  PREGUNTA 2.1 — La tabla tiene 200.000 filas y la consulta devuelve
--  unos pocos miles. ¿Por qué el optimizador está leyendo la tabla
--  completa? ¿Es un error del optimizador?

--El optimizador esta leyendo toda la tabla (TABLE ACCES FULL) ya que fecha_transf no es un indice, 
--lo cual obliga a  hacer el acceso completo a la tabla y filtrar por la fecha de transferencia, No es un error del optimizador, usa la ruta mas optima

-- PASO 3  Cree el índice
CREATE INDEX idx_transf_fecha_estado ON transferencia (fecha_transf, estado);

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);

-- PASO 4  Repita la medición
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor)
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS '));

--
--  ANOTE:  operación = TABLE ACCESS FULL  COST = 377
--
--  PREGUNTA 2.2 — ¿Cuánto bajó el COST? Ejecute también con F6
--  (Autotrace) antes y después y compare los "consistent gets".
--No hubo cambio en COST ya que se sigue haciendo acceso completo a la tabla, ademas tambien los "consistent gets" tienen el mismo valor
--el optmizador no usa el indice para acceder a la tabla

-- PASO 5  El orden de las columnas SÍ importa
CREATE INDEX idx_transf_estado_fecha ON transferencia (estado, fecha_transf);

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);

-- Fuerce cada índice y compare
EXPLAIN PLAN FOR
SELECT /*+ INDEX(t idx_transf_fecha_estado) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS +predicate'));


SELECT /*+ INDEX(t idx_transf_estado_fecha) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

--
--  PREGUNTA 2.3 — ¿Cuál de los dos índices elige el optimizador cuando
--  no se le fuerza nada? Compare el COST de los dos SELECT anteriores.
--  Formule la regla general sobre el orden de columnas en un índice
--  compuesto, distinguiendo el predicado de IGUALDAD del de RANGO.
--
--  Cuando no se le fuerza nada el optimizador utiliza el indice que tiene primero el estado. 
--  En un indice compuesto la columna que se va a usar como predicado de igualdad va primero  y la columna que se va a usar como predicado de rango debe ir ultima 
--  ya que la IGUALDAD permite ir directamente a la hoja exacta del indice, el RANGO delimita un tramo que se lee completo.
--  si el RANGO va primero la columna de IGUALDAD se toma como un filtro (Filter predicate).

--  PREGUNTA 2.4 — Suponga ahora que existe además un informe diario que
--  filtra SOLO por rango de fechas, sin estado. ¿Cuál de los dos índices
--  le sirve a ese informe y cuál no? ¿Cambia eso su recomendación?
--  Responda cuál de los dos conservaría en producción y por qué.
-- 
--El indice en el que la primera columna es la fecha le sirve a este nuevo informe, el que inicia por estado sirve pero su costo es mucho mayor,
--Ya que al buscar un rango por la primera columna de un indice compuesto , el motor va directo a ese rango,
--pero si la columna con la que se quiere buscar esta despues de otra que no se utiliza en la consulta, recorre la primera columna completa.
--Con esto en mente en produccion conservaria "idx_transf_fecha_estado" ya que para el primer caso el costo aumenta pero no demasiado usando este indice, a comparacion 
--de cuando se usa el indice "idx_transf_estado_fecha". En el segundo caso ocurre que al usar "idx_transf_fecha_estado" el costo es significativamente menor 
--a cuando se usa "idx_transf_estado_fecha". Por esto es mejor mantener el indice que cuando es peor, la diferencia de costo no es muy elevada

--PRUEBA SIN ESTADO
SELECT /*+ INDEX(t idx_transf_fecha_estado) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01';

SELECT /*+ INDEX(t idx_transf_estado_fecha) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01';

-- Para el resto del taller trabajamos con IX_TRANSF_FECHA_ESTADO,
-- para no multiplicar índices. Su recomendación va en la entrega.
DROP INDEX idx_transf_estado_fecha;


-- #####################################################################
-- EJERCICIO 2.2 — El índice que existe y no se usa
--
-- El área de servicio al cliente busca por nombre y se queja de que la
-- pantalla de consulta se demora.
-- #####################################################################


-- PASO 1  Sin índice
EXPLAIN PLAN FOR
SELECT id_cliente, nombre, ciudad, segmento
  FROM cliente WHERE UPPER(nombre) = 'MARCELA ROJAS 4004';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));

-- PASO 2  Creo el índice "obvio"
CREATE INDEX idx_cliente_nombre ON cliente (nombre);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', cascade => TRUE);

EXPLAIN PLAN FOR
SELECT id_cliente, nombre, ciudad, segmento
  FROM cliente WHERE UPPER(nombre) = 'MARCELA ROJAS 4004';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--
--  PREGUNTA 2.5 — El índice existe y sigue haciendo FULL SCAN.
--  ¿Por qué? ¿Qué le hizo la consulta a la columna indexada?
--
--Se  sigue haciendo FULL SCAN porque "nombre" esta dentro de una funcion (UPPER) 
--por lo que el motor no lo toma como un indice.

-- PASO 3  El índice que sí sirve
CREATE INDEX idx_cliente_nombre_upper ON cliente (UPPER(nombre));
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', cascade => TRUE);

EXPLAIN PLAN FOR
SELECT id_cliente, nombre, ciudad, segmento
  FROM cliente WHERE UPPER(nombre) = 'MARCELA ROJAS 4004';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));

-- PASO 4  El mismo error, con fechas.  Este es el más común de todos,
--   y en banca aparece en cada extracto y en cada corte diario.
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM transferencia WHERE TRUNC(fecha_transf) = DATE '2026-03-15';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));

EXPLAIN PLAN FOR
SELECT COUNT(*) FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-15'
   AND fecha_transf <  DATE '2026-03-16';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--
--  PREGUNTA 2.6 — Las dos consultas devuelven exactamente lo mismo.
--  Compare los planes. Escriba la regla, en una frase, que todo
--  desarrollador debería tener presente al filtrar por fecha.
--
--El costo es bastante menor cuando no se utiliza la funcion "TRUNC()" y se hace un rango entre dos fechas.
-- Como regla al filtrar por columnas con tipo de dato fecha que tengan un indice, no se debe utilizar funciones
-- sobre estas columnas en el "WHERE", es mejor usar un rango, ya que el rango deja la columna intacta y permite que se use el indice

-- #####################################################################
-- EJERCICIO 2.3 — Cuándo NO conviene un índice
-- #####################################################################

-- PASO 1  Un filtro que devuelve el 62% de la tabla
CREATE INDEX idx_transf_estado ON transferencia (estado);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);


EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor) FROM transferencia WHERE estado = 'APLICADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));

-- PASO 2  El mismo índice, con un valor poco frecuente
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor) FROM transferencia WHERE estado = 'REVERSADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));

--Prueba forzando el uso del indice, para comparar costos (usando el indice el costo es mayor).
EXPLAIN PLAN FOR
SELECT  /*+ INDEX(transferencia idx_transf_estado) */ COUNT(*), SUM(valor) FROM transferencia WHERE estado = 'REVERSADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));


--
--  PREGUNTA 2.7 — El mismo índice, la misma consulta, distinto valor:
--  en un caso se usa y en el otro no. ¿Cómo lo sabe el optimizador?
--  ¿Qué información necesita para tomar esa decisión?
--
--En ambos casos no usa el indice, ya que el costo es mayor si usa el indice y despues accede a cada fila,
--a que si se hace un escaneo completo de la tabla
--
--  PREGUNTA 2.8 — Consulte la selectividad y el clustering factor:
--
--selectividad muy baja 0.25 y clustering factor bajo 5273 de 199985 filas

SELECT column_name, num_distinct, num_nulls, density
  FROM user_tab_col_statistics
 WHERE table_name = 'TRANSFERENCIA'
   AND column_name IN ('ESTADO','FECHA_TRANSF','CUENTA_ORIGEN','CANAL');

SELECT index_name, num_rows, distinct_keys, clustering_factor, blevel, leaf_blocks
  FROM user_indexes WHERE table_name = 'TRANSFERENCIA';

--
--  ¿Qué le dice el CLUSTERING FACTOR de IX_TRANSF_FECHA_ESTADO comparado
--  con el de IX_TRANSF_ESTADO? ¿Por qué son tan distintos?
--
--el CLUSTERING FACTOR de ambos indices son tan diferentes ya que ESTADO se encuentra agrupado por bloques, mientras que en
--FECHA_TRANSF cada fila tiene un bloque distinto por los valores tan distintos de la columna.

-- #####################################################################
-- EJERCICIO 2.4 — El índice que evita tocar la tabla
-- #####################################################################

-- PASO 1  Cuentas más activas del trimestre
EXPLAIN PLAN FOR
SELECT cuenta_origen, COUNT(*) AS operaciones
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-01-01'
   AND fecha_transf <  DATE '2026-04-01'
 GROUP BY cuenta_origen;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--> Fíjese: hay INDEX RANGE SCAN y ADEMÁS TABLE ACCESS BY INDEX ROWID.

-- PASO 2  Agrego la columna que falta al índice
CREATE INDEX idx_transf_fecha_origen ON transferencia (fecha_transf, cuenta_origen);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);

EXPLAIN PLAN FOR
SELECT cuenta_origen, COUNT(*) AS operaciones
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-01-01'
   AND fecha_transf <  DATE '2026-04-01'
 GROUP BY cuenta_origen;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--
--  PREGUNTA 2.9 — Desapareció el TABLE ACCESS. ¿Cómo se llama esta
--  técnica y por qué es tan efectiva? ¿Cuál es su límite: hasta dónde
--  tiene sentido seguir agregando columnas al índice?
--
--La tecnica se llama "covering index", consiste en tener todas las columnas que una consulta necesita en un mismo indice.
--Es bastante efectivo ya que la cantidad de columnas es menor a la de la tabla, haciendolo mejor a un FULL SCAN
--Tiene sentido seguir agregando columnas hasta el punto en que un acceso completo a la tabla tiene un costo no muy significativo 
--en relacion a cuando se usa el indice, el indice entre mas grande, mas almacenamiento consume y dificulta las sentencias DML    

-- #####################################################################
-- EJERCICIO 2.5 — Lo que cuesta un índice
--
-- Hasta aquí solo hemos visto el beneficio. Ahora el precio.
-- #####################################################################

-- PASO 1  Cuántos índices tiene TRANSFERENCIA en este momento
SELECT index_name, leaf_blocks,
       ROUND(leaf_blocks * 8192 / 1024 / 1024, 2) AS mb_aprox
  FROM user_indexes WHERE table_name = 'TRANSFERENCIA';

-- PASO 2  Inserte 50.000 transferencias CON todos los índices y mida
--   (ejecute este bloque con F5 para ver el TIMING)
SET TIMING ON
INSERT INTO transferencia
  (id_transferencia, cuenta_origen, cuenta_destino, fecha_transf, valor, canal, estado)
SELECT 1000000 + LEVEL,
       MOD(LEVEL, 15000) + 1,
       MOD(LEVEL, 15000) + 15001,
       DATE '2026-06-01' + MOD(LEVEL,30), 100000, 'APP', 'REGISTRADA'
  FROM dual CONNECT BY LEVEL <= 50000;
COMMIT;
--> Anote el tiempo: 00:00:02.430

-- PASO 3  Ahora sin índices secundarios
DROP INDEX idx_transf_fecha_estado;
DROP INDEX idx_transf_estado;
DROP INDEX idx_transf_fecha_origen;

INSERT INTO transferencia
  (id_transferencia, cuenta_origen, cuenta_destino, fecha_transf, valor, canal, estado)
SELECT 2000000 + LEVEL,
       MOD(LEVEL, 15000) + 1,
       MOD(LEVEL, 15000) + 15001,
       DATE '2026-06-01' + MOD(LEVEL,30), 100000, 'APP', 'REGISTRADA'
  FROM dual CONNECT BY LEVEL <= 50000;
COMMIT;
--> Anote el tiempo: 00:00:00.381

-- PASO 4  Deje el esquema como debe quedar
DELETE FROM transferencia WHERE id_transferencia >= 1000000;
COMMIT;

CREATE INDEX ix_transf_fecha_estado ON transferencia (fecha_transf, estado);
CREATE INDEX ix_transf_fecha_origen ON transferencia (fecha_transf, cuenta_origen);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);
--
--  PREGUNTA 2.10 — ¿Cuál fue la diferencia de tiempo? Extrapole:
--  el Banco Andino procesa 12.000 transferencias por hora en hora pico.
--  ¿Qué costo operativo tiene cada índice que se agrega "por si acaso"?
--
--La diferencia de tiempo fue de 2.049 segundos 
-- Cada indice tiene un costo operativo muy grande, el volumen de escrituras por hora 
-- y los indices que se tienen genera un tiempo mayor a sino se tuvieran, es necesario mantener unicamente los indice
--mas usados




--  PREGUNTA 2.11 — Proponga la lista DEFINITIVA de índices para este
--  esquema. Para cada uno escriba: qué consulta lo justifica, y por qué
--  no se puede resolver con otro índice ya existente. Tenga en cuenta
--  que TRANSFERENCIA tiene DOS llaves foráneas hacia CUENTA.
--
--"IDX_TRANSF_FECHA_ESTADO" para la consulta 
    /*SELECT COUNT(*)
      FROM transferencia t
     WHERE fecha_transf >= DATE '2026-03-01'
       AND fecha_transf <  DATE '2026-04-01'
       AND estado        = 'APLICADA'; o
    SELECT  COUNT(*)
      FROM transferencia t
     WHERE fecha_transf >= DATE '2026-03-01'
       AND fecha_transf <  DATE '2026-04-01'*/
--Es el unico orden del indice que sigue funcionando cuando no se filtra tambien por estado,
-- solo por fecha que es la columna mas usada
--"IDX_TRANSF_FECHA_ORIGEN" para la consulta
    /*SELECT cuenta_origen, COUNT(*) AS operaciones
      FROM transferencia
    WHERE fecha_transf >= DATE '2026-01-01'
       AND fecha_transf <  DATE '2026-04-01'
    GROUP BY cuenta_origen; */
--Unico indice que tiene cuenta_origen

-- Es necesario tambien tener un indice por cada llave foranea "IDX_TRANSF_CUENTA_ORIGEN" y "IDX_TRANSF_CUENTA_DESTINO"
    


-- =====================================================================
-- Bases de Datos 2 · Taller integrador — Banco Andino
-- 01_sesion_A.sql        >>>  CONEXIÓN A  <<<   (cajero A)
--
-- NO ejecute este archivo de corrido. Cada bloque dice PASO n:
-- ejecútelo con Ctrl+Enter cuando le toque, alternando con la conexión B.
--
-- ANTES DE EMPEZAR, verifique:
--   1. Autocommit APAGADO
--      Herramientas > Preferencias > Base de datos > Avanzado > Autoconfirmar
--      (debe estar DESMARCADO)
--   2. Dos CONEXIONES distintas, no dos hojas sobre la misma conexión.
-- =====================================================================

SELECT 'CONEXIÓN A' AS ventana, SYS_CONTEXT('USERENV','SID') AS sid FROM dual;


-- #####################################################################
-- EJERCICIO 1.1 — El retiro que se pierde (actualización perdida)
--
-- Escenario: el mismo cliente retira por el cajero automático mientras
-- su empresa le hace un débito automático. Las dos operaciones leen el
-- saldo, restan en memoria y escriben el resultado. Es lo que hace la
-- mayoría del código que ustedes van a encontrar en producción.
--
-- Cuenta 1001, saldo inicial 1.000.000.
-- #####################################################################

-- PASO 1  (A)  Estado inicial
SELECT id_cuenta, saldo, saldo_retenido, version
  FROM cuenta WHERE id_cuenta = 1001;
--> Anote el SALDO. Debe ser 1.000.000.

-- PASO 2  (A)  "El cajero" leyó 1.000.000 y calculó 1.000.000 - 300.000
UPDATE cuenta SET saldo = 700000 WHERE id_cuenta = 1001;
--  NO confirme todavía.

-- ... vaya a la conexión B, PASO 3 ...

-- PASO 5  (A)  Confirmo mi retiro de 300.000
COMMIT;

-- ... conexión B, PASO 6 ...

-- PASO 8  (A)  ¿Cuánto saldo quedó?
SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta = 1001;
--
--  PREGUNTA 1.1 — Salieron 300.000 (A) más 200.000 (B) = 500.000 de
--  1.000.000. Deberían quedar 500.000. ¿Cuántos quedan? ¿Quién "ganó"?
--  ¿Hubo algún error, alguna advertencia, algún registro de que algo
--  salió mal?


--  Respuesta: No, quedan 800.000, ya que la parte B hizo update de ultimas, por lo cual
--  el resultado va a ser el que B haya dicho en este caso 800.000.
--  No hay error o advertencia ya que realmente todo se manejo de forma valida, para la base de datos
--  todo se realizo de forma adecuada.
--  frente a la situación gana el cliente ya que nunca se desconto o se resto la cantidad real, peride el banco.


--  PREGUNTA 1.2 — El bloqueo de fila SÍ funcionó: B esperó a que A
--  confirmara. Explique entonces por qué el banco perdió dinero de todos
--  modos.


--  RESPUESTA: Esto sucede ya que el bloqueo evita que se escriba al mismo tiempo, pero al momento de realizarlo ambos leyeron el valor incial
--  Al leer el valor antes de confirmar un cambio, todo se realizo en base a ese, en pocas palabras A y B empezaron, A y B leyeron lo mismo,
--  A actualizo pero B tambien actualizo sobre el valor leido y reemplazo lo que A habia hecho.


--  PREGUNTA 1.3 — En un marketplace este error vende una unidad de más.
--  En un banco, ¿de quién es la plata que se acaba de crear de la nada,
--  y quién la va a reclamar?


--  RESPUESTA: Los 300.000 que no aparecnieron del retiro de A nunca llegaron a descontarse del saldo final,
--  es dinero que el banco cree que ya no tiene el cliente, pero que el cliente si tiene,  es el
--  banco el que pierde esa plata y es el banco quien debe ir a reclamar 

-- #####################################################################
-- EJERCICIO 1.2 — Defensa pesimista: SELECT ... FOR UPDATE
-- #####################################################################

-- PASO 1  (A)  Dejo la cuenta en un valor conocido
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta = 1001;
COMMIT;

-- PASO 2  (A)  Leo Y bloqueo en la misma operación
SELECT id_cuenta, saldo
  FROM cuenta
 WHERE id_cuenta = 1001
   FOR UPDATE;

-- ... conexión B, PASO 3 ...

-- PASO 5  (A)  Descuento mis 300.000 y libero
UPDATE cuenta SET saldo = saldo - 300000 WHERE id_cuenta = 1001;
COMMIT;

-- ... conexión B, PASO 6 ...

-- PASO 8  (A)  Resultado
SELECT id_cuenta, saldo FROM cuenta WHERE id_cuenta = 1001;
--
--  PREGUNTA 1.4 — Ahora sí quedan 500.000. ¿Qué dos cosas cambiaron
--  respecto al ejercicio anterior? (pista: una es el FOR UPDATE, la otra
--  está dentro del UPDATE mismo)


--  Si, en el For UPDATE del paso 2 cambio,, ya que hace que A tome el bloqueo de la fila en el momento de leer, no cuando se esta escribiendo
--  lo que nos dice que B queda bloqueado desde el el SELECT FOR UPDATE, ya que este asegura que los datos no cambien entre el momento en que se lee y el momento en que se actualiza
--  y en el UPDATE, se esta realizando una cuenta "- 200000" no se esta escribiendo el valor de uan, por lo cual se va a realizar sobre el valor que haya no sobre uno fijo


--  PREGUNTA 1.5 — ¿Cuál fue el precio que se pagó por esta seguridad?
--  Piense en una cuenta empresarial de recaudo que recibe cientos de
--  consignaciones por minuto.


--  Como tal afecta directamente el tiempo de espera, ya que mientras se bloquea una fila y se quiera hacer un cambio o algo se debe
--  esperar por lo que queda bloquead, ahora si nos sucede esto con cientos de consignaciones, se genera un bloqueo en cascada, y la posibiladad de haber interbloqueos.


-- #####################################################################
-- EJERCICIO 1.3 — Defensa optimista: columna de versión
--
-- Nadie bloquea nada. El choque se detecta al escribir.
-- #####################################################################

-- PASO 1  (A)  Reinicio
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta = 1001;
COMMIT;

-- PASO 2  (A)  Leo el saldo y la versión.  NO bloqueo nada.
SELECT id_cuenta, saldo, version FROM cuenta WHERE id_cuenta = 1001;
--> Anote la versión que ve. Debe ser 0.

-- ... conexión B, PASO 3: lee lo mismo y escribe PRIMERO ...

-- PASO 5  (A)  Intento escribir con la versión que leí
UPDATE cuenta
   SET saldo   = saldo - 300000,
       version = version + 1
 WHERE id_cuenta = 1001
   AND version   = 0;              -- <-- la versión que leí en el PASO 2
COMMIT;
--
--  Mire el mensaje: ¿cuántas filas actualizó?

-- PASO 6  (A)
SELECT id_cuenta, saldo, version FROM cuenta WHERE id_cuenta = 1001;
--
--  PREGUNTA 1.6 — Su UPDATE afectó 0 filas. ¿Qué debe hacer la
--  aplicación en ese momento, y qué NO debe hacer nunca?

--  RESPUESTA: se debe volver a realizar el conteo de filas y reintentar, si no hay un cambio informar que hubo un error o choque, pero no se debe 
--  ignorar el resultado y asumir que todo salio adecuadamenre


--  PREGUNTA 1.7 — Compare las dos defensas. ¿En qué producto del banco
--  usaría la pesimista y en cuál la optimista? Justifique con el nivel
--  de contención esperado, no con opiniones.


--  RESPUESTA: FOR UPDATE es mejor cuando se espera alta contencion sobre el mismo registro
--  pero las transacciones son cortas:
--  por ejemplo, el saldo de una cuenta transaccional de uso frecuente,
--  donde es más barato esperar un poco que reintentar constantemente.
--  mientras la otra version conviene cuando la contención es baja y cuando hay pasos 
--  intermedios largos (ej. el usuario revisa datos en pantalla antes de confirmar)
--  durante los cuales sería absurdo mantener un bloqueo abierto, esto quiere decir que ahi no es viable bloquear
--  "por si acaso" un recurso que probablemente nadie mas va a tocar.

-- #####################################################################
-- EJERCICIO 1.4 — Repartir la cola de compensación: SKIP LOCKED
--
-- Dos procesos de compensación toman transferencias de la misma cola.
-- No pueden procesar la misma dos veces, y no pueden quedarse esperando
-- el uno al otro: la ventana de compensación se cierra a una hora fija.
-- #####################################################################

-- PASO 1  (A)  Tomo 5 tareas y las marco como mías
SELECT id_tarea, id_transferencia
  FROM tarea_compensacion
 WHERE estado = 'PENDIENTE'
   AND ROWNUM <= 5
   FOR UPDATE SKIP LOCKED;
--  Nota de sintaxis: aquí se usa ROWNUM y no FETCH FIRST ... ROWS ONLY.
--  Oracle implementa FETCH FIRST como una vista en línea, y combinarlo
--  con FOR UPDATE devuelve ORA-02014. Para una cola de trabajo ROWNUM es
--  además lo correcto: no importa CUÁLES cinco tareas toma, importa que
--  sean cinco libres y que nadie más las tenga.
--> Anote los id_tarea que le tocaron.  NO confirme todavía.

-- ... conexión B, PASO 2: pide 5 tareas y recibe OTRAS distintas ...

-- PASO 3  (A)  Marco las mías como compensadas y libero
UPDATE tarea_compensacion
   SET estado = 'COMPENSADA', tomada_por = 'PROCESO_A', fecha_toma = SYSTIMESTAMP
 WHERE id_tarea IN (1,2,3,4,5);      -- <-- reemplace por los ids que le tocaron
COMMIT;

-- PASO 5  (A)  Verificación conjunta
SELECT tomada_por, COUNT(*) AS tareas
  FROM tarea_compensacion WHERE estado = 'COMPENSADA'
 GROUP BY tomada_por;
--
--  PREGUNTA 1.8 — ¿Qué habría pasado sin SKIP LOCKED? Describa los dos
--  comportamientos posibles según se use FOR UPDATE simple o NOWAIT.


--  RESPUESTA: Con FOR UPDATE simple el proceso b se quedaria esperando indefinidamente que A libere las filas bloqueadas,
--  con FOR UPDATE NOWAIT, b como tal no espera recibe  el error ORA-00054: resource busy, por lo que la consulta se debera reintentar despues.


--  PREGUNTA 1.9 — En una compensación real, procesar dos veces la misma
--  transferencia significa mover la plata dos veces. ¿Qué le garantiza
--  SKIP LOCKED que no le garantizaría un reparto hecho en la aplicación
--  con un "WHERE MOD(id,2) = 0" para un proceso y "= 1" para el otro?


--  El SKIP LOCKED lo que garantiza es que las tareas que se reparten están efectivamente libres en ese instante
--  no se toma una fila que otro porceso este usando o tenga bloqueada,

-- #####################################################################
-- EJERCICIO 1.5 — El bloqueo que nadie espera: FK sin índice
--
-- NOTIFICACION.ID_TRANSFERENCIA es llave foránea hacia TRANSFERENCIA
-- y NO está indexada.
-- #####################################################################

-- PASO 1  (A)  Registro la notificación de la transferencia 900001.
--   NO confirmo.
INSERT INTO notificacion (id_notificacion, id_transferencia, canal, enviada)
VALUES (9000001, 900001, 'SMS', 'S');

-- ... conexión B, PASO 2: intenta borrar la transferencia 900005, que no
--     tiene ninguna notificación ni ningún movimiento, y se queda esperando ...

-- PASO 3  (A)  Mientras B espera, mire el bloqueo.
--   TX = bloqueo de fila.  TM = bloqueo de TABLA.
SELECT l.sid, l.type,
       DECODE(l.lmode, 0,'ninguno',1,'null',2,'RS',3,'RX',4,'S',5,'SRX',6,'X') AS tiene,
       DECODE(l.request,0,'-',1,'null',2,'RS',3,'RX',4,'S',5,'SRX',6,'X')      AS pide
  FROM v$lock l JOIN v$session s ON s.sid = l.sid
 WHERE s.username = USER AND l.type IN ('TX','TM');
--> Si no tiene permisos sobre V$, el docente lo proyecta.

-- PASO 4  (A)  Libero
COMMIT;

-- PASO 6  (A)  Creo el índice que faltaba
CREATE INDEX ix_notif_transferencia ON notificacion (id_transferencia);

-- PASO 7  (A)  Repitan los pasos 1 y 2. Ahora B NO se bloquea.
--
--  PREGUNTA 1.10 — Explique por qué Oracle toma un bloqueo de TABLA sobre
--  el hijo cuando se borra un padre y la FK no está indexada.


--  RESPUESTA:  Al borrar un padre, Oracle debe verificar que ningun hijo
--  lo referencie, para no violar la integrida, si la FK del hijo no
--  esta indexada, no hay forma rapida de hacer esa búsqueda asi que tocaria
--  recorrer toda la tabla hijo, por lo cual mientras dura esa verificacion,
--  Oracle bloquea la TABLA hijo completa en vez de solo una fila: es su
--  forma de evitar que aparezcan hijos nuevos que invaliden el borrado
--  mientras este está en curso.


--  PREGUNTA 1.11 — Revise el esquema completo del Banco Andino. ¿Qué
--  OTRAS llaves foráneas están sin índice? ¿Cuáles de ellas son realmente
--  un problema en este negocio y cuáles no? Justifique pensando en qué
--  se borra y qué no se borra nunca en un banco.


--  RESPUESTA: En general, una FK sin indice es un problema real cuando la tabla hija participa en DELETE
--  o UPDATE frecuentes sobre la clave del padre, por ejemplo, transferencias o notificaciones ligadas 
--  a operaciones que sí se llegan a cancelar o corregir, no es un problema en tablas que solo se
--  insertan y nunca se borran ni se modifican, como el histórico de movimientos de un banco, donde el 
--  padre nunca se toca después de creado.


-- #####################################################################
-- EJERCICIO 1.6 — Interbloqueo: las dos transferencias cruzadas
--
-- Este es el caso clásico de la banca, y no es hipotético: ocurre todos
-- los días. Dos clientes se transfieren plata mutuamente al mismo tiempo.
-- #####################################################################

-- Antes de empezar, deje las dos cuentas en un valor conocido
UPDATE cuenta SET saldo = 1000000, version = 0 WHERE id_cuenta IN (1001, 1002);
COMMIT;

-- PASO 1  (A)  Transferencia de la 1001 a la 1002: primero debito el origen
UPDATE cuenta SET saldo = saldo - 50000 WHERE id_cuenta = 1001;

-- ... conexión B, PASO 2: hace la transferencia inversa, 1002 -> 1001,
--     y debita PRIMERO la 1002 ...

-- PASO 3  (A)  Ahora acredito el destino: la cuenta 1002, que B ya tiene
UPDATE cuenta SET saldo = saldo + 50000 WHERE id_cuenta = 1002;
--> Me quedo esperando.

-- ... conexión B, PASO 4: pide la 1001, que yo tengo -> ciclo cerrado ...

--> En segundos, UNA de las dos recibe:
--     ORA-00060: deadlock detected while waiting for resource

ROLLBACK;
--
--  PREGUNTA 1.12 — Oracle abortó UNA sentencia, no la transacción
--  completa. ¿En qué estado queda la sesión víctima y qué debe hacer?
--  ¿Qué pasa si la aplicación asume que Oracle deshizo todo?


--  RESPUESTA. La sesión víctima recibe el error ORA-00060, pero solo
--  se aborta esa sentencia, la transacción sigue abierta con los
--  cambios anteriores sin confirmar, la aplicacion debe capturar ese
--  error y hacer ROLLBACK ella misma, se asume que Oracle ya deshizo
--  todo y sigue adelante sin hacerlo, la transacción puede quedar
--  abierta bloqueando recursos, o confirmarse por error con datos
--  incompletos.


--  PREGUNTA 1.13 — Escriba la regla de diseño, en una frase, que habría
--  hecho imposible este interbloqueo. Después dígala en términos de
--  código: ¿qué línea concreta hay que agregar antes de los dos UPDATE?


--  RESPUESTA: Se podria siempre bloquear los recursos en un mismo orden,
--  sin importar cual sea el origen y cual el destino, por ejemplo,
--  siempre por id_cuenta de menor a mayor tipo en codigo: antes de los dos
--  UPDATE, agregar una validacion que ordene las cuentas (ej. si
--  id_origen > id_destino, intercambiarlas) para que ambas
--  transacciones toquen primero la misma cuenta, sin importar el
--  sentido de la transferencia.


-- =====================================================================
-- Bases de Datos 2 · Taller integrador — Banco Andino
-- 02_indices.sql   Índices y optimización de consultas
--
-- IMPORTANTE: de aquí en adelante trabajen en UNA SOLA CONEXIÓN.
-- La pareja comparte el mismo esquema, y dos personas creando índices o
-- insertando en la misma tabla al mismo tiempo se bloquean entre sí.
-- Uno maneja el teclado, los dos discuten y anotan.
--
-- Ejecute bloque por bloque con Ctrl+Enter.
-- =====================================================================

SET TIMING ON
SET LINESIZE 200
SET PAGESIZE 1000

-- ---------------------------------------------------------------------
-- CÓMO VAMOS A MEDIR
--
-- En SQL Developer tiene tres herramientas. Úselas todas:
--
--   F10  Explain Plan   -> el plan que el optimizador PIENSA usar.
--                          No ejecuta la consulta. Es una estimación.
--   F6   Autotrace      -> ejecuta la consulta y muestra el plan REAL
--                          más las estadísticas de sesión.
--   F5   Run Script     -> para los bloques con SET TIMING.
--
-- Las dos cifras que importan:
--   COST            estimación del optimizador (sirve para comparar)
--   consistent gets bloques leídos de verdad (esta es la que no miente)
--
-- También puede pedir el plan por texto, así:
-- ---------------------------------------------------------------------

EXPLAIN PLAN FOR
SELECT COUNT(*) FROM transferencia WHERE estado = 'APLICADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));


-- #####################################################################
-- EJERCICIO 2.1 — El informe de la Superintendencia
--
-- Todos los meses hay que reportar el valor y el número de
-- transferencias efectivamente aplicadas del mes anterior.
-- #####################################################################

-- PASO 1  Ejecute la consulta y mida
SELECT COUNT(*)          AS operaciones,
       SUM(valor)        AS valor_total,
       ROUND(AVG(valor)) AS ticket_promedio
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

-- PASO 2  Vea el plan
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor)
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS +PREDICATE'));
--
--  ANOTE:  operación = TABLE ACCESS FULL   COST = 377   filas = 5427

--  PREGUNTA 2.1 — La tabla tiene 200.000 filas y la consulta devuelve
--  unos pocos miles. ¿Por qué el optimizador está leyendo la tabla
--  completa? ¿Es un error del optimizador?

--El optimizador esta leyendo toda la tabla (TABLE ACCES FULL) ya que fecha_transf no es un indice, 
--lo cual obliga a  hacer el acceso completo a la tabla y filtrar por la fecha de transferencia, No es un error del optimizador, usa la ruta mas optima

-- PASO 3  Cree el índice
CREATE INDEX idx_transf_fecha_estado ON transferencia (fecha_transf, estado);

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);

-- PASO 4  Repita la medición
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor)
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS '));

--
--  ANOTE:  operación = TABLE ACCESS FULL  COST = 377
--
--  PREGUNTA 2.2 — ¿Cuánto bajó el COST? Ejecute también con F6
--  (Autotrace) antes y después y compare los "consistent gets".
--No hubo cambio en COST ya que se sigue haciendo acceso completo a la tabla, ademas tambien los "consistent gets" tienen el mismo valor
--el optmizador no usa el indice para acceder a la tabla

-- PASO 5  El orden de las columnas SÍ importa
CREATE INDEX idx_transf_estado_fecha ON transferencia (estado, fecha_transf);

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);

-- Fuerce cada índice y compare
EXPLAIN PLAN FOR
SELECT /*+ INDEX(t idx_transf_fecha_estado) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS +predicate'));


SELECT /*+ INDEX(t idx_transf_estado_fecha) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01'
   AND estado        = 'APLICADA';

--
--  PREGUNTA 2.3 — ¿Cuál de los dos índices elige el optimizador cuando
--  no se le fuerza nada? Compare el COST de los dos SELECT anteriores.
--  Formule la regla general sobre el orden de columnas en un índice
--  compuesto, distinguiendo el predicado de IGUALDAD del de RANGO.
--
--  Cuando no se le fuerza nada el optimizador utiliza el indice que tiene primero el estado. 
--  En un indice compuesto la columna que se va a usar como predicado de igualdad va primero  y la columna que se va a usar como predicado de rango debe ir ultima 
--  ya que la IGUALDAD permite ir directamente a la hoja exacta del indice, el RANGO delimita un tramo que se lee completo.
--  si el RANGO va primero la columna de IGUALDAD se toma como un filtro (Filter predicate).

--  PREGUNTA 2.4 — Suponga ahora que existe además un informe diario que
--  filtra SOLO por rango de fechas, sin estado. ¿Cuál de los dos índices
--  le sirve a ese informe y cuál no? ¿Cambia eso su recomendación?
--  Responda cuál de los dos conservaría en producción y por qué.
-- 
--El indice en el que la primera columna es la fecha le sirve a este nuevo informe, el que inicia por estado sirve pero su costo es mucho mayor,
--Ya que al buscar un rango por la primera columna de un indice compuesto , el motor va directo a ese rango,
--pero si la columna con la que se quiere buscar esta despues de otra que no se utiliza en la consulta, recorre la primera columna completa.
--Con esto en mente en produccion conservaria "idx_transf_fecha_estado" ya que para el primer caso el costo aumenta pero no demasiado usando este indice, a comparacion 
--de cuando se usa el indice "idx_transf_estado_fecha". En el segundo caso ocurre que al usar "idx_transf_fecha_estado" el costo es significativamente menor 
--a cuando se usa "idx_transf_estado_fecha". Por esto es mejor mantener el indice que cuando es peor, la diferencia de costo no es muy elevada

--PRUEBA SIN ESTADO
SELECT /*+ INDEX(t idx_transf_fecha_estado) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01';

SELECT /*+ INDEX(t idx_transf_estado_fecha) */ COUNT(*)
  FROM transferencia t
 WHERE fecha_transf >= DATE '2026-03-01'
   AND fecha_transf <  DATE '2026-04-01';

-- Para el resto del taller trabajamos con IX_TRANSF_FECHA_ESTADO,
-- para no multiplicar índices. Su recomendación va en la entrega.
DROP INDEX idx_transf_estado_fecha;


-- #####################################################################
-- EJERCICIO 2.2 — El índice que existe y no se usa
--
-- El área de servicio al cliente busca por nombre y se queja de que la
-- pantalla de consulta se demora.
-- #####################################################################


-- PASO 1  Sin índice
EXPLAIN PLAN FOR
SELECT id_cliente, nombre, ciudad, segmento
  FROM cliente WHERE UPPER(nombre) = 'MARCELA ROJAS 4004';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));

-- PASO 2  Creo el índice "obvio"
CREATE INDEX idx_cliente_nombre ON cliente (nombre);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', cascade => TRUE);

EXPLAIN PLAN FOR
SELECT id_cliente, nombre, ciudad, segmento
  FROM cliente WHERE UPPER(nombre) = 'MARCELA ROJAS 4004';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--
--  PREGUNTA 2.5 — El índice existe y sigue haciendo FULL SCAN.
--  ¿Por qué? ¿Qué le hizo la consulta a la columna indexada?
--
--Se  sigue haciendo FULL SCAN porque "nombre" esta dentro de una funcion (UPPER) 
--por lo que el motor no lo toma como un indice.

-- PASO 3  El índice que sí sirve
CREATE INDEX idx_cliente_nombre_upper ON cliente (UPPER(nombre));
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', cascade => TRUE);

EXPLAIN PLAN FOR
SELECT id_cliente, nombre, ciudad, segmento
  FROM cliente WHERE UPPER(nombre) = 'MARCELA ROJAS 4004';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));

-- PASO 4  El mismo error, con fechas.  Este es el más común de todos,
--   y en banca aparece en cada extracto y en cada corte diario.
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM transferencia WHERE TRUNC(fecha_transf) = DATE '2026-03-15';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));

EXPLAIN PLAN FOR
SELECT COUNT(*) FROM transferencia
 WHERE fecha_transf >= DATE '2026-03-15'
   AND fecha_transf <  DATE '2026-03-16';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--
--  PREGUNTA 2.6 — Las dos consultas devuelven exactamente lo mismo.
--  Compare los planes. Escriba la regla, en una frase, que todo
--  desarrollador debería tener presente al filtrar por fecha.
--
--El costo es bastante menor cuando no se utiliza la funcion "TRUNC()" y se hace un rango entre dos fechas.
-- Como regla al filtrar por columnas con tipo de dato fecha que tengan un indice, no se debe utilizar funciones
-- sobre estas columnas en el "WHERE", es mejor usar un rango, ya que el rango deja la columna intacta y permite que se use el indice

-- #####################################################################
-- EJERCICIO 2.3 — Cuándo NO conviene un índice
-- #####################################################################

-- PASO 1  Un filtro que devuelve el 62% de la tabla
CREATE INDEX idx_transf_estado ON transferencia (estado);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);


EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor) FROM transferencia WHERE estado = 'APLICADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));

-- PASO 2  El mismo índice, con un valor poco frecuente
EXPLAIN PLAN FOR
SELECT COUNT(*), SUM(valor) FROM transferencia WHERE estado = 'REVERSADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));

--Prueba forzando el uso del indice, para comparar costos (usando el indice el costo es mayor).
EXPLAIN PLAN FOR
SELECT  /*+ INDEX(transferencia idx_transf_estado) */ COUNT(*), SUM(valor) FROM transferencia WHERE estado = 'REVERSADA';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));


--
--  PREGUNTA 2.7 — El mismo índice, la misma consulta, distinto valor:
--  en un caso se usa y en el otro no. ¿Cómo lo sabe el optimizador?
--  ¿Qué información necesita para tomar esa decisión?
--
--En ambos casos no usa el indice, ya que el costo es mayor si usa el indice y despues accede a cada fila,
--a que si se hace un escaneo completo de la tabla
--
--  PREGUNTA 2.8 — Consulte la selectividad y el clustering factor:
--
--selectividad muy baja 0.25 y clustering factor bajo 5273 de 199985 filas

SELECT column_name, num_distinct, num_nulls, density
  FROM user_tab_col_statistics
 WHERE table_name = 'TRANSFERENCIA'
   AND column_name IN ('ESTADO','FECHA_TRANSF','CUENTA_ORIGEN','CANAL');

SELECT index_name, num_rows, distinct_keys, clustering_factor, blevel, leaf_blocks
  FROM user_indexes WHERE table_name = 'TRANSFERENCIA';

--
--  ¿Qué le dice el CLUSTERING FACTOR de IX_TRANSF_FECHA_ESTADO comparado
--  con el de IX_TRANSF_ESTADO? ¿Por qué son tan distintos?
--
--el CLUSTERING FACTOR de ambos indices son tan diferentes ya que ESTADO se encuentra agrupado por bloques, mientras que en
--FECHA_TRANSF cada fila tiene un bloque distinto por los valores tan distintos de la columna.

-- #####################################################################
-- EJERCICIO 2.4 — El índice que evita tocar la tabla
-- #####################################################################

-- PASO 1  Cuentas más activas del trimestre
EXPLAIN PLAN FOR
SELECT cuenta_origen, COUNT(*) AS operaciones
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-01-01'
   AND fecha_transf <  DATE '2026-04-01'
 GROUP BY cuenta_origen;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--> Fíjese: hay INDEX RANGE SCAN y ADEMÁS TABLE ACCESS BY INDEX ROWID.

-- PASO 2  Agrego la columna que falta al índice
CREATE INDEX idx_transf_fecha_origen ON transferencia (fecha_transf, cuenta_origen);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);

EXPLAIN PLAN FOR
SELECT cuenta_origen, COUNT(*) AS operaciones
  FROM transferencia
 WHERE fecha_transf >= DATE '2026-01-01'
   AND fecha_transf <  DATE '2026-04-01'
 GROUP BY cuenta_origen;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST'));
--
--  PREGUNTA 2.9 — Desapareció el TABLE ACCESS. ¿Cómo se llama esta
--  técnica y por qué es tan efectiva? ¿Cuál es su límite: hasta dónde
--  tiene sentido seguir agregando columnas al índice?
--
--La tecnica se llama "covering index", consiste en tener todas las columnas que una consulta necesita en un mismo indice.
--Es bastante efectivo ya que la cantidad de columnas es menor a la de la tabla, haciendolo mejor a un FULL SCAN
--Tiene sentido seguir agregando columnas hasta el punto en que un acceso completo a la tabla tiene un costo no muy significativo 
--en relacion a cuando se usa el indice, el indice entre mas grande, mas almacenamiento consume y dificulta las sentencias DML    

-- #####################################################################
-- EJERCICIO 2.5 — Lo que cuesta un índice
--
-- Hasta aquí solo hemos visto el beneficio. Ahora el precio.
-- #####################################################################

-- PASO 1  Cuántos índices tiene TRANSFERENCIA en este momento
SELECT index_name, leaf_blocks,
       ROUND(leaf_blocks * 8192 / 1024 / 1024, 2) AS mb_aprox
  FROM user_indexes WHERE table_name = 'TRANSFERENCIA';

-- PASO 2  Inserte 50.000 transferencias CON todos los índices y mida
--   (ejecute este bloque con F5 para ver el TIMING)
SET TIMING ON
INSERT INTO transferencia
  (id_transferencia, cuenta_origen, cuenta_destino, fecha_transf, valor, canal, estado)
SELECT 1000000 + LEVEL,
       MOD(LEVEL, 15000) + 1,
       MOD(LEVEL, 15000) + 15001,
       DATE '2026-06-01' + MOD(LEVEL,30), 100000, 'APP', 'REGISTRADA'
  FROM dual CONNECT BY LEVEL <= 50000;
COMMIT;
--> Anote el tiempo: 00:00:02.430

-- PASO 3  Ahora sin índices secundarios
DROP INDEX idx_transf_fecha_estado;
DROP INDEX idx_transf_estado;
DROP INDEX idx_transf_fecha_origen;

INSERT INTO transferencia
  (id_transferencia, cuenta_origen, cuenta_destino, fecha_transf, valor, canal, estado)
SELECT 2000000 + LEVEL,
       MOD(LEVEL, 15000) + 1,
       MOD(LEVEL, 15000) + 15001,
       DATE '2026-06-01' + MOD(LEVEL,30), 100000, 'APP', 'REGISTRADA'
  FROM dual CONNECT BY LEVEL <= 50000;
COMMIT;
--> Anote el tiempo: 00:00:00.381

-- PASO 4  Deje el esquema como debe quedar
DELETE FROM transferencia WHERE id_transferencia >= 1000000;
COMMIT;

CREATE INDEX ix_transf_fecha_estado ON transferencia (fecha_transf, estado);
CREATE INDEX ix_transf_fecha_origen ON transferencia (fecha_transf, cuenta_origen);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'TRANSFERENCIA', cascade => TRUE);
--
--  PREGUNTA 2.10 — ¿Cuál fue la diferencia de tiempo? Extrapole:
--  el Banco Andino procesa 12.000 transferencias por hora en hora pico.
--  ¿Qué costo operativo tiene cada índice que se agrega "por si acaso"?
--
--La diferencia de tiempo fue de 2.049 segundos 
-- Cada indice tiene un costo operativo muy grande, el volumen de escrituras por hora 
-- y los indices que se tienen genera un tiempo mayor a sino se tuvieran, es necesario mantener unicamente los indice
--mas usados




--  PREGUNTA 2.11 — Proponga la lista DEFINITIVA de índices para este
--  esquema. Para cada uno escriba: qué consulta lo justifica, y por qué
--  no se puede resolver con otro índice ya existente. Tenga en cuenta
--  que TRANSFERENCIA tiene DOS llaves foráneas hacia CUENTA.
--
--"IDX_TRANSF_FECHA_ESTADO" para la consulta 
    /*SELECT COUNT(*)
      FROM transferencia t
     WHERE fecha_transf >= DATE '2026-03-01'
       AND fecha_transf <  DATE '2026-04-01'
       AND estado        = 'APLICADA'; o
    SELECT  COUNT(*)
      FROM transferencia t
     WHERE fecha_transf >= DATE '2026-03-01'
       AND fecha_transf <  DATE '2026-04-01'*/
--Es el unico orden del indice que sigue funcionando cuando no se filtra tambien por estado,
-- solo por fecha que es la columna mas usada
--"IDX_TRANSF_FECHA_ORIGEN" para la consulta
    /*SELECT cuenta_origen, COUNT(*) AS operaciones
      FROM transferencia
    WHERE fecha_transf >= DATE '2026-01-01'
       AND fecha_transf <  DATE '2026-04-01'
    GROUP BY cuenta_origen; */
--Unico indice que tiene cuenta_origen

-- Es necesario tambien tener un indice por cada llave foranea "IDX_TRANSF_CUENTA_ORIGEN" y "IDX_TRANSF_CUENTA_DESTINO"
    

-- =====================================================================
-- Bases de Datos 2 · Taller integrador — Banco Andino
-- 03_sql_avanzado.sql   SQL analítico, jerárquico y MERGE
--
-- Trabajen en UNA SOLA CONEXIÓN: la pareja comparte el esquema.
-- Cada bloque trae una consulta RESUELTA que sirve de modelo, y una
-- consulta que ustedes deben ESCRIBIR. Complete las que dicen ESCRIBA.
-- =====================================================================

SET LINESIZE 220
SET PAGESIZE 60
SET TIMING ON


-- #####################################################################
-- EJERCICIO 3.1 — Ranking dentro de grupos
--
-- La vicepresidencia comercial quiere los 3 productos que más saldo
-- captan dentro de cada FAMILIA de productos, solo cuentas activas.
-- #####################################################################

-- MODELO (resuelto)
WITH captacion AS (
    SELECT f.id_producto  AS id_familia,
         f.nombre       AS familia,
         p.id_producto,
         p.nombre       AS producto,
         SUM(c.saldo)   AS saldo_captado,
         COUNT(*)       AS cuentas
    FROM cuenta c
    JOIN catalogo_producto p ON p.id_producto = c.id_producto
    JOIN catalogo_producto f ON f.id_producto = p.id_padre
   WHERE c.estado = 'ACTIVA'
   GROUP BY f.id_producto, f.nombre, p.id_producto, p.nombre
)
SELECT familia, producto, cuentas, ROUND(saldo_captado) AS saldo_captado, puesto
  FROM (SELECT v.*,
               DENSE_RANK() OVER (PARTITION BY id_familia
                                  ORDER BY saldo_captado DESC) AS puesto
          FROM captacion v)
 WHERE puesto <= 3
 ORDER BY familia, puesto;

--
--  PREGUNTA 3.1 — Cambie DENSE_RANK por RANK y luego por ROW_NUMBER.
--  Explique en qué se diferencian los tres cuando hay empates, y cuál
--  usaría usted para un "top 3" que debe devolver exactamente 3 filas.


--  En los resultados de los cambios entre DENSE_RANK, RANK Y ROW_NUMBER, no hay diferencia
--  ya que no hay valores iguales, todos son distintos, pero estos tres se diferencian cuando
--  hay valores iguales.
--  Dense_rank: cuando hay valores iguales los marca con el mismo número y el siguiente lo marca consecutivamente
--  ejemplo: 1,1,2,3 o 1,2,2,3,3...
--  Rank: Al encontrar valores iguales, marca el número con el valor que corresponde con el mismo numero, pero para el siguiente salta al valor que deberia ir.
--  Ejemplo: 1,1,3,4 o 1,2,2,4,4
--  Row_number: Este sin importar empates asigna consecutivamente un número
--  Ejemplo: 1,2,3,4 o 1,2,3,4,5
--  Por estas razones si se necesita exactamente tres filas y no interea si hay empate la mejor opción es ROW_NUMBER, los demas mantienen la posibilidad de mandar mas filas si hay valores iguales. 


--  ESCRIBA 3.1 — La misma consulta, pero mostrando además qué porcentaje
--  representa cada producto sobre el saldo total captado por su familia.
--  Use RATIO_TO_REPORT o una función de ventana con SUM() OVER.
--  Cuidado: el porcentaje debe ser sobre la familia COMPLETA, no sobre
--  el top 3.


WITH captacion AS (
    SELECT f.id_producto  AS id_familia,
         f.nombre AS familia,
         p.id_producto,
         p.nombre AS producto,
         SUM(c.saldo) AS saldo_captado,
         COUNT(*) AS cuentas
    FROM cuenta c
    JOIN catalogo_producto p ON p.id_producto = c.id_producto
    JOIN catalogo_producto f ON f.id_producto = p.id_padre
    WHERE c.estado = 'ACTIVA'
    GROUP BY f.id_producto, f.nombre, p.id_producto, p.nombre
)
SELECT familia, producto, cuentas, saldo_captado_r AS saldo_captado, puesto, pct_familia
    FROM (SELECT v.*,
               DENSE_RANK() OVER (PARTITION BY id_familia
                                  ORDER BY saldo_captado DESC) AS puesto,
               ROUND(saldo_captado) AS saldo_captado_r,
               ROUND(100 * RATIO_TO_REPORT(saldo_captado)
                     OVER (PARTITION BY id_familia), 1) AS pct_familia
          FROM captacion v)
    WHERE puesto <= 3
    ORDER BY familia, puesto;

---------------------



-- #####################################################################
-- EJERCICIO 3.2 — Series de tiempo: acumulado y variación
--
-- Riesgo operativo quiere la evolución mensual del valor transferido
-- durante 2026, con el acumulado del año y la variación contra el mes
-- anterior. Es la base de las alertas por comportamiento atípico.
-- #####################################################################

-- MODELO (resuelto)
WITH mensual AS (
  SELECT TRUNC(fecha_transf, 'MM') AS mes,
         SUM(valor)                AS valor_transferido,
         COUNT(*)                  AS operaciones
    FROM transferencia
   WHERE fecha_transf >= DATE '2026-01-01'
     AND fecha_transf <  DATE '2027-01-01'
     AND estado = 'APLICADA'
   GROUP BY TRUNC(fecha_transf, 'MM')
)
SELECT TO_CHAR(mes,'YYYY-MM')                          AS mes,
       operaciones,
       ROUND(valor_transferido)                        AS valor,
       ROUND(SUM(valor_transferido) OVER (ORDER BY mes
             RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS acumulado,
       ROUND(LAG(valor_transferido) OVER (ORDER BY mes)) AS mes_anterior,
       ROUND(100 * (valor_transferido - LAG(valor_transferido) OVER (ORDER BY mes))
                 / NULLIF(LAG(valor_transferido) OVER (ORDER BY mes),0), 1) AS var_pct
  FROM mensual
 ORDER BY mes;

--
--  PREGUNTA 3.2 — ¿Qué diferencia hay entre
--     ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--  y  RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ?
--  Constrúyase un caso donde den resultados distintos.


-- La diferencia es que mientras rows between .... cuenta las posiciones una por una secuancialmente sin importar si al valores iguales el 
-- Range between ... cuentaa posiciones pero agrupadas si tienen un mismo valor se organiza como si fueran una sola.
-- en este caso no hay valores repetidos por lo que no se ve una direncia. 




--IMPORTANTE




-- 
--  ESCRIBA 3.2 — Agregue una columna con el promedio móvil de los
--  últimos 3 meses (mes actual y los dos anteriores), que es la línea
--  base contra la que riesgo compara cada mes.




--CONSULTA:
WITH mensual AS (
  SELECT TRUNC(fecha_transf, 'MM') AS mes,
         SUM(valor)                AS valor_transferido,
         COUNT(*)                  AS operaciones
    FROM transferencia
   WHERE fecha_transf >= DATE '2026-01-01'
     AND fecha_transf <  DATE '2027-01-01'
     AND estado = 'APLICADA'
   GROUP BY TRUNC(fecha_transf, 'MM')
)
SELECT TO_CHAR(mes,'YYYY-MM')                          AS mes,
       operaciones,
       ROUND(valor_transferido)                        AS valor,
       ROUND(SUM(valor_transferido) OVER (ORDER BY mes
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS acumulado,
       ROUND(LAG(valor_transferido) OVER (ORDER BY mes))  AS mes_anterior,
       ROUND(100 * (valor_transferido - LAG(valor_transferido) OVER (ORDER BY mes))
                 / NULLIF(LAG(valor_transferido) OVER (ORDER BY mes),0), 1) AS var_pct,
       ROUND(AVG(valor_transferido) OVER (ORDER BY mes
             ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS prom_movil_3m
  FROM mensual
 ORDER BY mes;




-- #####################################################################
-- EJERCICIO 3.3 — La misma respuesta, dos planes muy distintos
--
-- Se necesita, por cada cliente PREFERENCIAL, su última transferencia.
-- #####################################################################

-- VERSIÓN A — subconsulta correlacionada  (la que sale sola al escribir)
EXPLAIN PLAN FOR
SELECT cl.id_cliente, cl.nombre, t.id_transferencia, t.fecha_transf, t.valor
  FROM cliente       cl
  JOIN cuenta        c ON c.id_cliente = cl.id_cliente
  JOIN transferencia t ON t.cuenta_origen = c.id_cuenta
 WHERE cl.segmento = 'PREFERENCIAL'
   AND t.fecha_transf = (SELECT MAX(t2.fecha_transf)
                           FROM transferencia t2
                           JOIN cuenta c2 ON c2.id_cuenta = t2.cuenta_origen
                          WHERE c2.id_cliente = cl.id_cliente);

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));

-- VERSIÓN B — función analítica
EXPLAIN PLAN FOR
SELECT id_cliente, nombre, id_transferencia, fecha_transf, valor
  FROM (SELECT cl.id_cliente, cl.nombre, t.id_transferencia,
               t.fecha_transf, t.valor,
               ROW_NUMBER() OVER (PARTITION BY cl.id_cliente
                                  ORDER BY t.fecha_transf DESC) AS rn
          FROM cliente       cl
          JOIN cuenta        c ON c.id_cliente = cl.id_cliente
          JOIN transferencia t ON t.cuenta_origen = c.id_cuenta
         WHERE cl.segmento = 'PREFERENCIAL')
 WHERE rn = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +COST +ROWS'));


--  PREGUNTA 3.3 — Compare los dos planes. ¿Cuántas veces se lee
--  TRANSFERENCIA en cada versión? ¿Cuál es el COST de cada una?


-- En ambos planes transferencia se lee una sola vez --> Rows=199K 
-- el cost de la versión correlacionada es 1268 mientras en el de la analitica es 1160
-- por lo que la analitica es mas barata



--  PREGUNTA 3.4 — Las dos consultas NO son totalmente equivalentes:
--  hay un caso en el que devuelven distinto número de filas. ¿Cuál es?
--  (pista: piense en un cliente que hizo dos transferencias el mismo
--  día a la misma hora, algo perfectamente normal en un pago de nómina)


--  Si en el caso de que un cliente realice dos transferencias cambia ya que en estas versiones tenemos fecha_transf 
--  en la versión correlacionada la igualdad no distingue entre las filas empatadas: si dos comparten el máximo, las trae ambas
--  mientras que la versión analitica asigna un numero unico por fila, así que el empate solo deja pasar una fila.
--  Para ese cliente, la
--  La versión correlacionada devuelve 2 filas y la versión analitica devuelve 1 


-- #####################################################################
-- EJERCICIO 3.4 — Jerarquías: la CTE recursiva
--
-- El catálogo tiene tres niveles: línea de negocio, familia y producto.
-- #####################################################################

-- MODELO (resuelto) — ruta completa de cada nodo del catálogo
WITH arbol (id_producto, nombre, id_padre, nivel, ruta) AS (
  SELECT id_producto, nombre, id_padre, 1, CAST(nombre AS VARCHAR2(400))
    FROM catalogo_producto
   WHERE id_padre IS NULL
  UNION ALL
  SELECT c.id_producto, c.nombre, c.id_padre, a.nivel + 1,
         a.ruta || ' > ' || c.nombre
    FROM catalogo_producto c
    JOIN arbol a ON c.id_padre = a.id_producto
)
SELECT LPAD(' ', (nivel-1)*3) || nombre AS jerarquia, nivel, ruta
  FROM arbol
 ORDER BY ruta;

-- El equivalente con CONNECT BY, sintaxis propia de Oracle
SELECT LPAD(' ', (LEVEL-1)*3) || nombre AS jerarquia,
       LEVEL AS nivel,
       SYS_CONNECT_BY_PATH(nombre, ' > ') AS ruta
  FROM catalogo_producto
 START WITH id_padre IS NULL
CONNECT BY PRIOR id_producto = id_padre
 ORDER SIBLINGS BY nombre;

--
--  PREGUNTA 3.5 — ¿Qué ventaja tiene la CTE recursiva sobre CONNECT BY?
--  ¿Y qué le da CONNECT BY que la CTE no?
--





-- IMPORTANTE






--  ESCRIBA 3.3 — Saldo total captado por LÍNEA DE NEGOCIO.
--  Es decir: el saldo de "Cuenta de ahorros" debe sumar dentro de
--  "Banca Personas". Use la CTE recursiva para resolver a qué línea
--  pertenece cada producto hoja, y únala con los saldos de CUENTA.
--  Muestre además cuántas cuentas activas tiene cada línea.



-- CONSULTA :
WITH arbol (id_producto, nombre, id_padre, id_linea) AS (
    SELECT id_producto, nombre, id_padre, id_producto AS id_linea
    FROM catalogo_producto
    WHERE id_padre IS NULL
    UNION ALL
        SELECT c.id_producto, c.nombre, c.id_padre, a.id_linea
        FROM catalogo_producto c
        JOIN arbol a ON c.id_padre = a.id_producto
)
SELECT l.nombre             AS linea_negocio,
        COUNT(*)             AS cuentas_activas,
        ROUND(SUM(cu.saldo)) AS saldo_total
FROM cuenta cu
JOIN arbol a ON a.id_producto = cu.id_producto
JOIN catalogo_producto l ON l.id_producto = a.id_linea
WHERE cu.estado = 'ACTIVA'
GROUP BY l.nombre
ORDER BY saldo_total DESC;



-- #####################################################################
-- EJERCICIO 3.5 — MERGE: aplicar los ajustes del cierre mensual
--
-- Cada fin de mes se aplican intereses y cuotas de manejo. La tabla
-- AJUSTE_SALDO ya los tiene cargados.
-- #####################################################################

-- PASO 1  Antes
SELECT ROUND(SUM(saldo)) AS saldo_total, COUNT(*) AS cuentas FROM cuenta;
SELECT concepto, COUNT(*), SUM(delta) FROM ajuste_saldo GROUP BY concepto;

-- MODELO (resuelto)
MERGE INTO cuenta c
USING (SELECT id_cuenta, SUM(delta) AS delta
         FROM ajuste_saldo
        GROUP BY id_cuenta) a
   ON (c.id_cuenta = a.id_cuenta)
 WHEN MATCHED THEN
   UPDATE SET c.saldo   = GREATEST(c.saldo + a.delta, 0),
              c.version = c.version + 1;
--> Mire el mensaje de SQL Developer: cuántas filas fusionó.
COMMIT;

-- PASO 2  Después
SELECT ROUND(SUM(saldo)) AS saldo_total FROM cuenta;

--
--  PREGUNTA 3.6 — ¿Por qué se agrupa la tabla de ajustes dentro del
--  USING en lugar de usarla directamente? ¿Qué error da Oracle si una
--  misma cuenta aparece dos veces en el origen?


--  Se agrupa dentro del usign porque el merge exige que
--  cada fila coincida con máximo una fila del source, si no se ajustara y se tienen mas de un ajuste en la 
--  tabla esto ocacionaria  que no se sepa cual fila actualizar y ocaciona el error:
--  ORA-30926: unable to get a stable set of rows in the source tables


--  PREGUNTA 3.7 — El GREATEST(..., 0) evita que el saldo quede negativo.
--  En un banco eso NO es una solución: si una cuota de manejo excede el
--  saldo, truncar a cero significa que el banco regaló la diferencia.
--  ¿Qué haría usted en un sistema real? Proponga el mecanismo, no solo
--  la crítica.
 
 
--  En un sistema real no se realiza de esa forma ya que eso implica que el banco regale
--  la diferencia sin dejar rastro de que la cuota no se cobro completa.
--  La formas mas viable es: aplicar el ajuste solo si el resultado es
--  válido como saldo >= 0, o dentro de un cupo de sobregiro autorizado, si
--  no cabe completo, la cuenta no se toca y en su lugar se registra en
--  una tabla de excepciones con el monto que falto por cobrar, para que el area correspondiente
--  la revise manualmente, reintente el cobro en el siguiente ciclo, o
--  lo gestione como cartera pendiente


--  ESCRIBA 3.4 — Reescriba el MERGE para que las cuentas cuyo ajuste no
--  se pueda aplicar completo NO se toquen, y en cambio queden
--  identificadas. Pista: la cláusula WHERE de la actualización dentro
--  del MERGE, más una consulta que liste las excluidas.


--CONSULTA:
MERGE INTO cuenta c
USING (SELECT id_cuenta, SUM(delta) AS delta
        FROM ajuste_saldo
        GROUP BY id_cuenta) a
        ON (c.id_cuenta = a.id_cuenta)
    WHEN MATCHED THEN
    UPDATE SET c.saldo   = c.saldo + a.delta,
              c.version = c.version + 1
    WHERE c.saldo + a.delta >= 0;
COMMIT;

--Cuentas excluidas
SELECT c.id_cuenta,
        c.saldo AS saldo_actual,
        a.delta,
        c.saldo + a.delta AS saldo_si_aplicara
FROM cuenta c
JOIN (SELECT id_cuenta, SUM(delta) AS delta
        FROM ajuste_saldo
        GROUP BY id_cuenta) a
ON a.id_cuenta = c.id_cuenta
WHERE c.saldo + a.delta < 0;





-- #####################################################################
-- EJERCICIO 3.6 — PIVOT y LISTAGG
-- #####################################################################

-- MODELO (resuelto) — valor transferido por canal y trimestre, en columnas
SELECT *
  FROM (SELECT canal,
               'T' || TO_CHAR(fecha_transf,'Q') AS trimestre,
               valor
          FROM transferencia
         WHERE fecha_transf >= DATE '2026-01-01'
           AND fecha_transf <  DATE '2027-01-01'
           AND estado = 'APLICADA')
 PIVOT (ROUND(SUM(valor)) FOR trimestre IN ('T1' AS t1, 'T2' AS t2,
                                            'T3' AS t3, 'T4' AS t4))
 ORDER BY canal;
 
 
-- PARA ESTE ME SALE: ORA-56902: se espera una función aggregate en la operación PIVOT



-- MODELO (resuelto) — los 10 clientes con más saldo y qué productos tienen
SELECT cl.id_cliente, cl.nombre, cl.segmento,
       ROUND(SUM(c.saldo)) AS saldo_total,
       COUNT(*)            AS cuentas,
       LISTAGG(DISTINCT p.nombre, ', ')
         WITHIN GROUP (ORDER BY p.nombre) AS productos
  FROM cliente cl
  JOIN cuenta  c ON c.id_cliente  = cl.id_cliente
  JOIN catalogo_producto p ON p.id_producto = c.id_producto
 WHERE c.estado = 'ACTIVA'
 GROUP BY cl.id_cliente, cl.nombre, cl.segmento
 ORDER BY saldo_total DESC
 FETCH FIRST 10 ROWS WITH TIES;

--
--  PREGUNTA 3.8 — ¿Qué diferencia hay entre FETCH FIRST 10 ROWS ONLY y
--  FETCH FIRST 10 ROWS WITH TIES? ¿En cuál de los dos casos puede
--  devolver más de 10 filas y por qué?


--  Para FETCH FIRST 10 ROWS ONLY da exactamente las 10 filas, no importa si 
--  hay empates como si la fila 10 y la 11 tienen el mismo
--  valor, la 11 simplemente se descarta mientras que el FETCH FIRST 10
--  ROWS WITH TIES devuelve las 10 primeras MÁS todas las filas que
--  empaten con el valor de la fila número 10 en la columna del ORDER BY
--  por eso puede devolver mas de 10 filas, pero solo si el empate es justo en la decima fila


--  ESCRIBA 3.5 — Un informe de "clientes en fuga": clientes
--  PREFERENCIAL cuya última transferencia tiene más de 120 días,
--  mostrando cuántos días llevan inactivos, su saldo total y cuántos
--  productos tienen contratados.


--CONSULTA:
WITH ultima_transf AS (
    SELECT c.id_cliente, MAX(t.fecha_transf) AS ultima_fecha
    FROM cuenta c
    JOIN transferencia t ON t.cuenta_origen = c.id_cuenta
    GROUP BY c.id_cliente
),
saldo_cliente AS (
    SELECT id_cliente,
        ROUND(SUM(saldo))          AS saldo_total,
        COUNT(DISTINCT id_producto) AS productos
    FROM cuenta
    WHERE estado = 'ACTIVA'
    GROUP BY id_cliente
)
SELECT cl.id_cliente,
        cl.nombre,
        TRUNC(SYSDATE - ut.ultima_fecha) AS dias_inactivo,
        sc.saldo_total,
        sc.productos
FROM cliente cl
JOIN ultima_transf ut ON ut.id_cliente = cl.id_cliente
JOIN saldo_cliente  sc ON sc.id_cliente = cl.id_cliente
WHERE cl.segmento = 'PREFERENCIAL'
    AND ut.ultima_fecha < SYSDATE - 120
    ORDER BY dias_inactivo DESC;