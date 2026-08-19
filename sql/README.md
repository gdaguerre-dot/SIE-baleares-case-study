# `sql/` — trabajo en SQL sobre el sistema SIE Balears

Tres scripts, dos categorías distintas. La diferencia importante no es el tema (todos tocan actuaciones/centros/técnicos), es **si dependen de datos que no están en este repositorio**.

## 1. Reproducible por cualquiera — `sie_practica.sql`

Autocontenido: crea su propio esquema (`CREATE TABLE`) y genera sus propios datos falsos con `generate_series` y `random()` — no depende de nada externo. Cubre DDL, DML, JOINs, subconsultas, CTEs, funciones de ventana, vistas, y una función PL/pgSQL, organizado en bloques temáticos tipo EDA.

**Cualquiera que clone este repo puede abrirlo en pgAdmin (o adaptarlo a SQL Server, notas al final del archivo) y correrlo de punta a punta sin pedirle nada a nadie.**

## 2. Documentación de proceso real — `exploracion_inicial.sql` y `eda_real.sql`

Estos dos corren contra el esquema real del sistema (`sie_real`), reconstruido a partir de un dump de producción que **no está en este repositorio** por confidencialidad. Documentan preguntas y consultas reales que se hicieron, pero no se pueden ejecutar sin esos datos.

- **`exploracion_inicial.sql`** — reconocimiento del esquema: qué tablas hay, qué columnas, qué tipos, cómo se relacionan (FKs), cuántas filas tiene cada una. Usa `information_schema`, portable entre PostgreSQL y SQL Server.
- **`eda_real.sql`** — preguntas de negocio: actuaciones por isla, presupuesto, prioridad, convenios con ayuntamientos, carga de trabajo por técnico.

Ambos son seguros para un repositorio público aunque documenten trabajo sobre datos reales, porque:
- Solo contienen **definiciones de consultas** (texto SQL), nunca datos.
- Cada consulta evita explícitamente columnas con información personal: nunca `SELECT` de `centres.email`, `centres.Telefon`, `actuacions.descripcio`, `actuacions.observacions`, `tecnic.nom`, ni nombres de archivo/URLs de documentos. Solo conteos, promedios, agrupaciones y JOINs sobre columnas de catálogo.

**No subir nunca a este repositorio**: la base de datos real convertida (`bd_sie_postgres.sql`) ni ningún resultado exportado (CSV, capturas) de correr estas consultas contra los datos reales.

## Regla al agregar una consulta nueva a `exploracion_inicial.sql` o `eda_real.sql`

Antes de agregarla, preguntate: *"¿el resultado de esto podría contener el nombre de una persona, un email, un teléfono o una URL interna?"* Si la respuesta es sí, agregala igual pero dejá anotado que es solo para uso local — nunca para pegar el resultado en ningún lado público, ni siquiera como captura de pantalla.
