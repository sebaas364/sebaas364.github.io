// Evidencias: scripts de práctica de Bases de Datos 2.
//
// Cada script aparece como una tarjeta en /posts (dentro del panel indicado)
// y tiene su propia página de detalle en /evidencias/<slug> con todos sus
// ejercicios. Los archivos están en la carpeta "evidencias/" en la raíz del
// repositorio; los enlaces llevan a esa carpeta en GitHub.

export const repoUrl = "https://github.com/sebaas364/sebaas364.github.io";
export const repoBranch = "main";
export const repoFolder = "evidencias";

export interface Ejercicio {
  num: string;
  title: string;
  description: string;
}

export interface ArchivoExtra {
  label: string;
  file: string;
}

export interface Script {
  slug: string;
  panel: "SQL" | "PL/SQL Scripts" | "NoSQL";
  title: string;
  summary: string;
  /** Subcarpeta dentro de evidencias/ ("" si está en la raíz de evidencias/). */
  folder: string;
  /** Nombre del archivo del script dentro de la carpeta (opcional si solo hay archivos extra). */
  file?: string;
  extras?: ArchivoExtra[];
  exercises: Ejercicio[];
}

const folderPath = (s: Script) => [repoFolder, s.folder].filter(Boolean).join("/");

/** Enlace a la carpeta del repositorio donde está el script. */
export const folderUrl = (s: Script) => `${repoUrl}/tree/${repoBranch}/${folderPath(s)}`;

/** Enlace a un archivo concreto dentro de la carpeta del script. */
export const fileUrl = (s: Script, file: string) =>
  `${repoUrl}/blob/${repoBranch}/${folderPath(s)}/${file}`;

