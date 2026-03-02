-- SAO: PostgreSQL Schema (Offline-First + Audit + Sync Architecture)
-- Source of Truth: Backend + Database

-- ============================================================
-- 1. PROYECTOS Y ORGANIZACIÓN
-- ============================================================

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(10) NOT NULL UNIQUE,  -- TMQ, TAP, SNL, QIR
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'active',  -- active, archived
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fronts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,  -- Frente A, Frente B, etc.
    code VARCHAR(50),  -- Optional: A1, A2, etc.
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(project_id, name)
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',  -- active, inactive, archived
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL UNIQUE,  -- operativo, coordinador, admin
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,  -- activity:create, activity:approve, etc.
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE user_project_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    front_id UUID REFERENCES fronts(id) ON DELETE CASCADE,  -- NULL = all fronts
    access_level VARCHAR(20) DEFAULT 'read',  -- read, edit, approve
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, project_id, front_id)
);

-- ============================================================
-- 2. ACTIVIDADES Y VALIDACIÓN
-- ============================================================

CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID UNIQUE,  -- Para sincronización (copia local puede tener local UUID)
    project_id UUID NOT NULL REFERENCES projects(id),
    front_id UUID NOT NULL REFERENCES fronts(id),
    operativo_id UUID NOT NULL REFERENCES users(id),  -- Quién capturó
    coordinator_id UUID REFERENCES users(id),  -- Quién revisa
    
    -- Datos capturados
    activity_type VARCHAR(50) NOT NULL,  -- reunion_comunitaria, caminamiento_tecnico, etc.
    title VARCHAR(255) NOT NULL,
    narrative TEXT,
    
    -- Ubicación
    pk_declared VARCHAR(50),  -- Ejemplo: 142+500
    pk_meters NUMERIC(10, 2),  -- Kilómetro + metros en metros
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    gps_accuracy_meters NUMERIC(5, 2),
    gps_distance_to_pk NUMERIC(6, 2),  -- Distancia calculada
    
    -- Estado
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',  -- DRAFT, SUBMITTED, IN_REVIEW, CHANGES_REQUESTED, APPROVED, REJECTED
    
    -- Auditoría de estado
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    submitted_at TIMESTAMP,
    review_started_at TIMESTAMP,
    review_completed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Metadatos
    rejection_reason TEXT,  -- Si status = REJECTED
    is_synced BOOLEAN DEFAULT false,
    sync_timestamp TIMESTAMP,
    
    INDEX idx_project_front_status (project_id, front_id, status),
    INDEX idx_status_coordinator (status, coordinator_id),
    INDEX idx_created_at (created_at)
);

CREATE TABLE activity_fields (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    field_value TEXT,  -- Jsonb en Postgres real
    field_type VARCHAR(20),  -- text, select, number, date, etc.
    catalog_version_id UUID,  -- Si fue validado contra catálogo
    is_valid BOOLEAN DEFAULT true,
    validation_error TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(activity_id, field_name)
);

CREATE TABLE activity_field_changes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    actor_id UUID NOT NULL REFERENCES users(id),
    actor_role VARCHAR(30),
    change_source VARCHAR(20) DEFAULT 'mobile',  -- mobile, desktop, system
    change_type VARCHAR(20) DEFAULT 'update',  -- update, validate, correct
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_activity_field (activity_id, field_name),
    INDEX idx_timestamp (timestamp)
);

-- ============================================================
-- 3. EVIDENCIAS
-- ============================================================

CREATE TABLE evidences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    file_url VARCHAR(500) NOT NULL,
    file_type VARCHAR(20),  -- image, pdf, video, audio
    file_size_bytes BIGINT,
    file_hash VARCHAR(64),  -- SHA256 para integridad
    
    -- Metadatos de evidencia
    caption TEXT,  -- Pie de foto / descripción
    captured_at TIMESTAMP,  -- Cuándo se capturó (EXIF)
    latitude NUMERIC(10, 8),
    longitude NUMERIC(11, 8),
    exif_metadata JSONB,  -- Metadatos EXIF completos
    
    -- Auditoría de cambios en evidencia
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(id),  -- Quién editó caption/metadata
    
    INDEX idx_activity_id (activity_id),
    INDEX idx_file_hash (file_hash)
);

