-- ============================================================================
-- ============================================================================
-- SIE Balears — Script de práctica SQL (VERSIÓN CORREGIDA)
-- Fix: los picks aleatorios de FK (centre_id, subtipus_id, estat_id, tecnic_id,
-- data_entrada, y el centre_id de centre_conveni) usaban una subconsulta NO
-- correlacionada del tipo (SELECT id FROM tabla ORDER BY random() LIMIT 1).
-- PostgreSQL, al no depender esa subconsulta de ninguna columna de la fila
-- externa, la trata como un InitPlan y la ejecuta UNA sola vez para toda la
-- sentencia INSERT ... SELECT — con lo que las 500 filas terminaban con el
-- MISMO centro/subtipo/estado/fecha. Fix: forzar correlación trivial con la
-- fila externa (WHERE s > 0 / WHERE c.id > 0) para impedir que el planner
-- la trate como constante.
-- ============================================================================
-- ============================================================================

DROP SCHEMA IF EXISTS sie CASCADE;
CREATE SCHEMA sie;
SET search_path TO sie;

CREATE TABLE illa (id SERIAL PRIMARY KEY, nom VARCHAR(30) NOT NULL UNIQUE);
CREATE TABLE municipi (id SERIAL PRIMARY KEY, illa_id INT NOT NULL REFERENCES illa(id), nom VARCHAR(60) NOT NULL);
CREATE TABLE centres (
    id SERIAL PRIMARY KEY, nom VARCHAR(120) NOT NULL,
    tipus VARCHAR(20) NOT NULL CHECK (tipus IN ('Public','Concertat','Privat')),
    illa_id INT NOT NULL REFERENCES illa(id), municipi_id INT NOT NULL REFERENCES municipi(id)
);
CREATE TABLE tipus_actuacio (id SERIAL PRIMARY KEY, nom VARCHAR(80) NOT NULL UNIQUE);
CREATE TABLE subtipus_actuacio (id SERIAL PRIMARY KEY, tipus_actuacio_id INT NOT NULL REFERENCES tipus_actuacio(id), nom VARCHAR(120) NOT NULL);
CREATE TABLE superestat_actuacio (id SERIAL PRIMARY KEY, nom VARCHAR(30) NOT NULL UNIQUE, ordre INT NOT NULL);
CREATE TABLE estat_actuacio (id SERIAL PRIMARY KEY, superestat_id INT NOT NULL REFERENCES superestat_actuacio(id), nom VARCHAR(60) NOT NULL, ordre INT NOT NULL);
CREATE TABLE prioritat_actuacio (id SERIAL PRIMARY KEY, nom VARCHAR(20) NOT NULL UNIQUE, pes INT NOT NULL);
CREATE TABLE tecnic (id SERIAL PRIMARY KEY, nom VARCHAR(60) NOT NULL);
CREATE TABLE actuacions (
    id SERIAL PRIMARY KEY, codi VARCHAR(20) NOT NULL UNIQUE,
    centre_id INT NOT NULL REFERENCES centres(id), subtipus_id INT NOT NULL REFERENCES subtipus_actuacio(id),
    estat_id INT NOT NULL REFERENCES estat_actuacio(id), tecnic_id INT REFERENCES tecnic(id),
    prioritat_id INT NOT NULL REFERENCES prioritat_actuacio(id),
    pressupost NUMERIC(10,2) NOT NULL DEFAULT 0, assumit_servei BOOLEAN NOT NULL DEFAULT FALSE,
    descripcio TEXT, data_entrada DATE NOT NULL, data_resolucio DATE,
    CHECK (data_resolucio IS NULL OR data_resolucio >= data_entrada)
);
CREATE TABLE seguiment_actuacio (id SERIAL PRIMARY KEY, actuacio_id INT NOT NULL REFERENCES actuacions(id), data_seguiment TIMESTAMP NOT NULL DEFAULT now(), comentari TEXT);
CREATE TABLE conveni (id SERIAL PRIMARY KEY, codi VARCHAR(20) NOT NULL UNIQUE, municipi_id INT NOT NULL REFERENCES municipi(id), import_total NUMERIC(12,2) NOT NULL, data_signatura DATE NOT NULL);
CREATE TABLE centre_conveni (id SERIAL PRIMARY KEY, conveni_id INT NOT NULL REFERENCES conveni(id), centre_id INT NOT NULL REFERENCES centres(id));
CREATE TABLE pagament_conveni (id SERIAL PRIMARY KEY, conveni_id INT NOT NULL REFERENCES conveni(id), import NUMERIC(12,2) NOT NULL, data_pagament DATE NOT NULL);

CREATE INDEX idx_actuacions_centre ON actuacions(centre_id);
CREATE INDEX idx_actuacions_estat ON actuacions(estat_id);
CREATE INDEX idx_actuacions_tecnic ON actuacions(tecnic_id);
CREATE INDEX idx_actuacions_data ON actuacions(data_entrada);
CREATE INDEX idx_centres_municipi ON centres(municipi_id);

INSERT INTO illa (nom) VALUES ('Mallorca'), ('Menorca'), ('Eivissa'), ('Formentera');

