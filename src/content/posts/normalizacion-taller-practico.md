---
title: "Normalización — Taller Práctico"
date: "3/20/2025"
author: "Sebastián Pérez Herrera"
tags: ["Normalización"]
readTime: "6 min read"
excerpt: "Taller de práctica con cuatro ejercicios de normalización hasta 3FN: proyectos-empleados, estudiantes-cursos, visitas médicas y alquiler de películas."
---

## Descripción

Taller de práctica con cuatro ejercicios de normalización progresiva (1FN → 2FN → 3FN), aplicando atomicidad, eliminación de grupos repetidos, dependencias parciales y transitivas.

---

## Ejercicio 1 — Proyectos y Empleados

### Esquema inicial (sin normalizar)

```
(cod_proyecto, nom_proyecto, cod_empleado, nom_empleado,
profesion, vlr_hora, hrs_asignadas)
```

El modelo no está normalizado: un proyecto se repite por cada empleado asignado, generando redundancia.

### 1FN — Atomicidad y separación de grupos repetidos

Se separan en tres tablas para eliminar los grupos repetidos:

- **PROYECTO** (`cod_proyecto`, nom_proyecto)
- **PROYECTO_EMPLEADO** (`cod_proyecto`, `cod_empleado`, hrs_asignadas) → PK compuesta
- **EMPLEADO** (`cod_empleado`, nom_empleado, profesion, vlr_hora)

### 2FN — Dependencias parciales

Todos los atributos dependen completamente de su clave. El esquema ya está en 2FN tras el paso anterior.

### 3FN — Dependencias transitivas

Se detecta que `vlr_hora` depende de `profesion`, no directamente de `cod_empleado`. Se extrae:

- **EMPLEADO** (`cod_empleado`, nom_empleado, cod_profesion) → FK: `cod_profesion`
- **PROFESION** (`cod_profesion`, profesion, vlr_hora)
- **PROYECTO** y **PROYECTO_EMPLEADO** sin cambios.

---

## Ejercicio 2 — Estudiantes y Cursos

### Esquema inicial (sin normalizar)

```
(Cod, Name, Email, Courses, GradePoints)
```

No está en 1FN: los campos `Courses` y `GradePoints` contienen múltiples valores separados por comas (falta de atomicidad).

### 1FN — Atomicidad

Se descompone para que cada fila tenga un solo valor por campo:

| Cod | Name | Email | Courses | GradePoints |
|---|---|---|---|---|
| 100111 | John Doe | doe@usna.edu | NN204 | 2 |
| 100111 | John Doe | doe@usna.edu | SI204 | 3 |
| ... | ... | ... | ... | ... |

Luego se separa en tablas:

- **ESTUDIANTE** (`Cod`, Name, Email)
- **CURSO** (`cod_Curse`, Courses)
- **ESTUDIANTE_CURSO** (`Cod`, `cod_Curse`, GradePoints) → FK: `Cod`, `cod_Curse`

### 2FN y 3FN

El esquema resultante ya cumple 2FN y 3FN: no hay dependencias parciales ni transitivas.

---

## Ejercicio 3 — Visitas Médicas

### Esquema inicial (sin normalizar)

```
(VisitaNo, DiaVisita, PacNo, PacEdad, PacCiudad,
ProvNo, ProvEspecialidad, Diagnostico)
```

Un paciente puede tener varios profesionales en la misma visita, y un diagnóstico diferente por cada uno → grupo repetido.

### 1FN — Separación de grupos repetidos

- **VISITA_PACIENTE** (`VisitaNo`, DiaVisita, PacNo, PacEdad, PacCiudad)
- **PROFESIONAL** (`ProvNo`, ProvEspecialidad)
- **VISITA_PROFESIONAL** (`VisitaNo`, `ProvNo`, Diagnostico) → FK: `VisitaNo`, `ProvNo`

### 2FN y 3FN

Tras la separación, todos los atributos dependen completamente de sus llaves. El modelo ya está en 3FN.

---

## Ejercicio 4 — Alquiler de Películas

### Esquema inicial (sin normalizar)

```
(RentalID, Title, CustomerID, MailedOutDate,
Director, MovieCategory, Price)
```

Un alquiler puede incluir varias películas → grupo repetido. El precio depende de la categoría, no del alquiler → dependencia transitiva.

### 1FN — Separación de grupos repetidos

- **ALQUILER** (`RentalID`, CustomerID, MailedOutDate)
- **PELICULA** (`Title`, Director, MovieCategory, Price)
- **ALQUILER_PELICULA** (`RentalID`, `Title`) → FK: `RentalID`, `Title`

### 2FN — Dependencias parciales

Los atributos del alquiler y de la película ya dependen completamente de su respectiva clave. Sin cambios adicionales.

### 3FN — Dependencias transitivas

Se detecta que `Price` depende de `MovieCategory`, no directamente del título. Se extrae:

- **PELICULA** (`Title`, Director, MovieCategory) → FK: `MovieCategory`
- **CATEGORIA** (`MovieCategory`, Price)

## Archivo del ejercicio

Ingreso al taller (Excel con la solución completa): [Ver archivo](https://drive.google.com/file/d/18cFeP9F3HFqef52bL8cAcNfVfMyMgXfb/view?usp=sharing)