CREATE TABLE evidence_captions_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evidence_id UUID NOT NULL REFERENCES evidences(id) ON DELETE CASCADE,
    old_caption TEXT,
    new_caption TEXT,
    edited_by UUID NOT NULL REFERENCES users(id),
    edited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_evidence_id (evidence_id)
);

-- ============================================================
-- 4. CATÁLOGOS VERSIONADOS
-- ============================================================

CREATE TABLE catalog_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id),
    version VARCHAR(20) NOT NULL,  -- 1.0, 1.1, 2.0, etc.
    status VARCHAR(20) DEFAULT 'draft',  -- draft, published, deprecated
    
    -- Metadatos
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,
    published_by UUID REFERENCES users(id),
    deprecated_at TIMESTAMP,
    
    -- Contenido
    schema_json JSONB,  -- FormSchema completo
    items_json JSONB,  -- Catálogo de valores
    
    UNIQUE(project_id, version),
    INDEX idx_project_status (project_id, status),
    INDEX idx_published_at (published_at)
);

CREATE TABLE catalog_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id UUID NOT NULL REFERENCES catalog_versions(id) ON DELETE CASCADE,
    key VARCHAR(100) NOT NULL,
    value VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    description TEXT,
    order_index INT DEFAULT 0,
    UNIQUE(version_id, key),
    INDEX idx_version_key (version_id, key)
);

-- ============================================================
-- 5. FORMULARIOS (FORM SCHEMA)
-- ============================================================

CREATE TABLE form_schemas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id),
    catalog_version_id UUID REFERENCES catalog_versions(id),  -- Versión de catálogo asociada
    
    -- Definición del formulario
    schema_json JSONB NOT NULL,  -- { fields: [...], validations: [...], visibility_rules: [...] }
    
    status VARCHAR(20) DEFAULT 'draft',  -- draft, published
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(id),
    
    INDEX idx_project_version (project_id, catalog_version_id)
);

-- ============================================================
-- 6. NOTAS Y COMUNICACIÓN
-- ============================================================

CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id),
    
    content TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT false,  -- true = no sale en reporte oficial
    note_type VARCHAR(30) DEFAULT 'comment',  -- comment, correction_request, review_note
    
    -- Referencia a campo específico si aplica
    referenced_field VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_activity_internal (activity_id, is_internal),
    INDEX idx_created_at (created_at)
);

-- ============================================================
-- 7. AUDITORÍA Y TRAZABILIDAD
-- ============================================================

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Qué
    entity_type VARCHAR(50) NOT NULL,  -- activity, evidence, catalog, user, etc.
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,  -- create, update, approve, reject, validate, etc.
    
    -- Quién
    actor_id UUID NOT NULL REFERENCES users(id),
    actor_role VARCHAR(30),
    actor_name VARCHAR(255),
    
    -- Cambios
    changes JSONB,  -- { field: old_value → new_value }
    previous_state JSONB,  -- Estado anterior completo
    new_state JSONB,  -- Estado nuevo completo
    
    -- Metadatos
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sync_mode VARCHAR(20) DEFAULT 'server',  -- server, mobile, desktop
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    
    metadata JSONB,  -- Contexto adicional (proyecto, frente, etc.)
    
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_actor_timestamp (actor_id, timestamp),
    INDEX idx_action_timestamp (action, timestamp),
    INDEX idx_timestamp (timestamp)
);

CREATE TABLE activity_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    from_status VARCHAR(30),
    to_status VARCHAR(30) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by UUID NOT NULL REFERENCES users(id),
    reason TEXT,  -- Motivo del cambio
    INDEX idx_activity_timestamp (activity_id, changed_at),
    INDEX idx_to_status (to_status)
);