export const scripts: Script[] = [
  // ============================== SQL ==============================
  {
    slug: "practica-sql",
    panel: "SQL",
    title: "Ejercicios de práctica SQL",
    summary:
      "Consultas sobre el esquema HR de Oracle: JOINs entre empleados, departamentos, ciudades y países, agrupaciones con HAVING, subconsultas, casos borde (empleados sin jefe o sin departamento) y la diferencia entre filtrar en ON y en WHERE.",
    folder: "",
    file: "ejercios_practica_SQL.sql",
    exercises: [
      {
        num: "1",
        title: "Empleados con cargo, departamento y ubicación",
        description:
          "Lista el nombre completo de cada empleado con su cargo, departamento, ciudad y país, uniendo cinco tablas con LEFT JOIN para no perder empleados sin departamento. Ordena por país y apellido. Incluye una versión alternativa con nombre y apellido por separado.",
      },
      {
        num: "2",
        title: "Países con empleados en más de una ciudad",
        description:
          "Agrupa por país y usa COUNT(DISTINCT ciudad) con HAVING para quedarse solo con los países donde hay empleados en varias ciudades. Incluye una consulta de comprobación para los países que empiezan por 'Ca'.",
      },
      {
        num: "3",
        title: "Empleados cuyo jefe no es el manager del departamento",
        description:
          "Compara el jefe directo de cada empleado con el manager de su departamento y muestra los que no coinciden, teniendo en cuenta los valores nulos.",
      },
      {
        num: "4",
        title: "Departamentos sin empleados",
        description:
          "Usa LEFT OUTER JOIN y filtra los departamentos que no tienen ningún empleado asociado. Incluye una versión que muestra todas las columnas.",
      },
      {
        num: "5",
        title: "Empleados que ganan más que el promedio de su departamento",
        description:
          "Calcula el salario promedio por departamento en una subconsulta y lo une con los empleados para mostrar solo los que están por encima de ese promedio.",
      },
      {
        num: "6.1",
        title: "Verificación de casos borde del esquema",
        description:
          "Con UNION ALL resume en una sola tabla cuántos empleados no tienen jefe, cuántos no tienen departamento, cuántos no tienen comisión y cuántos departamentos están vacíos.",
      },
      {
        num: "6.2",
        title: "Inventario completo de departamentos",
        description:
          "Para cada departamento muestra ciudad, país, número de empleados y salario promedio, usando NVL para que los departamentos vacíos aparezcan con 0.",
      },
      {
        num: "6.3",
        title: "Cadena de mando",
        description:
          "Une la tabla de empleados consigo misma (self join) para mostrar a cada empleado junto al nombre de su jefe, su cargo y su departamento.",
      },
      {
        num: "6.4",
        title: "Condición en ON frente a condición en WHERE",
        description:
          "Ejecuta el mismo LEFT JOIN filtrando el salario primero en el ON y luego en el WHERE, y compara los conteos (36 frente a 15) para mostrar cómo cambia el resultado.",
      },
      {
        num: "6.6",
        title: "Agregación con filtrado de grupos",
        description:
          "Por departamento calcula cantidad de empleados, salario promedio, mínimo, máximo, masa salarial y contratados después de 2005, y con HAVING deja solo los que tienen más de 5 empleados y promedio mayor a 6000.",
      },
    ],
  },
  {
    slug: "taller-banco-andino",
    panel: "SQL",
    title: "Taller Banco Andino: concurrencia, índices y SQL avanzado",
    summary:
      "Simulación con dos sesiones de cajeros: actualización perdida, bloqueo pesimista con SELECT ... FOR UPDATE, control optimista con columna de versión y reparto de colas con SKIP LOCKED. También analiza planes de ejecución, cuándo conviene un índice y consultas analíticas, recursivas y MERGE.",
    folder: "",
    file: "taller_bancoAndinoSQL_SebastianPerez_CamylaPoveda.sql",
    exercises: [
      {
        num: "1.1",
        title: "El retiro que se pierde (actualización perdida)",
        description:
          "Dos sesiones leen el mismo saldo, restan en memoria y escriben encima. Demuestra que el banco pierde dinero aunque el bloqueo de fila funcione, porque ambas partieron del mismo valor leído.",
      },
      {
        num: "1.2",
        title: "Defensa pesimista: SELECT ... FOR UPDATE",
        description:
          "Bloquea la fila en el momento de leerla y descuenta sobre el saldo actual. Analiza el precio de esta seguridad: esperas y bloqueos en cascada cuando hay mucha concurrencia.",
      },
      {
        num: "1.3",
        title: "Defensa optimista: columna de versión",
        description:
          "Sin bloquear nada, detecta el choque al escribir porque el UPDATE afecta 0 filas. Compara en qué productos del banco conviene la estrategia pesimista y en cuáles la optimista.",
      },
      {
        num: "1.4",
        title: "Repartir una cola de trabajo con SKIP LOCKED",
        description:
          "Dos procesos de compensación toman tareas de la misma cola sin repetir ninguna y sin esperarse entre sí, usando FOR UPDATE SKIP LOCKED con ROWNUM.",
      },
      {
        num: "1.5",
        title: "El bloqueo que nadie espera: llave foránea sin índice",
        description:
          "Muestra cómo una llave foránea sin índice hace que un borrado en la tabla padre quede bloqueado por una inserción no relacionada en la tabla hija.",
      },
      {
        num: "1.6",
        title: "Interbloqueo: dos transferencias cruzadas",
        description:
          "Dos clientes se transfieren dinero al mismo tiempo y se produce un deadlock (ORA-00060). Explica en qué estado queda la sesión víctima y la regla para evitarlo: bloquear siempre las cuentas en el mismo orden.",
      },
      {
        num: "2.1",
        title: "El informe de la Superintendencia",
        description:
          "Mide la consulta mensual de transferencias aplicadas y compara índices compuestos según el orden de sus columnas (fecha y estado frente a estado y fecha) con sus planes de ejecución.",
      },
      {
        num: "2.2",
        title: "El índice que existe y no se usa",
        description:
          "Un índice sobre el nombre no se usa porque la consulta aplica UPPER a la columna; se resuelve con un índice basado en función. Lo mismo pasa con TRUNC sobre fechas, que se corrige usando un rango.",
      },
      {
        num: "2.3",
        title: "Cuándo NO conviene un índice",
        description:
          "Compara un filtro que devuelve el 62% de la tabla con uno muy selectivo, revisa selectividad y clustering factor, y explica por qué el optimizador prefiere un escaneo completo.",
      },
      {
        num: "2.4",
        title: "El índice que evita tocar la tabla",
        description:
          "Agrega la columna que faltaba a un índice para que la consulta se resuelva solo con el índice (covering index) y desaparezca el acceso a la tabla.",
      },
      {
        num: "2.5",
        title: "Lo que cuesta un índice",
        description:
          "Inserta 50.000 transferencias con y sin índices secundarios, compara los tiempos y propone la lista definitiva de índices del esquema, justificando cada uno.",
      },
      {
        num: "3.1",
        title: "Ranking dentro de grupos",
        description:
          "Obtiene los 3 productos que más saldo captan dentro de cada familia de productos con DENSE_RANK, y compara el resultado con RANK y ROW_NUMBER cuando hay empates.",
      },
      {
        num: "3.2",
        title: "Series de tiempo: acumulado y variación",
        description:
          "Calcula la evolución mensual del valor transferido en 2026, con el acumulado del año y la variación frente al mes anterior usando funciones de ventana.",
      },
      {
        num: "3.3",
        title: "La misma respuesta, dos planes muy distintos",
        description:
          "Obtiene la última transferencia de cada cliente preferencial con una subconsulta correlacionada y con la función analítica ROW_NUMBER, y compara sus planes de ejecución.",
      },
      {
        num: "3.4",
        title: "Jerarquías con CTE recursiva",
        description:
          "Recorre el catálogo de tres niveles (línea de negocio, familia y producto) con una CTE recursiva para construir la ruta completa de cada nodo.",
      },
      {
        num: "3.5",
        title: "MERGE: ajustes del cierre mensual",
        description:
          "Aplica intereses y cuotas de manejo de la tabla AJUSTE_SALDO sobre las cuentas con una sola sentencia MERGE, verificando los saldos antes y después.",
      },
      {
        num: "3.6",
        title: "PIVOT y LISTAGG",
        description:
          "Convierte filas en columnas para mostrar el valor transferido por canal y trimestre (PIVOT) y concatena valores de un grupo en una sola cadena (LISTAGG).",
      },
    ],
  },

  // ============================== PL/SQL ==============================
  {
    slug: "practica-plsql",
    panel: "PL/SQL Scripts",
    title: "Práctica PL/SQL",
    summary:
      "Cursor explícito que clasifica salarios del departamento 80 en ALTO, MEDIO y BAJO; procedimiento sp_subir_salario con validaciones y tope del cargo; función fn_costo_empleado que calcula el costo anual; trigger de auditoría que impide bajar salarios; y cursores parametrizados con manejo de una excepción propia.",
    folder: "",
    file: "plsql_practica.sql",
    exercises: [
      {
        num: "1",
        title: "Clasificación de salarios con cursor explícito",
        description:
          "Bloque anónimo que recorre los empleados del departamento 80 con OPEN, FETCH y CLOSE, los clasifica en ALTO, MEDIO o BAJO frente al promedio del departamento y muestra un resumen por categoría.",
      },
      {
        num: "2",
        title: "Procedimiento sp_subir_salario",
        description:
          "Aumenta el salario de un empleado según un porcentaje, valida los parámetros, respeta el salario máximo del cargo y lanza un error personalizado si el empleado no existe.",
      },
      {
        num: "3",
        title: "Función fn_costo_empleado",
        description:
          "Devuelve el costo anual de un empleado (salario por 12 más comisión, con 10% extra si lleva más de 15 años) y retorna NULL en vez de fallar si el empleado no existe.",
      },
      {
        num: "4",
        title: "Auditoría de salarios con trigger",
        description:
          "Crea la tabla auditoria_salarios y el trigger trg_audit_salario, que registra cada cambio de salario, impide que el salario baje y marca el cambio como AUMENTO GRANDE o AUMENTO NORMAL.",
      },
      {
        num: "5",
        title: "Empleados con su manager y salario con comisión",
        description:
          "Bloque anónimo con un cursor parametrizado por departamento que une la tabla de empleados consigo misma para obtener el nombre del manager, y muestra el salario y el salario con comisión, o 'SIN COMISION' si el empleado no tiene.",
      },
      {
        num: "6",
        title: "Excepción propia para departamentos inexistentes",
        description:
          "Recorre los departamentos 80 y 90, valida que cada uno exista y, si no, lanza la excepción propia e_sin_departamento y la captura en un bloque interno, para que el error de un departamento no detenga el resto del reporte.",
      },
    ],
  },
  {
    slug: "taller-plsql-grupo-2",
    panel: "PL/SQL Scripts",
    title: "Taller PL/SQL (Grupo 2): sistema de inventario",
    summary:
      "Procedimientos para registrar productos, ajustar stock y crear pedidos; funciones de stock y cupo disponible; cursores, manejo de excepciones, disparadores y un caso integrador de facturación, cada uno con su justificación.",
    folder: "",
    file: "TALLER_PLSQL_GRUPO_2.sql",
    exercises: [
      {
        num: "1.1",
        title: "SP_REGISTRAR_PRODUCTO",
        description:
          "Registra un producto nuevo tomando el id de una secuencia, valida que el precio supere el costo y que la categoría exista, y maneja el código duplicado.",
      },
      {
        num: "1.2",
        title: "SP_AJUSTAR_STOCK",
        description:
          "Registra entradas, salidas y ajustes de inventario por bodega, guarda el movimiento, impide existencias negativas y protege la lectura frente a cambios concurrentes.",
      },
      {
        num: "1.3",
        title: "SP_CREAR_PEDIDO",
        description:
          "Crea la cabecera de un pedido en estado BORRADOR y rechaza, con mensajes distintos, a clientes inactivos o sin cupo de crédito.",
      },
      {
        num: "2.1",
        title: "FN_STOCK_DISPONIBLE",
        description:
          "Devuelve el stock de un producto en una bodega o el consolidado de todas, y retorna 0 si el producto no existe.",
      },
      {
        num: "2.2",
        title: "FN_CUPO_DISPONIBLE",
        description:
          "Calcula el cupo de crédito disponible del cliente (cupo menos saldo pendiente), con 0 para clientes inactivos y sin permitir valores negativos.",
      },
      {
        num: "2.3",
        title: "FN_CALCULAR_DESCUENTO",
        description:
          "Calcula el valor en pesos del descuento según el monto de la compra, con 2% adicional si el cliente no tiene saldo pendiente y un tope del 10%.",
      },
      {
        num: "2.4",
        title: "Funciones dentro de consultas SQL",
        description:
          "Lista los clientes activos ordenados por cupo disponible usando FN_CUPO_DISPONIBLE dentro de un SELECT y explica qué condiciones debe cumplir una función para usarse en SQL.",
      },
      {
        num: "3.1",
        title: "Cursor explícito de productos bajo el mínimo",
        description:
          "Recorre con OPEN, FETCH y CLOSE los productos con stock por debajo del mínimo y muestra un reporte con las unidades faltantes y el total.",
      },
      {
        num: "3.2",
        title: "Cursor parametrizado de pedidos",
        description:
          "Muestra los pedidos confirmados de un cliente en un rango de fechas, con su total y número de líneas, recibiendo los filtros como parámetros del cursor.",
      },
      {
        num: "3.3",
        title: "Cursor FOR UPDATE con WHERE CURRENT OF",
        description:
          "Ajusta el precio de los productos de una categoría sin tocar los inactivos ni bajar del margen mínimo, y explica el bloqueo que genera FOR UPDATE.",
      },
      {
        num: "3.4",
        title: "SP_LISTAR_MOVIMIENTOS con SYS_REFCURSOR",
        description:
          "Procedimiento que devuelve un cursor de referencia con los movimientos de un producto y un bloque anónimo que lo consume y lo cierra.",
      },
      {
        num: "3.5",
        title: "BULK COLLECT y FORALL",
        description:
          "Carga los productos de una categoría en una colección y actualiza su stock mínimo en bloque, explicando el costo de cambio de contexto que se evita.",
      },
      {
        num: "4.1",
        title: "FN_PRECIO_PRODUCTO",
        description:
          "Devuelve el precio de un producto por su código y maneja NO_DATA_FOUND y TOO_MANY_ROWS retornando -1 y -2 con un mensaje.",
      },
      {
        num: "4.2",
        title: "SP_VALIDAR_DESPACHO",
        description:
          "Verifica si se puede despachar una cantidad desde una bodega, usando una excepción propia que se lanza con RAISE cuando no hay suficiente stock.",
      },
      {
        num: "4.3",
        title: "SP_ANULAR_PEDIDO",
        description:
          "Anula un pedido usando RAISE_APPLICATION_ERROR con códigos propios para pedido inexistente, ya anulado o con más de 30 días.",
      },
      {
        num: "4.4",
        title: "Excepción con nombre para ORA-02291",
        description:
          "Intenta insertar un producto con una categoría inexistente y captura el error de integridad referencial asociándolo a una excepción con nombre (PRAGMA EXCEPTION_INIT).",
      },
      {
        num: "4.5",
        title: "SP_REGISTRAR_ERROR",
        description:
          "Guarda SQLCODE y SQLERRM en LOG_ERRORES con una transacción autónoma, para que el registro se conserve aunque la transacción principal haga ROLLBACK.",
      },
      {
        num: "5.1",
        title: "TRG_CLIENTE_BI",
        description:
          "Trigger BEFORE INSERT que asigna el id desde una secuencia, pasa el nombre a mayúsculas sin espacios sobrantes y deja el cliente activo por defecto.",
      },
      {
        num: "5.2",
        title: "TRG_PRODUCTO_AU_PRECIO",
        description:
          "Registra en AUDITORIA_PRECIO cada cambio de precio con su variación porcentual, disparándose solo cuando el precio cambia gracias a la cláusula WHEN.",
      },
      {
        num: "5.3",
        title: "TRG_PRODUCTO_BIU_MARGEN",
        description:
          "Impide guardar un producto cuyo precio no alcanza el margen mínimo de su categoría, rechazando la operación con el error -20020.",
      },
      {
        num: "5.4",
        title: "TRG_DETALLE_AI_STOCK",
        description:
          "Al insertar una línea de pedido descuenta el stock de la bodega, registra la salida y aborta con el error -20030 si no hay stock suficiente.",
      },
      {
        num: "5.5",
        title: "TRG_DETALLE_TOTAL",
        description:
          "Recalcula el total del pedido cuando cambian sus líneas y documenta el error de tabla mutante del primer intento y cómo se resolvió.",
      },
      {
        num: "5.6",
        title: "TRG_V_STOCK_IO",
        description:
          "Trigger INSTEAD OF que permite actualizar precio y stock mínimo a través de la vista V_STOCK_CONSOLIDADO, que no es actualizable directamente.",
      },
      {
        num: "6.1",
        title: "Caso integrador: PKG_VENTAS",
        description:
          "Paquete con SP_FACTURAR_PEDIDO, que valida el pedido, acumula sus líneas con un cursor, aplica descuento, revisa el cupo, confirma el pedido y usa SAVEPOINT para revertir y registrar errores. Incluye pruebas con varios casos.",
      },
    ],
  },

  // ============================== NoSQL ==============================
  {
    slug: "practica-mql-airbnb",
    panel: "NoSQL",
    title: "Práctica MQL: sample_airbnb",
    summary:
      "Operaciones CRUD en MongoDB sobre la colección listingsAndReviews: inserciones con objetos anidados y arrays, validación de la unicidad del _id, y consultas con filtros, proyecciones, operadores de comparación, regex, arrays, ordenamiento y límite.",
    folder: "",
    file: "practica_MQL_sample_airbnb.js",
    exercises: [
      {
        num: "1",
        title: "insertOne básico",
        description:
          "Inserta un nuevo listing \"Cozy Cabin Retreat\" con summary, property_type \"Cabin\" y precio 150.",
      },
      {
        num: "2",
        title: "insertOne con objeto anidado",
        description:
          "Inserta un listing con una dirección anidada que incluye el país (Chile) y el mercado (Santiago).",
      },
      {
        num: "3",
        title: "insertMany simple",
        description:
          "Inserta dos listings en una sola operación: \"Studio de Arte Urbano\" (80) y \"Loft Minimalista\" (110).",
      },
      {
        num: "4",
        title: "insertMany con arrays",
        description:
          "Inserta un listing con un array amenities de varios elementos (Wifi, Kitchen, Free parking, Air conditioning).",
      },
      {
        num: "5",
        title: "Validación de _id",
        description:
          "Busca un listing existente e intenta insertar otro con el mismo _id, para comprobar el error de llave duplicada que garantiza la unicidad del _id.",
      },
      {
        num: "6",
        title: "find por país",
        description: "Consulta los listings ubicados en Brazil filtrando por el campo anidado address.country.",
      },
      {
        num: "7",
        title: "find con $gt",
        description: "Encuentra los listings con más de 5 camas y proyecta solo el nombre y el número de reseñas.",
      },
      {
        num: "8",
        title: "find con $lt",
        description: "Encuentra los listings con precio menor a 75 y proyecta nombre, precio y tipo de propiedad.",
      },
      {
        num: "9",
        title: "find con $and y objeto anidado",
        description: "Busca los listings de tipo Apartment ubicados en el mercado de New York.",
      },
      {
        num: "10",
        title: "find con $in",
        description: "Encuentra los listings cuyo tipo de propiedad es House o Condominium.",
      },
      {
        num: "11",
        title: "find con regex",
        description:
          "Busca los listings cuyo nombre contiene la palabra \"Luxury\" sin distinguir mayúsculas de minúsculas.",
      },
      {
        num: "12",
        title: "find en array",
        description: "Encuentra los listings que incluyen \"Heating\" dentro de su array de amenities.",
      },
      {
        num: "13",
        title: "find con $size",
        description: "Encuentra los listings que tienen exactamente 20 amenities.",
      },
      {
        num: "14",
        title: "find con sort y limit",
        description: "Muestra los 10 listings más caros con su nombre, precio y país, ordenados de mayor a menor precio.",
      },
    ],
  },
  {
    slug: "taller-nosql",
    panel: "NoSQL",
    title: "Taller NoSQL: MongoDB",
    summary:
      "Consultas MQL sobre la base de ejemplo sample_mflix con find, filtros, pipelines de agregación ($group, $lookup, $switch), actualizaciones, borrados e índices; y diseño de modelos documentales para una plataforma de domicilios y una red social.",
    folder: "tallerNOSQL_Lozano_Perez_Poveda",
    file: "taller_Lozano_Perez_Poveda.js",
    extras: [
      { label: "Documento del taller (PDF)", file: "taller_Lozano_Perez_Poveda.pdf" },
      { label: "Caso 1: diagrama", file: "Caso1.jpeg" },
      { label: "Caso 1: documentos JSON", file: "rappi_documentos.json" },
      { label: "Caso 3: diagrama", file: "Caso3.jpeg" },
      { label: "Caso 3: documentos JSON", file: "red_social.json" },
    ],
    exercises: [
      {
        num: "1",
        title: "Dramas de 2000 a 2010 con rating alto",
        description:
          "Busca películas de drama estrenadas entre 2000 y 2010 con rating IMDb de 8 o más, muestra el top 10 ordenado por rating y cuenta el total.",
      },
      {
        num: "2",
        title: "Películas de Tom Hanks no dirigidas por Spielberg",
        description:
          "Combina con $and la condición de reparto y $ne sobre los directores para excluir las películas de Steven Spielberg.",
      },
      {
        num: "3",
        title: "Comedias románticas con exactamente 3 géneros",
        description:
          "Usa $all y $size para encontrar películas que incluyen Comedy y Romance y tienen exactamente tres géneros.",
      },
      {
        num: "4",
        title: "Películas sin clasificación",
        description:
          "Con $or, $exists y $in lista las películas sin el campo rated o marcadas como UNRATED o NOT RATED, y las cuenta.",
      },
      {
        num: "5",
        title: "Títulos que empiezan por 'The' y terminan en 'Man'",
        description:
          "Usa una expresión regular sin distinguir mayúsculas para filtrar los títulos.",
      },
      {
        num: "6",
        title: "Estadísticas de rating por género",
        description:
          "Pipeline con $unwind y $group que calcula número de películas, rating promedio y máximo por género, solo para géneros con más de 500 películas.",
      },
      {
        num: "7",
        title: "Top 5 de directores con mejores películas",
        description:
          "Agrupa por director las películas con rating de 7.5 o más y muestra los 5 con más títulos (mínimo 5), con hasta 3 títulos de ejemplo.",
      },
      {
        num: "8",
        title: "Películas por década",
        description:
          "Agrupa las películas desde 1950 por década usando $subtract y $mod, y muestra cada década como texto (por ejemplo, 1990s) con su total.",
      },
      {
        num: "9",
        title: "Top 10 de películas más comentadas",
        description:
          "Cuenta los comentarios por película y usa $lookup para traer título y año desde la colección movies.",
      },
      {
        num: "10",
        title: "Usuarios con más de 250 comentarios",
        description:
          "Agrupa los comentarios por email y muestra la cantidad y las fechas del primer y último comentario de los usuarios más activos.",
      },
      {
        num: "11",
        title: "Nueva colección con $out y $switch",
        description:
          "Crea la colección peliculas_pareja con las películas de 2015 y una categoría calculada (Alta, Media o Baja) según su rating.",
      },
      {
        num: "12",
        title: "Actualización con updateMany",
        description:
          "Marca como revisadas las películas de categoría Media e incrementa su rating en 0.1, reportando matchedCount y modifiedCount.",
      },
      {
        num: "13",
        title: "Borrado con deleteMany",
        description: "Elimina las películas de categoría Baja y reporta cuántos documentos se borraron.",
      },
      {
        num: "14",
        title: "Índice compuesto con la regla ESR",
        description:
          "Compara con explain('executionStats') la consulta del punto 1 antes y después de crear un índice compuesto en orden igualdad, orden y rango, y luego elimina el índice.",
      },
      {
        num: "Caso 1",
        title: "Plataforma de domicilios",
        description:
          "Modelo con colecciones de clientes, restaurantes, productos, repartidores, reseñas y pedidos. El pedido referencia al cliente, restaurante, producto y repartidor, y guarda el menú embebido; el restaurante conserva sus reseñas más recientes.",
      },
      {
        num: "Caso 3",
        title: "Red social",
        description:
          "Modelo con cuentas, publicaciones, comentarios y seguidores. Las publicaciones embeben los comentarios recientes y las métricas, y los seguidores que no caben en la cuenta se guardan paginados en una colección aparte.",
      },
    ],
  },
];

export const scriptsByPanel = (panel: string) => scripts.filter((s) => s.panel === panel);
