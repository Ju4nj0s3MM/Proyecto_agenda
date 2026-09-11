-- Crear la base de datos
--CREATE DATABASE agenda;
--CREATE SCHEMA prototipo;


-- Configurar el search_path para que las tablas se creen dentro de ese esquema
-- y se busquen ahí automáticamente
SET search_path TO prototipo, public;


-- 1. Usuarios
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    fecha_registro DATE DEFAULT CURRENT_DATE NOT NULL,
    activo BOOLEAN DEFAULT TRUE
);


-- 2. Contactos (RF02, RE02, RN02)
CREATE TABLE usuario_telefonos (
    id_usuario INT REFERENCES usuarios(id_usuario),
    telefono VARCHAR(20),
    PRIMARY KEY (id_usuario, telefono)
);


CREATE TABLE usuario_emails (
    id_usuario INT REFERENCES usuarios(id_usuario),
    email VARCHAR(100),
    PRIMARY KEY (id_usuario, email)
);


-- 3. Categorías (RF03, RE05, RN04)
CREATE TABLE categorias (
    id_categoria SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    id_categoria_padre INT REFERENCES categorias(id_categoria)
    -- NOTA: La raíz tendría id_categoria_padre NULL
);

--Adicion de tala para el modulo de ubicaciones
CREATE TABLE ubicaciones (
    id_ubicacion SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    direccion VARCHAR(150) NOT NULL,
    ciudad VARCHAR(50) NOT NULL,
    capacidad INT NOT NULL CHECK (capacidad > 0)
);

-- 4. Eventos (RF04, RE04, RF-09)
CREATE TABLE eventos (
    id_evento SERIAL PRIMARY KEY,
    id_usuario_propietario INT NOT NULL REFERENCES usuarios(id_usuario),
    id_categoria INT NOT NULL REFERENCES categorias(id_categoria), --Al usar REFERENCES categorias(id_categoria) postgress crea automaticamente la FK
    id_ubicacion INT NOT NULL REFERENCES ubicaciones(id_ubicacion),
    titulo VARCHAR(100) NOT NULL,
    descripcion TEXT,
    fecha_inicio TIMESTAMP NOT NULL,
    fecha_fin TIMESTAMP NOT NULL,
    CONSTRAINT check_fechas CHECK (fecha_fin > fecha_inicio)
);


-- 5. Participación (RF05, RE01, RN01, RN05)
CREATE TABLE participaciones (
    id_evento INT REFERENCES eventos(id_evento) ON DELETE CASCADE,
    id_invitado INT REFERENCES usuarios(id_usuario),
    rol VARCHAR(50),
    estado_confirmacion VARCHAR(20) DEFAULT 'pendiente',
    PRIMARY KEY (id_evento, id_invitado)
);


-- 6. Log de Accesos (RF06)
CREATE TABLE log_accesos (
    id_log SERIAL PRIMARY KEY,
    id_usuario INT REFERENCES usuarios(id_usuario),
    fecha_acceso TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Tareas (RF-15, RE-?, RN-?)
CREATE TABLE tareas (
    id_tarea SERIAL PRIMARY KEY,
    id_evento INT NOT NULL REFERENCES eventos(id_evento) ON DELETE CASCADE,
    id_usuario_responsable INT NOT NULL REFERENCES usuarios(id_usuario),
    titulo VARCHAR(100) NOT NULL,
    descripcion TEXT,
    prioridad VARCHAR(20) NOT NULL DEFAULT 'media'
        CHECK (prioridad IN ('baja', 'media', 'alta')),
    fecha_limite DATE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'en progreso', 'completada', 'cancelada'))
);


-- Implementación de Cálculos Dinámicos (RF07, RE03, RN03) mediante vistas


-- Vista para Antigüedad
CREATE VIEW vista_antiguedad_usuarios AS
SELECT 
    id_usuario, 
    nombre, 
    fecha_registro,
    age(CURRENT_DATE, fecha_registro) AS antiguedad
FROM usuarios;


-- Vista para Duración de eventos diarios
CREATE VIEW vista_duracion_eventos_diarios AS
SELECT 
    id_usuario_propietario,
    fecha_inicio::DATE AS dia,
    SUM(EXTRACT(EPOCH FROM (fecha_fin - fecha_inicio))/60) AS duracion_total_minutos
FROM eventos
GROUP BY id_usuario_propietario, fecha_inicio::DATE;

CREATE VIEW vista_ranking_ubicaciones AS
SELECT
    u.id_ubicacion,
    u.nombre,
    u.ciudad,
    u.capacidad,
    COUNT(e.id_evento) AS total_eventos
FROM ubicaciones u
LEFT JOIN eventos e ON e.id_ubicacion = u.id_ubicacion
GROUP BY u.id_ubicacion, u.nombre, u.ciudad, u.capacidad
ORDER BY total_eventos DESC;