-- ============================================================
-- 8. REPORTES
-- ============================================================

CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES activities(id),
    
    -- Identificación oficial
    folio VARCHAR(50) UNIQUE NOT NULL,  -- SAO-TMQ-A-142+500-20260218-001
    
    -- Contenido
    status VARCHAR(20) DEFAULT 'draft',  -- draft, official, archived, rejected
    pdf_url VARCHAR(500),
    pdf_hash VARCHAR(64),  -- Para integridad
    
    -- Opciones de generación
    include_audit_trail BOOLEAN DEFAULT false,
    include_internal_notes BOOLEAN DEFAULT false,
    include_attachments BOOLEAN DEFAULT true,
    
    -- Auditoría de reporte
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    generated_by UUID NOT NULL REFERENCES users(id),
    generated_for_status VARCHAR(30),  -- Cuál era el status cuando se generó
    
    INDEX idx_activity_status (activity_id, status),
    INDEX idx_folio (folio),
    INDEX idx_generated_at (generated_at)
);

-- ============================================================
-- 9. SINCRONIZACIÓN
-- ============================================================

CREATE TABLE sync_tokens (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    last_sync_at TIMESTAMP,
    last_sync_server_timestamp TIMESTAMP,
    device_id VARCHAR(100),  -- Para sincronización multi-device
    sync_log JSONB,  -- Últimas 10 syncs: { ts, status, items_count }
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sync_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type VARCHAR(50),  -- activity, evidence, note, etc.
    entity_id UUID,
    action VARCHAR(50),  -- create, update, delete
    data JSONB NOT NULL,  -- Payload completo
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    synced_at TIMESTAMP,
    sync_error TEXT,
    retry_count INT DEFAULT 0,
    INDEX idx_user_synced (user_id, synced_at),
    INDEX idx_created_at (created_at)
);

-- ============================================================
-- ÍNDICES FINALES PARA PERFORMANCE
-- ============================================================

CREATE INDEX idx_activities_coordinator ON activities(coordinator_id, status);
CREATE INDEX idx_activities_operativo ON activities(operativo_id, status);
CREATE INDEX idx_activities_project_front ON activities(project_id, front_id);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id, timestamp);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id, timestamp);
CREATE INDEX idx_notes_activity_author ON notes(activity_id, author_id);
CREATE INDEX idx_catalog_version_published ON catalog_versions(project_id, status, published_at);

-- ============================================================
-- PERMISOS Y ROLES INICIALES
-- ============================================================

INSERT INTO roles (name, description) VALUES
    ('operativo', 'Equipo de campo: captura datos offline'),
    ('coordinador', 'Coordinador: revisa, valida, aprueba actividades'),
    ('administrador', 'Admin: gestiona sistema completo');

INSERT INTO permissions (name, description) VALUES
    -- Actividades
    ('activity:create', 'Crear actividades (operativo)'),
    ('activity:edit:own', 'Editar propias actividades'),
    ('activity:submit', 'Enviar actividades (SUBMITTED)'),
    ('activity:review:start', 'Iniciar revisión'),
    ('activity:review:complete', 'Completar revisión (approve/reject)'),
    ('activity:view:project', 'Ver actividades del proyecto'),
    
    -- Catálogos
    ('catalog:edit', 'Editar catálogos'),
    ('catalog:publish', 'Publicar versiones de catálogo'),
    
    -- Usuarios y permisos
    ('user:create', 'Crear usuarios'),
    ('user:manage', 'Gestionar usuarios y roles'),
    
    -- Auditoría
    ('audit:view', 'Ver logs de auditoría');

-- Asignar permisos a roles (ejemplo)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'operativo' AND p.name IN ('activity:create', 'activity:edit:own', 'activity:submit', 'activity:view:project');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'coordinador' AND p.name IN (
    'activity:review:start', 'activity:review:complete', 'activity:view:project',
    'catalog:edit', 'audit:view'
);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p
WHERE r.name = 'administrador';  -- Admin tiene todos los permisos

