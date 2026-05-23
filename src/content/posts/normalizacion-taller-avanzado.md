---
title: "Normalización — Taller Avanzado"
date: "4/10/2025"
author: "Sebastián Pérez Herrera"
tags: ["Normalización"]
readTime: "8 min read"
excerpt: "Taller calificable con dos casos avanzados de normalización hasta 3FN: Sistema de Envío Internacional y Sistema Integral de Video Club."
---

## Descripción

Taller calificable con cuatro casos de dificultad elevada. Se aplica el proceso formal de normalización (1FN → 2FN → 3FN) identificando grupos repetidos, dependencias parciales y dependencias transitivas.

---

## Ejercicio 1 — Sistema de Envío Internacional (LOGISTIC SYSTEMS S.A.S.)

### Enunciado

La empresa LOGISTIC SYSTEMS S.A.S. presta servicios de envío puerta a puerta entre ciudades y países. Cada guía de envío puede amparar varios paquetes, es despachada por un empleado en un vehículo determinado y va asociada a un plan tarifario según la zona de destino. El sistema también registra eventos de rastreo (recogida, tránsito, aduana, entrega) y el medio de pago del cliente remitente.

**Esquema inicial sin normalizar:**

```
ENVIO(num_guia, fecha_guia, hora_guia, orgn_nit, orgn_nombre, orgn_actividad,
orgn_ciudad, orgn_pais, orgn_direccion, orgn_telefono, orgn_celular,
dest_id, dest_nombre, dest_cod_ciudad, dest_ciudad, dest_pais, dest_direccion,
dest_telefono, dest_km_desde_origen, cod_zona, nombre_zona, tarifa_base_zona,
cod_empleado, nombre_empleado, licencia_empleado, placa_vehiculo,
tipo_vehiculo, capacidad_vehiculo, cod_paquete, tipo_paquete, nombre_paquete,
descripcion_paquete, peso_paquete, valor_declarado, cant_unidades,
valor_flete_paquete, cod_evento, fecha_evento, estado_evento,
descripcion_evento, cod_pago, metodo_pago, valor_pagado)
```

### 1FN — Eliminar grupos repetidos

**Llave primaria:** `num_guia` (identificador único de cada guía de envío).

Se detectan dos grupos repetidos: los **paquetes** (cod_paquete y sus atributos) y los **eventos** de rastreo (cod_evento anidado dentro de cada paquete). Se extraen en tablas separadas:

- **GUIA** (`num_guia`, fecha_guia, hora_guia, orgn_nit, dest_id, cod_zona, cod_empleado, placa_vehiculo, cod_pago, metodo_pago, valor_pagado) → PK: `num_guia`
- **PAQUETE** (cod_paquete, tipo_paquete, nombre_paquete, descripcion_paquete, peso_paquete, valor_declarado, cant_unidades, valor_flete_paquete, num_guia) → PK: `cod_paquete`, FK: `num_guia`
- **EVENTO** (cod_evento, fecha_evento, estado_evento, descripcion_evento, num_guia, cod_paquete) → PK: `(cod_evento, num_guia, cod_paquete)`, FK: `num_guia`, `cod_paquete`

### 2FN — Eliminar dependencias parciales

Se separan los atributos que no dependen completamente de la llave primaria:

- **GUIA** (`num_guia`, fecha_guia, hora_guia, cod_empleado, placa_vehiculo, dest_id, cod_pago, metodo_pago, valor_pagado)
- **ORGANIZACION_REMITENTE** (`orgn_nit`, orgn_nombre, orgn_ciudad, orgn_pais, orgn_direccion, orgn_telefono, orgn_celular)
- **DESTINATARIO_ZONA** (`dest_id`, dest_nombre, dest_cod_ciudad, dest_ciudad, dest_pais, dest_direccion, dest_telefono, dest_km_desde_origen, cod_zona, nombre_zona, tarifa_base_zona)
- **EMPLEADO** (`cod_empleado`, nombre_empleado, licencia_empleado)
- **VEHICULO** (`placa_vehiculo`, tipo_vehiculo, capacidad_vehiculo)
- **PAQUETE** y **EVENTO** se mantienen igual.

### 3FN — Eliminar dependencias transitivas

Se detectan dependencias transitivas en DESTINATARIO_ZONA (dest_ciudad y dest_pais dependen de dest_cod_ciudad, no de dest_id; nombre_zona y tarifa_base_zona dependen de cod_zona) y en GUIA (metodo_pago y valor_pagado dependen de cod_pago):

