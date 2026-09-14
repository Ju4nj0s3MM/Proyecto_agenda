# Proyecto_agenda
Repositorio en el cual se va a evaluar el primer protyecto de BD durante el II Sem del 2026.

## Matriz de Trazabilidad y Estado de Implementación

### Módulo de Gestión de Ubicaciones

| Req. | Fase | Tarea | Estado |
|---|---|---|---|
| RF-08 | 1. Modelo Conceptual | Definir la entidad UBICACIONES y sus atributos obligatorios (id_ubicacion, nombre, dirección, ciudad, capacidad). | Completado |
| | 2. Modelo Lógico | Estructurar la tabla relacional especificando tipos de datos y clave primaria. | Completado |
| | 3. Modelo Físico | Codificar el `CREATE TABLE ubicaciones` en PostgreSQL con restricciones `NOT NULL` y `CHECK (capacidad > 0)`. | Completado |
| | 4. Interfaz Gráfica | Desarrollar la pestaña de Ubicaciones con tabla y formulario para registrar, consultar, actualizar y eliminar recintos. | Completado |
| RF-09 | 1. Modelo Conceptual | Establecer la relación "SE REALIZA EN" entre EVENTOS y UBICACIONES (cardinalidad N:1). | Completado |
| | 2. Modelo Lógico | Incorporar `id_ubicacion` como FK obligatoria en el esquema relacional de eventos. | Completado |
| | 3. Modelo Físico | Agregar `id_ubicacion` como columna `NOT NULL` con `REFERENCES` en `eventos`, y crear el trigger `trg_evitar_traslape_ubicacion` para prevenir eventos simultáneos en la misma ubicación. | Completado |
| | 4. Interfaz Gráfica | Integrar el selector de ubicación en el formulario de eventos, mostrar la columna Ubicación en la tabla, y capturar el error del trigger con un mensaje amigable. | Completado |
| RF-10 | 3. Modelo Físico | Diseñar la vista `vista_ranking_ubicaciones` con conteo de eventos por ubicación (`LEFT JOIN` para incluir también las subutilizadas). | Completado |
| | 4. Interfaz Gráfica | Implementar el panel de reporte de solo lectura en la pestaña de Ubicaciones mostrando el ranking de ocupación. | Completado |

### Módulo de Tareas Asociadas a Eventos

| Req. | Fase | Tarea | Estado |
|---|---|---|---|
| RF-15 | 1. Modelo Conceptual | Definir la entidad TAREAS vinculada a EVENTOS ("GENERA") y a USUARIOS ("RESPONSABLE"), con atributos título, descripción, prioridad, fecha límite y estado. | Completado |
| | 2. Modelo Lógico | Establecer las FK `id_evento` e `id_usuario_responsable` en el esquema relacional de tareas. | Completado |
| | 3. Modelo Físico | Crear la tabla `tareas` con `CHECK` para prioridad/estado y `ON DELETE CASCADE` hacia eventos. | Completado |
| | 4. Interfaz Gráfica | Desarrollar la pestaña de Tareas con CRUD completo (crear, leer, actualizar estado y eliminar). | Completado |
| RF-16 | 3. Modelo Físico | Desarrollar las vistas `vista_carga_tareas_usuario` y `vista_eventos_con_tareas_vencidas` para medir tareas pendientes por usuario y detectar eventos con tareas vencidas. | Completado |
| | 4. Interfaz Gráfica | Configurar el despliegue de ambos reportes en paneles dentro de la pestaña de Tareas. | Completado |
| RF-17 | 3. Modelo Físico | Incluir en `vista_carga_tareas_usuario` el conteo de tareas activas y vencidas, filtradas por estado y fecha límite. | Completado |
| | 4. Interfaz Gráfica | Integrar el panel "Carga de tareas por usuario" para la detección temprana de sobrecargas de trabajo. | Completado |

### Módulo de Disponibilidad de Usuarios y Gestión de Tiempos

| Req. | Fase | Tarea | Estado |
|---|---|---|---|
| RF-11 | 1. Modelo Conceptual | Definir la entidad DISPONIBILIDADES vinculada a USUARIOS ("TIENE") y el catálogo TIPOS_DISPONIBILIDAD ("ES_DE_TIPO"). | Completado |
| | 2. Modelo Lógico | Estructurar las tablas relacionales de disponibilidad y sus FK hacia usuarios y tipos_disponibilidad. | Completado |
| | 3. Modelo Físico | Crear las tablas `tipos_disponibilidad` (con datos semilla: disponible, ocupado, no disponible) y `disponibilidades` con `CHECK` de horas válidas. | Completado |
| | 4. Interfaz Gráfica | Desarrollar el panel de disponibilidad dentro de la pestaña Usuarios, con entrada manual solo para "no disponible" (ausencias personales) y visualización de las franjas del usuario seleccionado. | Completado |
| RF-12 | 3. Modelo Físico | Implementar 4 triggers para automatizar y validar la disponibilidad: bloqueo de vinculaciones/eventos en conflicto (`trg_evitar_conflicto_disponibilidad`, `trg_verificar_disponibilidad_propietario`) y generación/liberación automática de "ocupado" (`trg_marcar_ocupado_por_participacion`, `trg_sincronizar_disponibilidad_propietario`, y sus triggers de liberación al desvincular/eliminar). | Completado |
| | 4. Interfaz Gráfica | Integrar el panel "Vincular a un evento" para asociar usuarios a eventos, mostrando el bloqueo automático de conflictos y liberando la disponibilidad al desvincular. | Completado |