# Modelo de permisos: perfil × fase

El control de acceso no depende solo del perfil del usuario, sino de la combinación **perfil × fase del proceso**. El mismo perfil puede tener permiso de edición en una fase y solo lectura en otra — lo que hace explícito, en la propia matriz, quién es responsable de qué en cada momento.

Perfiles involucrados:

- **Delegaciones territoriales (DT)** — origen de las propuestas, con visión de su ámbito territorial.
- **Servicios centrales (SSCC)** — supervisión y decisión final; permisos completos en todas las fases.
- **Equipo técnico de infraestructuras** — validación técnica y presupuestaria in situ.

| Fase | DT | SSCC | Equipo técnico |
|---|---|---|---|
| 1 — Propuesta | Crear, editar, ver, subir documentación | Todos los permisos | Solo lectura |
| 2 — En estudio | Ver, subir documentación | Todos los permisos | Solo lectura |
| 3 — En trámite | Ver, subir documentación | Todos los permisos | Editar presupuesto y descriptor, cambiar estado, subir documentación |
| 4 — Decisión final | Ver, subir documentación | Todos los permisos | Ver, subir documentación |
| 5 — Cierre | Ver | Todos los permisos | Ver |

## Por qué este diseño

Modelar el permiso como función de `perfil × fase` en lugar de crear un perfil distinto por cada combinación posible tiene dos ventajas prácticas:

1. **Menos perfiles que mantener** — el número de perfiles no crece con el número de fases del proceso.
2. **Auditoría más simple** — la propia matriz documenta quién podía hacer qué y cuándo, sin tener que reconstruirlo a partir de logs de permisos por usuario.

El coste es que la lógica de autorización debe consultar siempre dos dimensiones (perfil y fase actual de la actuación), no solo una — una decisión de diseño consciente, no un descuido.
