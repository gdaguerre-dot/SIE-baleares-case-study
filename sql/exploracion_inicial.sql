-- ============================================================================
-- Exploración inicial de un esquema desconocido — replicando en SQL puro
-- lo que se hizo originalmente con Python/regex sobre el archivo de texto.
--
-- No modifica nada. Solo consultas de lectura contra el catálogo del motor
-- (information_schema — estándar ANSI, funciona igual en PostgreSQL y en
-- SQL Server, con las notas de adaptación marcadas donde corresponde).
--
-- Requiere tener ya cargada la base (ver bd_sie_postgres.sql / instrucciones
-- de importación). Ejecutar contra el esquema "sie_real".
-- ============================================================================

-- Postgres: fijar el esquema de trabajo (en SQL Server no existe SET search_path;
-- ahí se usa el prefijo esquema.tabla directamente, ej. sie_real.actuacions)
SET search_path TO sie_real;


-- ============================================================================
-- 1. ¿Cuántas tablas tiene este esquema, y cómo se llaman?
--    (esto es lo primero que se corrió sobre el archivo original con
--     `grep -oP "CREATE TABLE \`\K[^\`]+"`  — acá el equivalente en SQL puro)
-- ============================================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'sie_real'      -- SQL Server: cambiar por el schema/DB que corresponda
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- cuántas son en total
SELECT COUNT(*) AS n_tablas
FROM information_schema.tables
WHERE table_schema = 'sie_real' AND table_type = 'BASE TABLE';


-- ============================================================================
-- 2. ¿Qué columnas tiene cada tabla, y de qué tipo?
--    (equivalente a haber mirado cada CREATE TABLE del archivo original)
-- ============================================================================

SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'sie_real'
ORDER BY table_name, ordinal_position;

-- cuántas columnas tiene cada tabla (para detectar rápido cuáles son
-- catálogos simples de 2 columnas vs. tablas más complejas)
SELECT table_name, COUNT(*) AS n_columnas
FROM information_schema.columns
WHERE table_schema = 'sie_real'
GROUP BY table_name
ORDER BY n_columnas DESC;

-- detalle de una tabla puntual (cambiar 'actuacions' por la que se quiera inspeccionar)
SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'sie_real' AND table_name = 'actuacions'
ORDER BY ordinal_position;


-- ============================================================================
-- 3. ¿Cuántas filas tiene cada tabla?
--    (equivalente a los conteos de INSERTs que se hicieron con regex sobre
--     el texto del dump original)
-- ============================================================================

-- Portable (funciona igual en Postgres y en SQL Server): una fila por tabla,
-- hay que listarlas a mano una vez que ya se sabe cuáles son (paso 1).
SELECT 'illa' AS tabla, COUNT(*) AS filas FROM illa
UNION ALL SELECT 'municipi', COUNT(*) FROM municipi
UNION ALL SELECT 'centres', COUNT(*) FROM centres
UNION ALL SELECT 'tipus_actuacio', COUNT(*) FROM tipus_actuacio
UNION ALL SELECT 'subtipus_actuacio', COUNT(*) FROM subtipus_actuacio
UNION ALL SELECT 'superestat_actuacio', COUNT(*) FROM superestat_actuacio
UNION ALL SELECT 'estat_actuacio', COUNT(*) FROM estat_actuacio
UNION ALL SELECT 'subestat_actuacio', COUNT(*) FROM subestat_actuacio
UNION ALL SELECT 'prioritat_actuacio', COUNT(*) FROM prioritat_actuacio
UNION ALL SELECT 'origen_actuacio', COUNT(*) FROM origen_actuacio
UNION ALL SELECT 'desti_actuacio', COUNT(*) FROM desti_actuacio
UNION ALL SELECT 'mode_enviament', COUNT(*) FROM mode_enviament
UNION ALL SELECT 'tecnic', COUNT(*) FROM tecnic
UNION ALL SELECT 'actuacions', COUNT(*) FROM actuacions
UNION ALL SELECT 'seguiment_actuacio', COUNT(*) FROM seguiment_actuacio
UNION ALL SELECT 'document_actuacio', COUNT(*) FROM document_actuacio
UNION ALL SELECT 'informe_actuacio', COUNT(*) FROM informe_actuacio
UNION ALL SELECT 'estat_conveni', COUNT(*) FROM estat_conveni
UNION ALL SELECT 'conveni', COUNT(*) FROM conveni
UNION ALL SELECT 'centre_conveni', COUNT(*) FROM centre_conveni
UNION ALL SELECT 'actuacio_conveni', COUNT(*) FROM actuacio_conveni
UNION ALL SELECT 'tipus_document_actuacio_conveni', COUNT(*) FROM tipus_document_actuacio_conveni
UNION ALL SELECT 'document_conveni', COUNT(*) FROM document_conveni
UNION ALL SELECT 'pagament_conveni', COUNT(*) FROM pagament_conveni
UNION ALL SELECT 'espai', COUNT(*) FROM espai
UNION ALL SELECT 'assignar_espais', COUNT(*) FROM assignar_espais
UNION ALL SELECT 'tipus_centre_educatiu', COUNT(*) FROM tipus_centre_educatiu
UNION ALL SELECT 'comissio_seguiment', COUNT(*) FROM comissio_seguiment
UNION ALL SELECT 'actuacions_seq', COUNT(*) FROM actuacions_seq
UNION ALL SELECT 'conveni_seq', COUNT(*) FROM conveni_seq
ORDER BY filas DESC;

