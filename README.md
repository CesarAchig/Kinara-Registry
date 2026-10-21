# Kinara-Registry

A universal private artifact repository and package cache for secure internal deployments across any stack (Docker/OCI, NuGet, Python, Go, Rust, and more).

---

## 1. Visión General y Propuesta de Valor

El proyecto **Kinara Registry** nace de la necesidad de contar con un registro privado y multifacético de artefactos moderno, autohosteable (*self-hosted*), altamente eficiente y diseñado específicamente para entornos nativos de la nube (*cloud-native*).

En el ecosistema tecnológico actual, soluciones consagradas como **JFrog Artifactory** o **Sonatype Nexus** presentan barreras significativas para equipos y organizaciones medianas:

* **Consumo excesivo de recursos:** Dependencias pesadas basadas en la JVM que requieren múltiples gigabytes de memoria RAM sólo para arrancar en reposo.
* **Sobrecarga de configuración y mantenimiento:** Dificultad para desplegar rápidamente instancias efímeras para pruebas, CI/CD o entornos *edge*.
* **Modelos de licenciamiento restrictivos:** Características esenciales como la deduplicación avanzada, réplicas globales o alta disponibilidad suelen estar bloqueadas tras costosas licencias empresariales.

**Kinara Registry** propone una alternativa moderna construida sobre estándares abiertos, con una huella mínima de recursos, despliegue inmediato en contenedores y compatibilidad nativa con almacenamiento de objetos (compatible con la API de S3).

---

## 📚 Documentación y Planificación Arquitectónica

Toda la documentación técnica, decisiones de diseño, modelos matemáticos, esquemas de bases de datos y la hoja de ruta de desarrollo se encuentran detallados en el directorio [`Planification/`](./Planification/):

* [`Planification/README.md`](./Planification/README.md) — Índice general y mapa de componentes.
* [`Planification/01-vision-y-alcance.md`](./Planification/01-vision-y-alcance.md) — Visión, pilares y ecosistemas del MVP.
* [`Planification/02-arquitectura-del-sistema.md`](./Planification/02-arquitectura-del-sistema.md) — Separación entre Plano de Control y Plano de Datos.
* [`Planification/03-estrategia-almacenamiento-cas.md`](./Planification/03-estrategia-almacenamiento-cas.md) — Almacenamiento CAS de fichero completo, autorización por repositorio y jerarquía de almacenamiento (FS/S3 + Hot Tier NVMe).
* [`Planification/04-tipos-de-repositorios.md`](./Planification/04-tipos-de-repositorios.md) — Repositorios Locales, Proxy, Virtuales y mitigación de Dependency Confusion.
* [`Planification/05-algoritmos-y-optimizaciones.md`](./Planification/05-algoritmos-y-optimizaciones.md) — Algoritmos clave: deduplicación CAS, evicción GDSF en Hot Tier, Inflight Coalescing sobre staging y Zero-Downtime GC con leases.
* [`Planification/06-modelo-datos-y-esquema-db.md`](./Planification/06-modelo-datos-y-esquema-db.md) — Esquema de base de datos relacional y metadatos JSONB.
* [`Planification/07-seguridad-autenticacion-y-acl.md`](./Planification/07-seguridad-autenticacion-y-acl.md) — Modelo de seguridad, tokens PAT/JWT y control de acceso granular (ACL).
* [`Planification/08-roadmap-y-fases-desarrollo.md`](./Planification/08-roadmap-y-fases-desarrollo.md) — Fases de implementación e hitos de ingeniería.
* [`Planification/09-investigacion-aplicaciones-y-stack-tecnologico.md`](./Planification/09-investigacion-aplicaciones-y-stack-tecnologico.md) — Desacoplamiento de aplicaciones y selección de stack tecnológico.

