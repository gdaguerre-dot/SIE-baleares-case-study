-- ============================================================================
-- SIE Balears — EDA sobre la base de datos REAL (esquema "sie_real")
--
-- REGLA DE DISEÑO DE ESTE SCRIPT: ninguna consulta selecciona columnas con
-- datos personales o texto libre potencialmente identificable. Se evita
-- explícitamente:
--   centres.email, centres.Telefon, centres.Fax   (contacto de personas)
--   actuacions.descripcio, actuacions.observacions (texto libre con nombres)
--   seguiment_actuacio.accio, informe_actuacio.observacions (idem)
--   tecnic.nom                                     (nombres reales del equipo)
--   document*.nom / url                            (nombres de archivo, URLs internas)
--
-- Todo lo demás (conteos, fechas, importes, estados, geografía) es seguro
-- de mostrar y de subir a un repositorio público — no identifica personas.
--
-- Este script SÍ puede ir al repositorio de Git. Los RESULTADOS de correrlo
-- (capturas, exports a CSV) NO deben subirse a ningún lado público.
-- ============================================================================

SET search_path TO sie_real;

-- ============================================================================
-- 1. Panorama general
-- ============================================================================

SELECT 'illa' AS tabla, COUNT(*) FROM illa
UNION ALL SELECT 'municipi', COUNT(*) FROM municipi
UNION ALL SELECT 'centres', COUNT(*) FROM centres
UNION ALL SELECT 'actuacions', COUNT(*) FROM actuacions
UNION ALL SELECT 'seguiment_actuacio', COUNT(*) FROM seguiment_actuacio
UNION ALL SELECT 'document_actuacio', COUNT(*) FROM document_actuacio
UNION ALL SELECT 'conveni', COUNT(*) FROM conveni;

-- rango de fechas real cubierto por los datos
SELECT MIN(data_entrada) AS primera_actuacio, MAX(data_entrada) AS ultima_actuacio
FROM actuacions;


-- ============================================================================
-- 2. Calidad de datos (el mismo tipo de hallazgo que motivó el case study)
-- ============================================================================

-- fechas "cero" (defecto típico de MySQL cuando no hay fecha real)
SELECT COUNT(*) AS fechas_invalidas_data_enviament
FROM actuacions
WHERE data_enviament IS NULL;  -- ya convertidas a NULL durante la migración

-- % de actuaciones sin técnico asignado
SELECT
    COUNT(*) FILTER (WHERE tecnic_id IS NULL) AS sin_tecnico,
    COUNT(*)                                   AS total,
    round(100.0 * COUNT(*) FILTER (WHERE tecnic_id IS NULL) / COUNT(*), 1) AS pct_sin_tecnico
FROM actuacions;

-- centros sin ninguna actuación registrada (LEFT JOIN + IS NULL)
SELECT COUNT(*) AS centros_sin_actuaciones
FROM centres c
LEFT JOIN actuacions a ON a.centre_id = c.id
WHERE a.id IS NULL;

-- catálogos vacíos (tablas de referencia sin ninguna fila cargada)
SELECT 'tipus_centre_educatiu' AS catalogo, COUNT(*) FROM tipus_centre_educatiu
UNION ALL SELECT 'comissio_seguiment', COUNT(*) FROM comissio_seguiment
UNION ALL SELECT 'mode_enviament', COUNT(*) FROM mode_enviament;


-- ============================================================================
-- 3. Distribución geográfica (JOIN illa -> municipi -> centres -> actuacions)
-- ============================================================================

SELECT
    i.nom AS illa,
    COUNT(DISTINCT c.id)  AS centros,
    COUNT(a.id)           AS actuaciones,
    round(AVG(a.pressupost), 2) AS presupuesto_promedio
FROM illa i
JOIN municipi m ON m.illa_id = i.id
JOIN centres c  ON c.id_municipi = m.id
LEFT JOIN actuacions a ON a.centre_id = c.id
GROUP BY i.nom
ORDER BY actuaciones DESC;

-- top 10 municipios por volumen de actuaciones
SELECT m.nom AS municipi, i.nom AS illa, COUNT(a.id) AS actuaciones
FROM municipi m
JOIN illa i ON i.id = m.illa_id
JOIN centres c ON c.id_municipi = m.id
JOIN actuacions a ON a.centre_id = c.id
GROUP BY m.nom, i.nom
ORDER BY actuaciones DESC
LIMIT 10;


