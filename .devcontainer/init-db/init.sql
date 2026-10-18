-- =============================================================================
-- Kinara Registry - Initial Database Schema & Seed Data (PostgreSQL)
-- Basado en: Planification/06-modelo-datos-y-esquema-db.md
--          y Planification/07-seguridad-autenticacion-y-acl.md
-- =============================================================================

-- Extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. IDENTIDAD, AUTENTICACIÓN Y CONTROL DE ACCESO (ACL)
-- =============================================================================

-- Usuarios del sistema
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(64) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tokens de Acceso Personal (PAT) para CI/CD y CLI
CREATE TABLE IF NOT EXISTS personal_access_tokens (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    scopes JSONB NOT NULL DEFAULT '["*"]'::jsonb,
    expires_at TIMESTAMP WITH TIME ZONE,
    last_used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Roles del sistema
CREATE TABLE IF NOT EXISTS roles (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    description TEXT
);

-- Relación usuarios y roles
CREATE TABLE IF NOT EXISTS user_roles (
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id VARCHAR(36) NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- Catálogo maestro de permisos
CREATE TABLE IF NOT EXISTS permissions (
    id VARCHAR(36) PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    description TEXT NOT NULL
);

-- Lista de Control de Acceso Granular (ACL)
CREATE TABLE IF NOT EXISTS access_control_list (
    id VARCHAR(36) PRIMARY KEY,
    subject_type VARCHAR(16) NOT NULL CHECK (subject_type IN ('USER', 'ROLE')),
    subject_id VARCHAR(36) NOT NULL,
    resource_type VARCHAR(16) NOT NULL CHECK (resource_type IN ('GLOBAL', 'REPOSITORY', 'PACKAGE')),
    resource_id VARCHAR(36),
    permission_id VARCHAR(36) NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    effect VARCHAR(8) NOT NULL DEFAULT 'ALLOW' CHECK (effect IN ('ALLOW', 'DENY')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_acl_rule UNIQUE (subject_type, subject_id, resource_type, resource_id, permission_id)
);

-- =============================================================================
-- 2. GESTIÓN DE REPOSITORIOS, PAQUETES Y VERSIONES
-- =============================================================================

-- Repositorios lógicos del sistema (Local, Proxy, Virtual)
CREATE TABLE IF NOT EXISTS repositories (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(128) NOT NULL UNIQUE,
    description TEXT,
    repo_type VARCHAR(16) NOT NULL CHECK (repo_type IN ('LOCAL', 'PROXY', 'VIRTUAL')),
    format VARCHAR(16) NOT NULL CHECK (format IN ('OCI', 'PYPI', 'NUGET', 'CARGO', 'GO')),
    upstream_url VARCHAR(512),
    virtual_default_target_id VARCHAR(36) REFERENCES repositories(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Paquetes lógicos dentro de un repositorio
CREATE TABLE IF NOT EXISTS packages (
    id VARCHAR(36) PRIMARY KEY,
    repo_id VARCHAR(36) NOT NULL REFERENCES repositories(id) ON DELETE CASCADE,
    name VARCHAR(256) NOT NULL,
    normalized_name VARCHAR(256) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_repo_package UNIQUE (repo_id, normalized_name)
);

-- Versiones específicas de un paquete
CREATE TABLE IF NOT EXISTS versions (
    id VARCHAR(36) PRIMARY KEY,
    package_id VARCHAR(36) NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
    version_string VARCHAR(128) NOT NULL,
    is_yanked BOOLEAN NOT NULL DEFAULT FALSE,
    is_latest BOOLEAN NOT NULL DEFAULT FALSE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_package_version UNIQUE (package_id, version_string)
);

-- =============================================================================
-- 3. ALMACENAMIENTO DIRECCIONABLE POR CONTENIDO (CAS)
-- =============================================================================

-- Bloques físicos únicos almacenados
CREATE TABLE IF NOT EXISTS blobs (
    sha256 VARCHAR(64) PRIMARY KEY,
    size_bytes BIGINT NOT NULL,
    storage_tier VARCHAR(16) NOT NULL DEFAULT 'WARM' CHECK (storage_tier IN ('HOT', 'WARM', 'COLD')),
    storage_path VARCHAR(512) NOT NULL,
    compression VARCHAR(16) DEFAULT 'NONE' CHECK (compression IN ('NONE', 'GZIP', 'ZSTD')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Asociación Many-to-Many entre versiones y bloques CAS
CREATE TABLE IF NOT EXISTS version_blobs (
    version_id VARCHAR(36) NOT NULL REFERENCES versions(id) ON DELETE CASCADE,
    blob_sha256 VARCHAR(64) NOT NULL REFERENCES blobs(sha256),
    chunk_order INT NOT NULL DEFAULT 0,
    logical_path VARCHAR(512) NOT NULL,
    part_type VARCHAR(32) NOT NULL DEFAULT 'LAYER' CHECK (part_type IN ('MANIFEST', 'CONFIG', 'LAYER', 'SOURCE', 'BINARY')),
    PRIMARY KEY (version_id, blob_sha256, logical_path)
);

-- Metadatos del Hot Tier (Caché Local) y control de evicción GDSF
CREATE TABLE IF NOT EXISTS blob_cache_metadata (
    blob_sha256 VARCHAR(64) PRIMARY KEY REFERENCES blobs(sha256) ON DELETE CASCADE,
    local_cache_path VARCHAR(512) NOT NULL,
    priority_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    access_count BIGINT NOT NULL DEFAULT 1,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cached_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 4. AUDITORÍA DE OPERACIONES
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(36),
    action VARCHAR(64) NOT NULL,
    resource_type VARCHAR(32) NOT NULL,
    resource_id VARCHAR(256) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- 5. ÍNDICES DE RENDIMIENTO (SUB-5MS)
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_packages_normalized ON packages(repo_id, normalized_name);
CREATE INDEX IF NOT EXISTS idx_versions_package_latest ON versions(package_id, is_latest);
CREATE INDEX IF NOT EXISTS idx_versions_metadata_gin ON versions USING gin (metadata);
CREATE INDEX IF NOT EXISTS idx_version_blobs_version ON version_blobs(version_id);
CREATE INDEX IF NOT EXISTS idx_version_blobs_blob ON version_blobs(blob_sha256);
CREATE INDEX IF NOT EXISTS idx_blobs_last_accessed ON blobs(last_accessed_at);
CREATE INDEX IF NOT EXISTS idx_blob_cache_score ON blob_cache_metadata(priority_score ASC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp DESC);

-- =============================================================================
-- 6. DATOS SEMILLA PARA DESARROLLO (SEED DATA)
-- =============================================================================

-- Permisos iniciales
INSERT INTO permissions (id, code, description) VALUES
    ('perm_pkg_download', 'pkg:download', 'Descarga y lectura de artefactos y metadatos'),
    ('perm_pkg_upload',   'pkg:upload',   'Publicación y subida de nuevas versiones o paquetes'),
    ('perm_pkg_delete',   'pkg:delete',   'Revocación o borrado de versiones de artefactos'),
    ('perm_repo_read',    'repo:read',    'Listar y visualizar repositorios'),
    ('perm_repo_write',   'repo:write',   'Modificar configuración de repositorios'),
    ('perm_repo_admin',   'repo:admin',   'Crear, borrar y administrar repositorios'),
    ('perm_admin_gc',     'admin:gc',     'Ejecutar recolección de basura manual')
ON CONFLICT (code) DO NOTHING;

-- Roles iniciales
INSERT INTO roles (id, name, description) VALUES
    ('role_admin',     'Admin',      'Acceso total a la plataforma y repositorios'),
    ('role_developer', 'Developer',  'Permisos de lectura y subida en repositorios internos'),
    ('role_cirunner',  'CI-Runner',  'Tokens de automatización de pipelines CI/CD'),
    ('role_reader',    'Reader',     'Solo lectura y descarga de paquetes')
ON CONFLICT (name) DO NOTHING;

-- Usuario administrador por defecto para desarrollo local
-- Password por defecto: 'admin123' (hash bcrypt / argon2 genérico para dev)
INSERT INTO users (id, username, email, password_hash, is_active, is_admin) VALUES
    ('usr_dev_admin', 'admin', 'admin@kinara.local', '$2a$12$e8Y50q7E4U5hGzW2yF4F7Oeq0k6hR29gX9yq3tX9Uq7tUq7tUq7tu', TRUE, TRUE)
ON CONFLICT (username) DO NOTHING;

-- Asignar rol Admin al usuario admin
INSERT INTO user_roles (user_id, role_id) VALUES
    ('usr_dev_admin', 'role_admin')
ON CONFLICT DO NOTHING;

-- Repositorios base para pruebas locales
INSERT INTO repositories (id, name, description, repo_type, format, upstream_url) VALUES
    ('repo_docker_local', 'docker-local', 'Imágenes de Docker y artefactos OCI locales', 'LOCAL', 'OCI', NULL),
    ('repo_pypi_local',   'pypi-local',   'Paquetes Python Wheels y sdist locales',      'LOCAL', 'PYPI', NULL),
    ('repo_cargo_local',  'cargo-local',  'Crates privados de Rust',                    'LOCAL', 'CARGO', NULL),
    ('repo_docker_proxy', 'docker-hub',   'Proxy caché transparente de Docker Hub',     'PROXY', 'OCI', 'https://registry-1.docker.io'),
    ('repo_pypi_proxy',   'pypi-org',     'Proxy caché transparente de PyPI público',    'PROXY', 'PYPI', 'https://pypi.org/simple')
ON CONFLICT (name) DO NOTHING;