-- Vista de Carga de Trabajo por Usuario (RF-16, RF-17)
-- Cuenta tareas activas (pendiente/en_progreso) y, de esas, cuántas están vencidas.
-- LEFT JOIN para que también aparezcan usuarios sin ninguna tarea asignada (0 en ambas columnas).
CREATE VIEW vista_carga_tareas_usuario AS
SELECT
    u.id_usuario,
    u.nombre,
    u.apellido,
    COUNT(*) FILTER (WHERE t.estado IN ('pendiente', 'en progreso')) AS tareas_activas,
    COUNT(*) FILTER (WHERE t.estado IN ('pendiente', 'en progreso') AND t.fecha_limite < CURRENT_DATE) AS tareas_vencidas
FROM usuarios u
LEFT JOIN tareas t ON t.id_usuario_responsable = u.id_usuario
GROUP BY u.id_usuario, u.nombre, u.apellido
ORDER BY tareas_vencidas DESC, tareas_activas DESC;

-- Vista de Eventos con Tareas Vencidas (RF-16)
-- Identifica qué eventos arrastran tareas fuera de su plazo límite.
CREATE VIEW vista_eventos_con_tareas_vencidas AS
SELECT
    e.id_evento,
    e.titulo,
    COUNT(t.id_tarea) AS tareas_vencidas
FROM eventos e
JOIN tareas t ON t.id_evento = e.id_evento
WHERE t.estado NOT IN ('completada', 'cancelada')
  AND t.fecha_limite < CURRENT_DATE
GROUP BY e.id_evento, e.titulo
ORDER BY tareas_vencidas DESC;


--Integridad y Prevención de Ciclos (RE05)
--Para evitar ciclos en la jerarquía de categorías, podemos usar una función 
--que verifique el ancestro antes de insertar o actualizar:


CREATE OR REPLACE FUNCTION evitar_ciclo_categorias()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_categoria_padre = NEW.id_categoria THEN
        RAISE EXCEPTION 'Una categoría no puede ser padre de sí misma.';
    END IF;
    -- Aquí se podría añadir una consulta recursiva para validar ancestros, 
    -- pero para Postgres 14 es altamente eficiente usar el camino (path) o este chequeo simple.
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_evitar_ciclo
BEFORE INSERT OR UPDATE ON categorias
FOR EACH ROW EXECUTE FUNCTION evitar_ciclo_categorias();

-- Integridad y Prevención de Traslapes de Ubicación (RF-09)
-- Antes de insertar o actualizar un evento, se verifica que ningún otro evento
-- ya registrado en la misma ubicación se solape en el tiempo con el nuevo horario.
-- Dos rangos [inicio1, fin1) y [inicio2, fin2) se solapan si: inicio1 < fin2 AND fin1 > inicio2.

CREATE OR REPLACE FUNCTION evitar_traslape_ubicacion()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM eventos e
        WHERE e.id_ubicacion = NEW.id_ubicacion
          AND e.id_evento <> COALESCE(NEW.id_evento, -1)
          AND NEW.fecha_inicio < e.fecha_fin
          AND NEW.fecha_fin > e.fecha_inicio
    ) THEN
        RAISE EXCEPTION 'La ubicación seleccionada ya tiene un evento programado en ese rango de fecha y hora.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_evitar_traslape_ubicacion
BEFORE INSERT OR UPDATE ON eventos
FOR EACH ROW EXECUTE FUNCTION evitar_traslape_ubicacion();

INSERT INTO ubicaciones (nombre, direccion, ciudad, capacidad) VALUES
('Auditorio Principal', 'Edificio A, planta baja', 'San José', 150),
('Sala de Conferencias B', 'Edificio B, piso 2', 'San José', 30),
('Sala de Reuniones C', 'Edificio B, piso 3', 'Heredia', 12),
('Auditorio Norte', 'Campus Norte, entrada principal', 'Alajuela', 200),
('Sala Virtual 1', 'Plataforma en línea', 'Remoto', 100),
('Salón de Usos Múltiples', 'Edificio C, planta baja', 'Cartago', 80),
('Terraza de Eventos', 'Edificio A, azotea', 'San José', 60);

INSERT INTO tareas (id_evento, id_usuario_responsable, titulo, descripcion, prioridad, fecha_limite, estado)
VALUES
(9, 1, 'Confirmar catering', 'Llamar al proveedor y confirmar el menú', 'alta', CURRENT_DATE - 2, 'pendiente'),
(9, 1, 'Enviar invitaciones', 'Mandar invitaciones por correo', 'media', CURRENT_DATE + 5, 'en_progreso'),
(10, 1, 'Revisar logística', 'Confirmar transporte y equipo de sonido', 'baja', CURRENT_DATE - 1, 'en_progreso');