INSERT INTO municipi (illa_id, nom) VALUES
(1,'Palma'),(1,'Calvià'),(1,'Manacor'),(1,'Inca'),(1,'Marratxí'),(1,'Llucmajor'),
(2,'Maó'),(2,'Ciutadella'),(2,'Alaior'),
(3,'Eivissa'),(3,'Sant Antoni de Portmany'),(3,'Santa Eulària des Riu'),
(4,'Formentera');

INSERT INTO centres (nom, tipus, illa_id, municipi_id)
SELECT 'CEIP ' || nom_generat,
       (ARRAY['Public','Public','Public','Concertat','Privat'])[1 + floor(random()*5)],
       m.illa_id, m.id
FROM (SELECT id, illa_id, ROW_NUMBER() OVER (ORDER BY random()) AS rn FROM municipi) m
CROSS JOIN LATERAL (SELECT 'Centre ' || generate_series AS nom_generat FROM generate_series(1, 5)) g
LIMIT 60;

INSERT INTO tipus_actuacio (nom) VALUES
('Climatització'),('Reformes i millores generals'),('Habilitació d''espais'),
('Banys i sanejament'),('Menjadors i cuines'),('Jocs de pati'),
('Goteres i impermeabilitzacions'),('Electricitat'),('Consulta tècnica');

INSERT INTO subtipus_actuacio (tipus_actuacio_id, nom)
SELECT id, nom || ' - ' || sub FROM tipus_actuacio, (VALUES ('reparació'),('instal·lació nova'),('manteniment')) AS s(sub);

INSERT INTO superestat_actuacio (nom, ordre) VALUES ('Pendent',1), ('En procés',2), ('Resolta',3);

INSERT INTO estat_actuacio (superestat_id, nom, ordre) VALUES
(1,'Pendent',1),
(2,'Agafada',1),(2,'Pendent documentació',2),(2,'Redacció documentació tècnica',3),
(3,'Contestada',1),(3,'Desfavorable',2),(3,'Autorització recursos propis',3),
(3,'Contracte menor',4),(3,'Derivar IBISEC',5),(3,'Tancada',6);

INSERT INTO prioritat_actuacio (nom, pes) VALUES ('Baixa',1),('Mitjana',2),('Alta',3);
INSERT INTO tecnic (nom) VALUES ('Tècnic A'),('Tècnic B'),('Tècnic C'),('Tècnic D');

-- FIX aplicado: "WHERE s > 0" fuerza correlación trivial con la fila del
-- generate_series y evita que Postgres colapse el ORDER BY random() LIMIT 1
-- en un InitPlan evaluado una sola vez.
INSERT INTO actuacions (codi, centre_id, subtipus_id, estat_id, tecnic_id, prioritat_id,
                         pressupost, assumit_servei, descripcio, data_entrada, data_resolucio)
SELECT
    'ACT-' || LPAD(s::text, 4, '0'),
    (SELECT id FROM centres WHERE s > 0 ORDER BY random() LIMIT 1),
    (SELECT id FROM subtipus_actuacio WHERE s > 0 ORDER BY random() LIMIT 1),
    e.id,
    CASE WHEN random() < 0.15 THEN NULL ELSE (SELECT id FROM tecnic WHERE s > 0 ORDER BY random() LIMIT 1) END,
    CASE WHEN random() < 0.7 THEN (SELECT id FROM prioritat_actuacio WHERE nom = 'Baixa')
         WHEN random() < 0.9 THEN (SELECT id FROM prioritat_actuacio WHERE nom = 'Mitjana')
         ELSE (SELECT id FROM prioritat_actuacio WHERE nom = 'Alta') END,
    CASE WHEN random() < 0.3 THEN 0::numeric ELSE round((random()*40000)::numeric, 2) END,
    random() < 0.28,
    'Actuación sintética de práctica #' || s,
    d.data_entrada,
    CASE WHEN e.superestat_id = 3 THEN d.data_entrada + (floor(random()*45)+1)::int ELSE NULL END
FROM generate_series(1,500) AS s
CROSS JOIN LATERAL (SELECT (DATE '2025-01-01' + (floor(random()*540))::int) AS data_entrada WHERE s > 0) d
CROSS JOIN LATERAL (SELECT id, superestat_id FROM estat_actuacio WHERE s > 0 ORDER BY random() LIMIT 1) e;

INSERT INTO seguiment_actuacio (actuacio_id, data_seguiment, comentari)
SELECT a.id, a.data_entrada + (n * 3), 'Seguimiento automático de práctica ' || n
FROM actuacions a CROSS JOIN generate_series(1, 1 + floor(random()*3)::int) AS n
WHERE a.data_resolucio IS NOT NULL;

INSERT INTO conveni (codi, municipi_id, import_total, data_signatura)
SELECT 'CNV-' || LPAD(s::text,3,'0'), (SELECT id FROM municipi WHERE s > 0 ORDER BY random() LIMIT 1),
       round((random()*300000 + 20000)::numeric,2), DATE '2025-01-01' + floor(random()*400)::int
FROM generate_series(1,15) s;

INSERT INTO centre_conveni (conveni_id, centre_id)
SELECT c.id, (SELECT id FROM centres WHERE c.id > 0 ORDER BY random() LIMIT 1)
FROM conveni c;

INSERT INTO pagament_conveni (conveni_id, import, data_pagament)
SELECT c.id, round((c.import_total / (1 + floor(random()*3))::numeric)::numeric, 2),
       c.data_signatura + floor(random()*200)::int
FROM conveni c;
