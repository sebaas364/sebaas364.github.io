// Ejercicios de práctica mostrados en la página de Evidencias.
// "panel" debe coincidir con el tag del panel en src/pages/posts.astro.
// Los archivos viven en public/evidencias/.
export interface Ejercicio {
  panel: "SQL" | "PL/SQL Scripts" | "NoSQL";
  title: string;
  description: string;
  url: string;
}

export const ejercicios: Ejercicio[] = [
  // ---------------- SQL ----------------
  {
    panel: "SQL",
    title: "Ejercicios de práctica SQL",
    description:
      "Consultas sobre el esquema HR de Oracle: JOINs entre empleados, departamentos, ciudades y países, agrupaciones con HAVING, subconsultas, casos borde (empleados sin jefe o sin departamento) y la diferencia entre filtrar en ON y en WHERE.",
    url: "/evidencias/ejercios_practica_SQL.sql",
  },
  {
    panel: "SQL",
    title: "Taller Banco Andino: concurrencia e índices",
    description:
      "Simulación con dos sesiones de cajeros: actualización perdida, bloqueo pesimista con SELECT ... FOR UPDATE, control optimista con columna de versión y reparto de colas con SKIP LOCKED. También analiza planes de ejecución y cuándo conviene o no un índice.",
    url: "/evidencias/taller_bancoAndinoSQL_SebastianPerez_CamylaPoveda.sql",
  },

  // ---------------- PL/SQL ----------------
  {
    panel: "PL/SQL Scripts",
    title: "Práctica PL/SQL",
    description:
      "Cursor explícito que clasifica salarios del departamento 80 en ALTO, MEDIO y BAJO; procedimiento sp_subir_salario con validaciones y tope del cargo; función fn_costo_empleado que calcula el costo anual; y trigger de auditoría que impide bajar salarios.",
    url: "/evidencias/plsql_practica.sql",
  },
  {
    panel: "PL/SQL Scripts",
    title: "Taller PL/SQL (Grupo 2): sistema de inventario",
    description:
      "Procedimientos para registrar productos, ajustar stock y crear pedidos; funciones de stock y cupo disponible; cursores, manejo de excepciones, disparadores y un caso integrador de facturación, cada uno con su justificación.",
    url: "/evidencias/TALLER_PLSQL_GRUPO_2.sql",
  },

  // ---------------- NoSQL ----------------
  {
    panel: "NoSQL",
    title: "Taller MQL: consultas en MongoDB",
    description:
      "Consultas con find y filtros ($and, $or, $all, $size, expresiones regulares) y pipelines de agregación ($group, $switch) sobre la base de ejemplo sample_mflix.",
    url: "/evidencias/tallerNOSQL_Lozano_Perez_Poveda/taller_Lozano_Perez_Poveda.js",
  },
  {
    panel: "NoSQL",
    title: "Documento del taller NoSQL",
    description: "Informe en PDF con el desarrollo y los resultados del taller.",
    url: "/evidencias/tallerNOSQL_Lozano_Perez_Poveda/taller_Lozano_Perez_Poveda.pdf",
  },
  {
    panel: "NoSQL",
    title: "Caso 1: plataforma de domicilios (modelo)",
    description:
      "Diagrama del modelo documental para una app de domicilios: clientes, restaurantes, productos, repartidores, reseñas y pedidos.",
    url: "/evidencias/tallerNOSQL_Lozano_Perez_Poveda/Caso1.jpeg",
  },
  {
    panel: "NoSQL",
    title: "Caso 1: documentos de ejemplo (JSON)",
    description: "Documentos JSON de ejemplo que siguen el modelo de la plataforma de domicilios.",
    url: "/evidencias/tallerNOSQL_Lozano_Perez_Poveda/rappi_documentos.json",
  },
  {
    panel: "NoSQL",
    title: "Caso 3: red social (modelo)",
    description:
      "Diagrama del modelo documental de una red social: cuentas, publicaciones con comentarios recientes embebidos, comentarios y seguidores paginados.",
    url: "/evidencias/tallerNOSQL_Lozano_Perez_Poveda/Caso3.jpeg",
  },
  {
    panel: "NoSQL",
    title: "Caso 3: documentos de ejemplo (JSON)",
    description: "Documentos JSON de ejemplo que siguen el modelo de la red social.",
    url: "/evidencias/tallerNOSQL_Lozano_Perez_Poveda/red_social.json",
  },
];
