-- ============================================================================
-- SIE Balears — Script de práctica SQL
-- Basado en el modelo de datos real de un sistema de gestión de actuaciones
-- de infraestructura educativa (esquema fiel; datos 100% sintéticos).
--
-- Motor objetivo principal: PostgreSQL 14+
-- Notas de adaptación a SQL Server al final del archivo (sección 5).
--
-- Cómo correrlo:
--   psql -U tu_usuario -d tu_base -f sie_practica.sql
--   (o pegarlo por bloques en pgAdmin / DBeaver)
-- ============================================================================


-- ============================================================================
-- SECCIÓN 0 — SETUP
-- ============================================================================

DROP SCHEMA IF EXISTS sie CASCADE;
CREATE SCHEMA sie;
SET search_path TO sie;


-- ============================================================================
-- SECCIÓN 1 — DDL: creación de tablas
-- (Esquema simplificado y fiel al real: catálogos + núcleo de actuaciones +
--  módulo geográfico + módulo de convenios)
-- ============================================================================

CREATE TABLE illa (
    id      SERIAL PRIMARY KEY,
    nom     VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE municipi (
    id       SERIAL PRIMARY KEY,
    illa_id  INT NOT NULL REFERENCES illa(id),
    nom      VARCHAR(60) NOT NULL
);

CREATE TABLE centres (
    id           SERIAL PRIMARY KEY,
    nom          VARCHAR(120) NOT NULL,
    tipus        VARCHAR(20) NOT NULL CHECK (tipus IN ('Public','Concertat','Privat')),
    illa_id      INT NOT NULL REFERENCES illa(id),
    municipi_id  INT NOT NULL REFERENCES municipi(id)
);

CREATE TABLE tipus_actuacio (
    id    SERIAL PRIMARY KEY,
    nom   VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE subtipus_actuacio (
    id                SERIAL PRIMARY KEY,
    tipus_actuacio_id INT NOT NULL REFERENCES tipus_actuacio(id),
    nom               VARCHAR(120) NOT NULL
);

CREATE TABLE superestat_actuacio (
    id      SERIAL PRIMARY KEY,
    nom     VARCHAR(30) NOT NULL UNIQUE,
    ordre   INT NOT NULL
);

CREATE TABLE estat_actuacio (
    id                    SERIAL PRIMARY KEY,
    superestat_id         INT NOT NULL REFERENCES superestat_actuacio(id),
    nom                   VARCHAR(60) NOT NULL,
    ordre                 INT NOT NULL
);

CREATE TABLE prioritat_actuacio (
    id      SERIAL PRIMARY KEY,
    nom     VARCHAR(20) NOT NULL UNIQUE,
    pes     INT NOT NULL          -- 1=Baixa 2=Mitjana 3=Alta, para poder ordenar
);

CREATE TABLE tecnic (
    id      SERIAL PRIMARY KEY,
    nom     VARCHAR(60) NOT NULL
);

-- Núcleo del modelo: cada actuación
CREATE TABLE actuacions (
    id              SERIAL PRIMARY KEY,
    codi            VARCHAR(20) NOT NULL UNIQUE,
    centre_id       INT NOT NULL REFERENCES centres(id),
    subtipus_id     INT NOT NULL REFERENCES subtipus_actuacio(id),
    estat_id        INT NOT NULL REFERENCES estat_actuacio(id),
    tecnic_id       INT REFERENCES tecnic(id),
    prioritat_id    INT NOT NULL REFERENCES prioritat_actuacio(id),
    pressupost      NUMERIC(10,2) NOT NULL DEFAULT 0,
    assumit_servei  BOOLEAN NOT NULL DEFAULT FALSE,
    descripcio      TEXT,
    data_entrada    DATE NOT NULL,
    data_resolucio  DATE,               -- NULL mientras no esté resuelta
    CHECK (data_resolucio IS NULL OR data_resolucio >= data_entrada)
);

CREATE TABLE seguiment_actuacio (
    id              SERIAL PRIMARY KEY,
    actuacio_id     INT NOT NULL REFERENCES actuacions(id),
    data_seguiment  TIMESTAMP NOT NULL DEFAULT now(),
    comentari       TEXT
);

CREATE TABLE conveni (
    id                SERIAL PRIMARY KEY,
    codi              VARCHAR(20) NOT NULL UNIQUE,
    municipi_id       INT NOT NULL REFERENCES municipi(id),
    import_total      NUMERIC(12,2) NOT NULL,
    data_signatura    DATE NOT NULL
);

CREATE TABLE centre_conveni (
    id           SERIAL PRIMARY KEY,
    conveni_id   INT NOT NULL REFERENCES conveni(id),
    centre_id    INT NOT NULL REFERENCES centres(id)
);

CREATE TABLE pagament_conveni (
    id            SERIAL PRIMARY KEY,
    conveni_id    INT NOT NULL REFERENCES conveni(id),
    import        NUMERIC(12,2) NOT NULL,
    data_pagament DATE NOT NULL
);

-- Índices sobre las columnas que más se van a filtrar/joinear (sección 3.11 los justifica)
CREATE INDEX idx_actuacions_centre   ON actuacions(centre_id);
CREATE INDEX idx_actuacions_estat    ON actuacions(estat_id);
CREATE INDEX idx_actuacions_tecnic   ON actuacions(tecnic_id);
CREATE INDEX idx_actuacions_data     ON actuacions(data_entrada);
CREATE INDEX idx_centres_municipi    ON centres(municipi_id);


-- ============================================================================
-- SECCIÓN 2 — DML: carga de datos de práctica
-- ============================================================================

INSERT INTO illa (nom) VALUES ('Mallorca'), ('Menorca'), ('Eivissa'), ('Formentera');

INSERT INTO municipi (illa_id, nom) VALUES
(1,'Palma'),(1,'Calvià'),(1,'Manacor'),(1,'Inca'),(1,'Marratxí'),(1,'Llucmajor'),
(2,'Maó'),(2,'Ciutadella'),(2,'Alaior'),
(3,'Eivissa'),(3,'Sant Antoni de Portmany'),(3,'Santa Eulària des Riu'),
(4,'Formentera');

-- 60 centros repartidos de forma realista (más peso en Mallorca)
INSERT INTO centres (nom, tipus, illa_id, municipi_id)
SELECT
    'CEIP ' || nom_generat,
    (ARRAY['Public','Public','Public','Concertat','Privat'])[1 + floor(random()*5)],
    m.illa_id,
    m.id
FROM (
    SELECT id, illa_id, ROW_NUMBER() OVER (ORDER BY random()) AS rn
    FROM municipi
) m
CROSS JOIN LATERAL (
    SELECT 'Centre ' || generate_series AS nom_generat
    FROM generate_series(1, 5)
) g
LIMIT 60;

INSERT INTO tipus_actuacio (nom) VALUES
('Climatització'),('Reformes i millores generals'),('Habilitació d''espais'),
('Banys i sanejament'),('Menjadors i cuines'),('Jocs de pati'),
('Goteres i impermeabilitzacions'),('Electricitat'),('Consulta tècnica');

INSERT INTO subtipus_actuacio (tipus_actuacio_id, nom)
SELECT id, nom || ' - ' || sub
FROM tipus_actuacio, (VALUES ('reparació'),('instal·lació nova'),('manteniment')) AS s(sub);

INSERT INTO superestat_actuacio (nom, ordre) VALUES
('Pendent',1), ('En procés',2), ('Resolta',3);

INSERT INTO estat_actuacio (superestat_id, nom, ordre) VALUES
(1,'Pendent',1),
(2,'Agafada',1),(2,'Pendent documentació',2),(2,'Redacció documentació tècnica',3),
(3,'Contestada',1),(3,'Desfavorable',2),(3,'Autorització recursos propis',3),
(3,'Contracte menor',4),(3,'Derivar IBISEC',5),(3,'Tancada',6);

INSERT INTO prioritat_actuacio (nom, pes) VALUES ('Baixa',1),('Mitjana',2),('Alta',3);

INSERT INTO tecnic (nom) VALUES ('Tècnic A'),('Tècnic B'),('Tècnic C'),('Tècnic D');

-- 500 actuaciones sintéticas, con fechas y estados distribuidos de forma plausible
INSERT INTO actuacions (codi, centre_id, subtipus_id, estat_id, tecnic_id, prioritat_id,
                         pressupost, assumit_servei, descripcio, data_entrada, data_resolucio)
SELECT
    'ACT-' || LPAD(s::text, 4, '0'),
    (SELECT id FROM centres ORDER BY random() LIMIT 1),
    (SELECT id FROM subtipus_actuacio ORDER BY random() LIMIT 1),
    e.id,
    CASE WHEN random() < 0.15 THEN NULL ELSE (SELECT id FROM tecnic ORDER BY random() LIMIT 1) END,
    CASE WHEN random() < 0.7 THEN (SELECT id FROM prioritat_actuacio WHERE nom = 'Baixa')
         WHEN random() < 0.9 THEN (SELECT id FROM prioritat_actuacio WHERE nom = 'Mitjana')
         ELSE (SELECT id FROM prioritat_actuacio WHERE nom = 'Alta') END,  -- sesgado: 70% Baixa, 20% Mitjana, 10% Alta
    CASE WHEN random() < 0.3 THEN 0::numeric ELSE round((random()*40000)::numeric, 2) END,
    random() < 0.28,
    'Actuación sintética de práctica #' || s,
    d.data_entrada,
    CASE WHEN e.superestat_id = 3 THEN d.data_entrada + (floor(random()*45)+1)::int ELSE NULL END
FROM generate_series(1,500) AS s
CROSS JOIN LATERAL (
    SELECT (DATE '2025-01-01' + (floor(random()*540))::int) AS data_entrada
) d
CROSS JOIN LATERAL (
    SELECT id, superestat_id FROM estat_actuacio ORDER BY random() LIMIT 1
) e;

-- seguimiento: 1 a 3 registros por actuación resuelta
INSERT INTO seguiment_actuacio (actuacio_id, data_seguiment, comentari)
SELECT a.id, a.data_entrada + (n * 3), 'Seguimiento automático de práctica ' || n
FROM actuacions a
CROSS JOIN generate_series(1, 1 + floor(random()*3)::int) AS n
WHERE a.data_resolucio IS NOT NULL;

INSERT INTO conveni (codi, municipi_id, import_total, data_signatura)
SELECT 'CNV-' || LPAD(s::text,3,'0'), (SELECT id FROM municipi ORDER BY random() LIMIT 1),
       round((random()*300000 + 20000)::numeric,2), DATE '2025-01-01' + floor(random()*400)::int
FROM generate_series(1,15) s;

INSERT INTO centre_conveni (conveni_id, centre_id)
SELECT c.id, (SELECT id FROM centres ORDER BY random() LIMIT 1)
FROM conveni c;

INSERT INTO pagament_conveni (conveni_id, import, data_pagament)
SELECT c.id, round((c.import_total / (1 + floor(random()*3))::numeric)::numeric, 2),
       c.data_signatura + floor(random()*200)::int
FROM conveni c;


-- ============================================================================
-- SECCIÓN 3 — EDA por bloques temáticos
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 3.1 Exploración inicial: volumen, nulos, valores distintos
-- ---------------------------------------------------------------------------

SELECT 'actuacions' AS tabla, COUNT(*) AS filas FROM actuacions
UNION ALL SELECT 'centres', COUNT(*) FROM centres
UNION ALL SELECT 'conveni', COUNT(*) FROM conveni;

-- % de actuaciones sin técnico asignado (nulos)
SELECT
    COUNT(*) FILTER (WHERE tecnic_id IS NULL)                       AS sin_tecnico,
    COUNT(*)                                                        AS total,
    round(100.0 * COUNT(*) FILTER (WHERE tecnic_id IS NULL) / COUNT(*), 1) AS pct_sin_tecnico
FROM actuacions;

-- valores distintos de prioridad presentes
SELECT DISTINCT p.nom FROM actuacions a JOIN prioritat_actuacio p ON p.id = a.prioritat_id;


-- ---------------------------------------------------------------------------
-- 3.2 Filtros y ordenamiento
-- ---------------------------------------------------------------------------

-- actuaciones de alta prioridad, sin resolver, más antiguas primero
SELECT a.codi, a.data_entrada, a.pressupost
FROM actuacions a
JOIN prioritat_actuacio p ON p.id = a.prioritat_id
WHERE p.nom = 'Alta' AND a.data_resolucio IS NULL
ORDER BY a.data_entrada ASC
LIMIT 10;

-- actuaciones con presupuesto en un rango, entradas en el último trimestre de datos
SELECT codi, pressupost, data_entrada
FROM actuacions
WHERE pressupost BETWEEN 5000 AND 20000
  AND data_entrada >= (SELECT MAX(data_entrada) - INTERVAL '90 days' FROM actuacions)
ORDER BY pressupost DESC;


-- ---------------------------------------------------------------------------
-- 3.3 Agregaciones (GROUP BY / HAVING)
-- ---------------------------------------------------------------------------

-- actuaciones y presupuesto total por isla
SELECT i.nom AS illa, COUNT(*) AS actuaciones, SUM(a.pressupost) AS pressupost_total
FROM actuacions a
JOIN centres c ON c.id = a.centre_id
JOIN illa i     ON i.id = c.illa_id
GROUP BY i.nom
ORDER BY actuaciones DESC;

-- técnicos con más de 100 actuaciones asignadas
SELECT t.nom, COUNT(*) AS n
FROM actuacions a
JOIN tecnic t ON t.id = a.tecnic_id
GROUP BY t.nom
HAVING COUNT(*) > 100
ORDER BY n DESC;


-- ---------------------------------------------------------------------------
-- 3.4 JOINs — encadenados a través de todo el modelo
-- ---------------------------------------------------------------------------

-- vista completa de una actuación: isla, municipio, centro, tipo, estado, técnico
SELECT
    a.codi,
    i.nom            AS illa,
    m.nom            AS municipi,
    c.nom            AS centre,
    ta.nom           AS tipus,
    se.nom           AS superestat,
    e.nom            AS estat,
    COALESCE(t.nom,'Sense assignar') AS tecnic,
    a.pressupost
FROM actuacions a
JOIN centres c              ON c.id = a.centre_id
JOIN municipi m              ON m.id = c.municipi_id
JOIN illa i                  ON i.id = m.illa_id
JOIN subtipus_actuacio sa    ON sa.id = a.subtipus_id
JOIN tipus_actuacio ta       ON ta.id = sa.tipus_actuacio_id
JOIN estat_actuacio e        ON e.id = a.estat_id
JOIN superestat_actuacio se  ON se.id = e.superestat_id
LEFT JOIN tecnic t           ON t.id = a.tecnic_id
ORDER BY a.data_entrada DESC
LIMIT 20;

-- LEFT JOIN para detectar centros SIN ninguna actuación registrada
SELECT c.nom AS centre, m.nom AS municipi
FROM centres c
JOIN municipi m ON m.id = c.municipi_id
LEFT JOIN actuacions a ON a.centre_id = c.id
WHERE a.id IS NULL;

-- convenios: municipio, importe firmado vs. importe efectivamente pagado
SELECT
    m.nom AS municipi,
    cv.codi,
    cv.import_total,
    COALESCE(SUM(p.import), 0) AS pagado,
    cv.import_total - COALESCE(SUM(p.import), 0) AS pendiente
FROM conveni cv
JOIN municipi m       ON m.id = cv.municipi_id
LEFT JOIN pagament_conveni p ON p.conveni_id = cv.id
GROUP BY m.nom, cv.codi, cv.import_total
ORDER BY pendiente DESC;


-- ---------------------------------------------------------------------------
-- 3.5 Subconsultas y CTEs
-- ---------------------------------------------------------------------------

-- técnicos con carga por encima del promedio general (subquery escalar)
WITH carga_por_tecnico AS (
    SELECT t.id, t.nom, COUNT(a.id) AS n_actuaciones
    FROM tecnic t
    LEFT JOIN actuacions a ON a.tecnic_id = t.id
    GROUP BY t.id, t.nom
)
SELECT nom, n_actuaciones
FROM carga_por_tecnico
WHERE n_actuaciones > (SELECT AVG(n_actuaciones) FROM carga_por_tecnico)
ORDER BY n_actuaciones DESC;

-- CTE de dos pasos: primero calcular tiempos de resolución, luego agregarlos por tipo
WITH resoluciones AS (
    SELECT
        a.id,
        ta.nom AS tipus,
        a.data_resolucio - a.data_entrada AS dias_resolucion
    FROM actuacions a
    JOIN subtipus_actuacio sa ON sa.id = a.subtipus_id
    JOIN tipus_actuacio ta    ON ta.id = sa.tipus_actuacio_id
    WHERE a.data_resolucio IS NOT NULL
)
SELECT tipus, COUNT(*) AS n_resueltas, round(AVG(dias_resolucion),1) AS dias_promedio
FROM resoluciones
GROUP BY tipus
ORDER BY dias_promedio DESC;


-- ---------------------------------------------------------------------------
-- 3.6 Funciones de ventana
-- ---------------------------------------------------------------------------

-- ranking de técnicos por carga, con RANK() y participación % del total
SELECT
    t.nom,
    COUNT(a.id) AS n_actuaciones,
    RANK() OVER (ORDER BY COUNT(a.id) DESC) AS ranking,
    round(100.0 * COUNT(a.id) / SUM(COUNT(a.id)) OVER (), 1) AS pct_del_total
FROM tecnic t
LEFT JOIN actuacions a ON a.tecnic_id = t.id
GROUP BY t.nom;

-- acumulado de actuaciones entradas por mes (running total) con LAG para variación mensual
WITH por_mes AS (
    SELECT date_trunc('month', data_entrada)::date AS mes, COUNT(*) AS n
    FROM actuacions
    GROUP BY 1
)
SELECT
    mes,
    n,
    SUM(n) OVER (ORDER BY mes)                       AS acumulado,
    n - LAG(n) OVER (ORDER BY mes)                   AS variacion_vs_mes_anterior
FROM por_mes
ORDER BY mes;


-- ---------------------------------------------------------------------------
-- 3.7 Fechas y tiempos de resolución
-- ---------------------------------------------------------------------------

-- distribución de tiempos de resolución en "cubos" (bucketing con CASE)
SELECT
    CASE
        WHEN dias <= 7  THEN '0-7 días'
        WHEN dias <= 15 THEN '8-15 días'
        WHEN dias <= 30 THEN '16-30 días'
        ELSE '31+ días'
    END AS rango,
    COUNT(*) AS n
FROM (SELECT (data_resolucio - data_entrada) AS dias FROM actuacions WHERE data_resolucio IS NOT NULL) t
GROUP BY 1
ORDER BY MIN(dias);


-- ---------------------------------------------------------------------------
-- 3.8 CASE WHEN / lógica condicional
-- ---------------------------------------------------------------------------

SELECT
    codi,
    pressupost,
    CASE
        WHEN pressupost = 0        THEN 'Sin coste estimado'
        WHEN pressupost < 5000     THEN 'Menor'
        WHEN pressupost < 20000    THEN 'Medio'
        ELSE 'Mayor'
    END AS categoria_presupuesto
FROM actuacions
ORDER BY pressupost DESC
LIMIT 15;


-- ---------------------------------------------------------------------------
-- 3.9 Vistas
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_actuacions_resumen AS
SELECT
    a.id, a.codi, i.nom AS illa, ta.nom AS tipus, se.nom AS superestat,
    a.pressupost, a.data_entrada, a.data_resolucio
FROM actuacions a
JOIN centres c            ON c.id = a.centre_id
JOIN illa i                ON i.id = c.illa_id
JOIN subtipus_actuacio sa  ON sa.id = a.subtipus_id
JOIN tipus_actuacio ta     ON ta.id = sa.tipus_actuacio_id
JOIN estat_actuacio e      ON e.id = a.estat_id
JOIN superestat_actuacio se ON se.id = e.superestat_id;

-- uso de la vista: ya no hace falta repetir los 5 joins
SELECT illa, COUNT(*) FROM v_actuacions_resumen GROUP BY illa;


-- ---------------------------------------------------------------------------
-- 3.10 DML de mantenimiento (UPDATE / DELETE seguros)
-- ---------------------------------------------------------------------------

-- ejemplo: reasignar actuaciones sin técnico al de menor carga actual
-- (patrón: subquery correlacionada dentro de UPDATE)
UPDATE actuacions
SET tecnic_id = (SELECT id FROM tecnic ORDER BY random() LIMIT 1)
WHERE tecnic_id IS NULL
  AND id IN (SELECT id FROM actuacions WHERE tecnic_id IS NULL LIMIT 5);  -- limitado a modo de ejemplo

-- ejemplo de borrado seguro: eliminar seguimientos huérfanos (si los hubiera)
DELETE FROM seguiment_actuacio s
WHERE NOT EXISTS (SELECT 1 FROM actuacions a WHERE a.id = s.actuacio_id);


-- ---------------------------------------------------------------------------
-- 3.11 Índices — ver el efecto en el plan de ejecución
-- ---------------------------------------------------------------------------

-- comparar el plan antes/después de tener el índice en estat_id
EXPLAIN ANALYZE
SELECT * FROM actuacions WHERE estat_id = 3;

-- (el índice idx_actuacions_estat ya existe desde la sección 1; para ver el
--  contraste, se puede DROP INDEX temporalmente y volver a correr el EXPLAIN)


-- ---------------------------------------------------------------------------
-- 3.12 Función PL/pgSQL — generador de código secuencial por año
-- (réplica del patrón real del sistema: cada actuación tiene un código
--  correlativo que reinicia cada año, ej. "1-2025", "2-2025"...)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS actuacions_seq (
    any_val   INT PRIMARY KEY,
    ultim_num INT NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION seguent_codi_actuacio(p_any INT)
RETURNS TEXT AS $$
DECLARE
    v_num INT;
BEGIN
    INSERT INTO actuacions_seq (any_val, ultim_num)
    VALUES (p_any, 1)
    ON CONFLICT (any_val) DO UPDATE SET ultim_num = actuacions_seq.ultim_num + 1
    RETURNING ultim_num INTO v_num;

    RETURN v_num || '-' || p_any;
END;
$$ LANGUAGE plpgsql;

-- uso:
SELECT seguent_codi_actuacio(2026);  -- → '1-2026'
SELECT seguent_codi_actuacio(2026);  -- → '2-2026'


-- ============================================================================
-- SECCIÓN 4 — Limpieza (opcional)
-- ============================================================================
-- DROP SCHEMA sie CASCADE;


-- ============================================================================
-- SECCIÓN 5 — Notas de adaptación a SQL Server
-- ============================================================================
-- · SERIAL PRIMARY KEY           →  INT IDENTITY(1,1) PRIMARY KEY
-- · BOOLEAN                      →  BIT (0/1) en vez de TRUE/FALSE
-- · now()                        →  GETDATE()
-- · date + integer (sumar días)  →  DATEADD(day, n, fecha)
-- · fecha1 - fecha2 (restar días) →  DATEDIFF(day, fecha2, fecha1)
-- · LIMIT n                      →  TOP (n) al inicio del SELECT (no al final)
-- · generate_series(a,b)         →  no existe nativo; usar una CTE recursiva
--                                    o una tabla numérica auxiliar
-- · COUNT(*) FILTER (WHERE ..)   →  SUM(CASE WHEN .. THEN 1 ELSE 0 END)
-- · ON CONFLICT .. DO UPDATE      →  MERGE (sintaxis distinta, más verbosa)
-- · CREATE OR REPLACE FUNCTION   →  CREATE OR ALTER PROCEDURE / FUNCTION
--                                    (T-SQL, sintaxis de cuerpo distinta)
-- · EXPLAIN ANALYZE              →  activar "Include Actual Execution Plan"
--                                    en SSMS, o SET STATISTICS IO/TIME ON
-- ============================================================================
