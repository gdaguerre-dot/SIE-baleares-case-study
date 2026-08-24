# `sql/` — trabajo en SQL sobre el sistema SIE Balears

Tres scripts, dos categorías distintas. La diferencia importante no es el tema (todos tocan actuaciones/centros/técnicos), es **si dependen de datos que no están en este repositorio**.

## 1. Reproducible por cualquiera — `sie_practica.sql`

Autocontenido: crea su propio esquema (`CREATE TABLE`) y genera sus propios datos falsos con `generate_series` y `random()` — no depende de nada externo. Cubre DDL, DML, JOINs, subconsultas, CTEs, funciones de ventana, vistas, y una función PL/pgSQL, organizado en bloques temáticos tipo EDA.

**Cualquiera que clone este repo puede abrirlo en pgAdmin (o adaptarlo a SQL Server, notas al final del archivo) y correrlo de punta a punta sin pedirle nada a nadie.**

> **Nota de reproducibilidad.** Como el script usa `random()` de forma intencional, cada ejecución genera una distribución *equivalente pero no idéntica*: mismo volumen (500 filas en `actuacions`), mismos rangos y proporciones, pero no exactamente los mismos números. Los datos del dashboard (`docs/dashboard.html`) corresponden a una ejecución congelada de este script, generada el 23/08/2026 directamente contra PostgreSQL 16 y volcada tal cual — no son datos inventados a mano. Volver a correr el script producirá cifras ligeramente distintas; eso es el comportamiento esperado, no un error.
>
> El script fue corregido el 23/08/2026: la versión original tenía un bug real donde `centre_id`, `subtipus_id`, `estat_id` y `data_entrada` no variaban entre filas, porque PostgreSQL trataba las subconsultas `(SELECT id FROM tabla ORDER BY random() LIMIT 1)` como no correlacionadas y las ejecutaba una sola vez para las 500 filas (`InitPlan`). El fix fuerza una correlación trivial (`WHERE s > 0`) con la fila del `generate_series` para garantizar que cada fila obtenga su propio valor aleatorio.

> **Verificación del fix.** Se corrió el script corregido contra PostgreSQL 16 real y se midió la cardinalidad de valores distintos por columna antes y después, sobre las 500 filas de `actuacions`:
>
> | Columna | Antes del fix (valores distintos / 500) | Después del fix |
> |---|---:|---:|
> | `centre_id` | 1 | 60 |
> | `subtipus_id` | 1 | 27 |
> | `estat_id` | 1 | 10 |
> | `data_entrada` | 1 | 330 |
> | `tecnic_id` | 2 | 4 (+ NULL ~15%) |
>
> `pressupost` no se vio afectada porque ahí `random()` se usa directo en el SELECT, sin subconsulta — de ahí que esa columna sí variara correctamente incluso en la versión con el bug. Los agregados se extrajeron con `jsonb_object_agg`/`jsonb_agg` directamente desde SQL (sin transcripción manual) y el objeto `AGG` de `docs/dashboard.html` corresponde a esa salida real: 500 actuaciones, repartidas Mallorca 253 / Menorca 118 / Eivissa 97 / Formentera 32.

## 2. Documentación de proceso real — `exploracion_inicial.sql` y `eda_real.sql`

Estos dos corren contra el esquema real del sistema (`sie_real`), reconstruido a partir de un dump de producción que **no está en este repositorio** por confidencialidad. Documentan preguntas y consultas reales que se hicieron, pero no se pueden ejecutar sin esos datos.

- **`exploracion_inicial.sql`** — reconocimiento del esquema: qué tablas hay, qué columnas, qué tipos, cómo se relacionan (FKs), cuántas filas tiene cada una. Usa `information_schema`, portable entre PostgreSQL y SQL Server.
- **`eda_real.sql`** — preguntas de negocio: actuaciones por isla, presupuesto, prioridad, convenios con ayuntamientos, carga de trabajo por técnico.

Ambos son seguros para un repositorio público aunque documenten trabajo sobre datos reales, porque:
- Solo contienen **definiciones de consultas** (texto SQL), nunca datos.
- Cada consulta evita explícitamente columnas con información personal: nunca `SELECT` de `centres.email`, `centres.Telefon`, `actuacions.descripcio`, `actuacions.observacions`, `tecnic.nom`, ni nombres de archivo/URLs de documentos. Solo conteos, promedios, agrupaciones y JOINs sobre columnas de catálogo.

**No subir nunca a este repositorio**: la base de datos real convertida (`bd_sie_postgres.sql`) ni ningún resultado exportado (CSV, capturas) de correr estas consultas contra los datos reales.