-- Solo PostgreSQL — versión dinámica (no hace falta listar las tablas a mano):
-- recorre information_schema y cuenta cada tabla automáticamente.
DO $$
DECLARE
    r RECORD;
    cnt BIGINT;
BEGIN
    FOR r IN
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'sie_real' AND table_type = 'BASE TABLE'
        ORDER BY table_name
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I.%I', 'sie_real', r.table_name) INTO cnt;
        RAISE NOTICE '% -> % filas', r.table_name, cnt;
    END LOOP;
END $$;
-- (el resultado aparece en la pestaña "Messages"/"Notices" de pgAdmin, no como
--  una tabla de resultados — es normal, así funciona RAISE NOTICE)


-- ============================================================================
-- 4. ¿Qué tablas están vacías? (catálogos sin poblar — hallazgo real que
--    se detectó en el análisis inicial: tipus_centre_educatiu, comissio_seguiment)
-- ============================================================================

SELECT 'tipus_centre_educatiu' AS tabla, COUNT(*) AS filas FROM tipus_centre_educatiu
UNION ALL SELECT 'comissio_seguiment', COUNT(*) FROM comissio_seguiment
UNION ALL SELECT 'document_actuacio_conveni', COUNT(*) FROM document_actuacio_conveni
HAVING COUNT(*) = 0;
-- Nota: HAVING sin GROUP BY funciona en Postgres tratando todo el resultado
-- como un solo grupo; en SQL Server también es válido. Si el motor se queja,
-- envolver en un WHERE aparte sobre una subconsulta como alternativa portable.


-- ============================================================================
-- 5. Relaciones entre tablas (claves foráneas) — el "mapa" de FKs que se
--    usó para construir el diagrama entidad-relación del case study
-- ============================================================================

-- PostgreSQL: vía information_schema (portable, funciona también en SQL Server
-- con el mismo esquema de vistas, aunque los nombres de catálogo interno difieren)
SELECT
    tc.table_name        AS tabla_origen,
    kcu.column_name       AS columna_fk,
    ccu.table_name        AS tabla_referenciada,
    ccu.column_name       AS columna_referenciada
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name AND tc.table_schema = ccu.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_schema = 'sie_real'
ORDER BY tabla_origen, columna_fk;


-- ============================================================================
-- 6. Calidad de datos: nulos por columna en la tabla más importante
--    (equivalente al hallazgo original de fechas '0000-00-00' → ahora NULL)
-- ============================================================================

SELECT
    COUNT(*)                                              AS total_filas,
    COUNT(*) FILTER (WHERE data_enviament IS NULL)        AS sin_data_enviament,
    COUNT(*) FILTER (WHERE tecnic_id IS NULL)              AS sin_tecnico,
    COUNT(*) FILTER (WHERE centre_id IS NULL)              AS sin_centro
FROM actuacions;
-- SQL Server no soporta FILTER (WHERE ..): usar
--   SUM(CASE WHEN data_enviament IS NULL THEN 1 ELSE 0 END)  en su lugar.