-- ============================================================================
-- 4. Flujo de estados (superestat -> estat)
-- ============================================================================

SELECT
    se.nom AS superestat,
    e.nom  AS estat,
    COUNT(a.id) AS n
FROM estat_actuacio e
JOIN superestat_actuacio se ON se.id = e.superestat_id
LEFT JOIN actuacions a ON a.estat_id = e.id
GROUP BY se.nom, e.nom, se.ordre, e.ordre
ORDER BY se.ordre, e.ordre;

-- tiempo de resolución (solo donde hay fecha de envío, sin exponer texto libre)
SELECT
    ta.nom AS tipus,
    COUNT(*) AS n_actuaciones,
    round(AVG(a.data_enviament - a.data_entrada), 1) AS dias_promedio_hasta_envio
FROM actuacions a
JOIN subtipus_actuacio sa ON sa.id = a.subtipus_id
JOIN tipus_actuacio ta    ON ta.id = sa.tipus_id
WHERE a.data_enviament IS NOT NULL
GROUP BY ta.nom
ORDER BY dias_promedio_hasta_envio DESC;


-- ============================================================================
-- 5. Prioridad y presupuesto
-- ============================================================================

SELECT
    p.nom AS prioridad,
    COUNT(*) AS n,
    SUM(a.pressupost) AS presupuesto_total,
    SUM(CASE WHEN a.assumit_servei = 'S' THEN 1 ELSE 0 END) AS asumidas_por_servicio
FROM actuacions a
JOIN prioritat_actuacio p ON p.id = a.prioritat_id
GROUP BY p.nom
ORDER BY presupuesto_total DESC;

-- distribución de presupuesto en bloques (para ver si predominan los "0" sin estimar)
SELECT
    CASE
        WHEN pressupost = 0     THEN 'Sin estimar (0)'
        WHEN pressupost < 5000  THEN '< 5.000€'
        WHEN pressupost < 20000 THEN '5.000-20.000€'
        ELSE '> 20.000€'
    END AS rango_presupuesto,
    COUNT(*) AS n
FROM actuacions
GROUP BY 1
ORDER BY MIN(pressupost);


-- ============================================================================
-- 6. Convenios con ayuntamientos
-- ============================================================================

SELECT
    m.nom AS municipi,
    cv.codi,
    cv.pressupost AS importe_conveni,
    COALESCE(SUM(pc.import), 0) AS pagado,
    cv.pressupost - COALESCE(SUM(pc.import), 0) AS pendiente
FROM conveni cv
JOIN municipi m ON m.id = cv.ajuntament_id
LEFT JOIN pagament_conveni pc ON pc.conveni_id = cv.id
GROUP BY m.nom, cv.codi, cv.pressupost
ORDER BY pendiente DESC;


-- ============================================================================
-- 7. Documentación y trazabilidad (solo conteos, sin exponer nombres de archivo)
-- ============================================================================

SELECT
    ta.nom AS tipus,
    COUNT(DISTINCT a.id)  AS actuaciones,
    COUNT(d.id)           AS documentos_adjuntos,
    round(COUNT(d.id)::numeric / NULLIF(COUNT(DISTINCT a.id), 0), 2) AS docs_por_actuacion
FROM actuacions a
JOIN subtipus_actuacio sa ON sa.id = a.subtipus_id
JOIN tipus_actuacio ta    ON ta.id = sa.tipus_id
LEFT JOIN document_actuacio d ON d.actuacio_id = a.id
GROUP BY ta.nom
ORDER BY documentos_adjuntos DESC;


-- ============================================================================
-- 8. Carga de trabajo por técnico — SOLO EL ID, nunca tecnic.nom
--    (si necesitás mostrar esto en algún lado público, referite a "Técnico 1",
--     "Técnico 2"... nunca hagas JOIN con tecnic.nom fuera de un entorno local)
-- ============================================================================

SELECT
    tecnic_id,
    COUNT(*) AS n_actuaciones,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS ranking
FROM actuacions
WHERE tecnic_id IS NOT NULL
GROUP BY tecnic_id
ORDER BY n_actuaciones DESC;