- **GUIA** (`num_guia`, fecha_guia, hora_guia, cod_empleado, placa_vehiculo, dest_id)
- **PAGO** (`num_guia`, cod_pago, metodo_pago, valor_pagado) → FK: `num_guia`
- **DESTINATARIO** (`dest_id`, dest_nombre, dest_direccion, dest_telefono)
- **DESTINO_CIUDAD** (`dest_id`, dest_cod_ciudad, dest_ciudad, dest_pais, dest_km_desde_origen) → FK: `dest_id`
- **ZONA** (`dest_cod_ciudad`, cod_zona, nombre_zona, tarifa_base_zona)
- **EMPLEADO**, **VEHICULO**, **PAQUETE**, **EVENTO** sin cambios.

---

## Ejercicio 2 — Sistema Integral de Video Club (STREAM&GO)

### Enunciado

La cadena STREAM&GO administra locales que alquilan películas en DVD y Blu-ray. Cada película puede tener varias copias físicas, varios actores con roles distintos, un director y pertenecer a varias categorías. Los clientes se afilian con una membresía que determina un plan tarifario.

**Esquema inicial sin normalizar:**

```
ALQUILER(cod_alquiler, fecha_alquiler, num_membresia, cod_cliente, nom_cliente,
dir_cliente, tel_cliente, email_cliente, cod_plan, nombre_plan, tarifa_dia_plan,
dias_prestamo_max, cod_sucursal, nombre_sucursal, direccion_sucursal,
ciudad_sucursal, cod_cassette, formato_cassette, estado_cassette, cod_pelicula,
titulo_pelicula, anio_pelicula, cod_director, nombre_director,
nacionalidad_director, cod_categoria, nombre_categoria, recargo_categoria,
cod_actor, nombre_actor, fecha_nac_actor, rol_en_pelicula, fecha_prog_dev,
fecha_real_dev, dias_retraso, recargo_mora)
```

### 1FN — Eliminar grupos repetidos

**Llave primaria compuesta mínima:** `(cod_alquiler, cod_cassette, cod_actor, cod_categoria)` — necesaria porque un alquiler puede incluir varios casetes, cada película tiene varios actores y varias categorías.

Se identifican los grupos repetidos: cod_cassette (varios por alquiler), cod_actor (varios por película), cod_categoria (varias por película). Se extraen:

- **Tabla principal** con `(cod_alquiler, cod_cassette, cod_actor, cod_categoria)` como clave
- **CASSETTE** (`cod_cassette`, formato_cassette, estado_cassette) → PK: `cod_cassette`
- **CATEGORIA** (`cod_categoria`, nombre_categoria, recargo_categoria) → PK: `cod_categoria`
- **ACTOR** (`cod_actor`, nombre_actor, fecha_nac_actor) → PK: `cod_actor`

### 2FN — Eliminar dependencias parciales

Se separan todos los atributos que solo dependen de parte de la clave compuesta:

- **CLIENTE** (`cod_cliente`, nom_cliente, dir_cliente, tel_cliente, email_cliente)
- **PLAN** (`cod_plan`, nombre_plan, tarifa_dia_plan, dias_prestamo_max)
- **SUCURSAL** (`cod_sucursal`, nombre_sucursal, direccion_sucursal, ciudad_sucursal)
- **PELICULA** (`cod_pelicula`, titulo_pelicula, anio_pelicula, cod_director)
- **DIRECTOR** (`cod_director`, nombre_director, nacionalidad_director)
- **PELICULA_ACTOR** (`cod_pelicula`, `cod_actor`, rol_en_pelicula)
- **PELICULA_CATEGORIA** (`cod_pelicula`, `cod_categoria`)
- **ALQUILER** (`cod_alquiler`, fecha_alquiler, num_membresia, cod_sucursal, cod_cliente, cod_plan)
- **ALQUILER_TOTAL** (`cod_alquiler`, `cod_cassette`, fecha_prog_dev, fecha_real_dev, dias_retraso, recargo_mora)

### 3FN — Eliminar dependencias transitivas

Se detecta que en ALQUILER: `cod_cliente` depende de `num_membresia` (transitiva), y `cod_plan` depende de `num_membresia`. Se extrae:

- **MEMBRESIA** (`num_membresia`, cod_cliente, cod_alquiler) → FK: `cod_cliente`
- **ALQUILER** (`cod_alquiler`, fecha_alquiler, cod_sucursal, cod_membresia)
- **PELICULA** (`cod_pelicula`, titulo_pelicula, anio_pelicula, cod_director) → FK: `cod_director`
- **CASSETTE** (`cod_cassette`, formato_cassette, estado_cassette, cod_pelicula) → FK: `cod_pelicula`
- **CLIENTE**, **PLAN**, **SUCURSAL**, **DIRECTOR**, **ACTOR**, **CATEGORIA**, **PELICULA_ACTOR**, **PELICULA_CATEGORIA**, **ALQUILER_TOTAL** sin cambios.

## Archivo del ejercicio

Ingreso al taller (Excel con la solución completa): [Ver archivo](https://drive.google.com/file/d/18cFeP9F3HFqef52bL8cAcNfVfMyMgXfb/view?usp=sharing)
