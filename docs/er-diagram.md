# Modelo entidad-relación

Extraído y simplificado a partir del esquema real de la base de datos (nombres de tabla y relaciones; sin datos).

```mermaid
erDiagram
  ILLA ||--o{ MUNICIPI : conte
  MUNICIPI ||--o{ CENTRES : ubica
  CENTRES ||--o{ ACTUACIONS : origina
  CENTRES ||--o{ CENTRE_CONVENI : participa
  CENTRES ||--o{ ASSIGNAR_ESPAIS : te

  TIPUS_ACTUACIO ||--o{ SUBTIPUS_ACTUACIO : classifica
  SUBTIPUS_ACTUACIO ||--o{ ACTUACIONS : tipifica
  SUPERESTAT_ACTUACIO ||--o{ ESTAT_ACTUACIO : agrupa
  ESTAT_ACTUACIO ||--o{ ACTUACIONS : defineix
  TECNIC ||--o{ ACTUACIONS : gestiona
  DESTI_ACTUACIO ||--o{ ACTUACIONS : desti
  ORIGEN_ACTUACIO ||--o{ ACTUACIONS : origen
  PRIORITAT_ACTUACIO ||--o{ ACTUACIONS : prioritza

  ACTUACIONS ||--o{ SEGUIMENT_ACTUACIO : audita
  ACTUACIONS ||--o{ DOCUMENT_ACTUACIO : adjunta
  ACTUACIONS ||--o{ INFORME_ACTUACIO : reporta

  MUNICIPI ||--o{ CONVENI : signa
  ESTAT_CONVENI ||--o{ CONVENI : defineix
  CONVENI ||--o{ CENTRE_CONVENI : inclou
  CONVENI ||--o{ PAGAMENT_CONVENI : financa
  CONVENI ||--o{ DOCUMENT_CONVENI : documenta
  CENTRE_CONVENI ||--o{ ACTUACIO_CONVENI : detalla
  TIPUS_DOCUMENT_ACTUACIO_CONVENI ||--o{ DOCUMENT_ACTUACIO_CONVENI : tipifica
  ACTUACIO_CONVENI ||--o{ DOCUMENT_ACTUACIO_CONVENI : adjunta
  ESPAI ||--o{ ASSIGNAR_ESPAIS : assigna
```

## Lectura del modelo

- **Núcleo (`ACTUACIONS`)**: cada solicitud de obra o incidencia. Referencia a centro, técnico asignado, estado, prioridad, tipo/subtipo, origen y destino.
- **Módulo geográfico** (`ILLA` → `MUNICIPI` → `CENTRES`): permite agregar cualquier métrica por territorio, clave en un archipiélago con capacidades de respuesta muy distintas entre islas.
- **Máquina de estados** (`SUPERESTAT_ACTUACIO` → `ESTAT_ACTUACIO`): jerarquía de dos niveles que permite tanto una vista simple ("pendiente / en proceso / resuelta") como el detalle operativo real.
- **Módulo de convenios**: financiación de obras mayores junto con ayuntamientos, en paralelo al flujo de actuaciones, con sus propios documentos y pagos.
- **Trazabilidad**: `SEGUIMENT_ACTUACIO`, `DOCUMENT_ACTUACIO` e `INFORME_ACTUACIO` permiten reconstruir el historial completo de cualquier expediente.
