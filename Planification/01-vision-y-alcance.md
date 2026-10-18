# 01. Visión del Producto, Pilares y Alcance Técnico

## 1. Visión General y Propuesta de Valor

El proyecto **Kinara Registry** nace de la necesidad de contar con un registro privado y multifacético de artefactos moderno, autohosteable (*self-hosted*), altamente eficiente y diseñado específicamente para entornos nativos de la nube (*cloud-native*).

En el ecosistema tecnológico actual, soluciones consagradas como **JFrog Artifactory** o **Sonatype Nexus** presentan barreras significativas para equipos y organizaciones medianas:

* **Consumo excesivo de recursos:** Dependencias pesadas basadas en la JVM que requieren múltiples gigabytes de memoria RAM sólo para arrancar en reposo.
* **Sobrecarga de configuración y mantenimiento:** Dificultad para desplegar rápidamente instancias efímeras para pruebas, CI/CD o entornos *edge*.
* **Modelos de licenciamiento restrictivos:** Características esenciales como la deduplicación avanzada, réplicas globales o alta disponibilidad suelen estar bloqueadas tras costosas licencias empresariales.

**Kinara Registry** propone una alternativa moderna construida sobre estándares abiertos, con una huella mínima de recursos, despliegue inmediato en contenedores y compatibilidad nativa con almacenamiento de objetos (compatible con la API de S3).

---

## 2. Pilares Fundamentales

La ingeniería del sistema se sustenta sobre tres principios rectores innegociables:

```mermaid
flowchart LR
    A["Despliegue Zero-Config"] --> D["Kinara Registry"]
    B["Arquitectura OCI-First"] --> D
    C["Experiencia de Desarrollador (DX)"] --> D
```

### 2.1. Despliegue Zero-Config (*Zero-Friction Operations*)
El sistema debe estar listo para operar en cuestión de segundos mediante comandos estándar:
* **Entornos locales o pequeños:** `docker compose up -d` inicializa la base de datos embebida (SQLite/PostgreSQL) y el almacenamiento local o MinIO.
* **Entornos de producción:** `helm install kinara ./helm/kinara` aprovisiona los pods, servicios, escalado automático horizontal (HPA) y conectividad con buckets S3 (AWS S3, MinIO, Cloudflare R2, Google Cloud Storage).
* La autoconfiguración inicial crea automáticamente las claves criptográficas para firmas de tokens, las migraciones de base de datos y los repositorios base sin interacción manual obligatoria.

### 2.2. Arquitectura Basada en el Estándar OCI (*Open Container Initiative*)
En lugar de crear motores de almacenamiento propietarios para cada gestor de dependencias:
* Se adopta la **especificación OCI Distribution Spec** y **OCI Image Spec** como el sustrato universal de persistencia.
* Todos los paquetes (imágenes Docker, Helm charts, librerías de lenguajes) se traducen o asocian internamente a una estructura de *manifests*, *configs* y *blobs* inmutables.
* Esto simplifica el motor de almacenamiento, centraliza la deduplicación y permite que cualquier cliente OCI compatible interactúe con el registro de manera nativa.

### 2.3. Experiencia de Desarrollador Limpia (*DX First*)
Una infraestructura es tan buena como la facilidad con la que los desarrolladores pueden adoptarla:
* **Asistentes "Set Me Up":** Generadores interactivos de configuración en un clic para generar archivos listos para copiar y pegar (`.npmrc`, `pip.conf`, `.docker/config.json`, `nuget.config`, `config.toml` de Cargo).
* **Autenticación transparente:** Compatibilidad con Personal Access Tokens (PAT) de expiración configurable y credenciales nativas de CLI.
* **Telemetría visual clara:** Métricas de espacio ahorrado por deduplicación, tasa de aciertos de caché (*cache hit ratio*) y latencias de red en tiempo real.

---

## 3. Alcance Técnico y Formatos Soportados (MVP)

Para el Producto Mínimo Viable (MVP), Kinara Registry se enfoca en los ecosistemas de mayor impacto en infraestructuras y pipelines de ingeniería de software:

| Formato / Ecosistema | Especificación / Protocolo CLI | Tipos de Artefactos | Casos de Uso Típicos |
| :--- | :--- | :--- | :--- |
| **Contenedores Docker / OCI** | OCI Distribution Spec v1.1+ / Docker Registry v2 | Imágenes de contenedores, OCI Artifacts, Helm Charts v3+ | Despliegue en Kubernetes, CI/CD, base images empresariales |
| **Python (pip / PyPI)** | PEP 503 (Simple Repository API), PEP 658 | Wheels (`.whl`), Source Distributions (`.tar.gz`) | Microservicios en FastAPI/Django, pipelines de Machine Learning / Data Science |
| **.NET (NuGet)** | NuGet Server API v3 (Service Index, Registration, Package Content) | Paquetes `.nupkg`, `.snupkg` (símbolos) | Librerías compartidas en C#, servicios backend corporativos |
| **Golang (Go Modules)** | Go Module Proxy Protocol (`@v/list`, `.info`, `.mod`, `.zip`) | Módulos y dependencias comprimidas de Go | Desarrollo de microservicios Go de alto rendimiento y CLIs internas |
| **Rust (Cargo / Crates)** | Cargo Sparse Registry Protocol / Git Index Protocol | Crates binarios empaquetados (`.crate`) y metadatos JSON | Sistemas embebidos, utilidades CLI nativas, motores de cálculo |

---

## 4. Decisiones de Diseño y Justificación Técnica (Trade-Offs)

### Decisión 1: OCI como Estándar de Almacenamiento Central
* **Alternativa Evaluada:** Construir un motor de almacenamiento independiente con directorios y esquemas específicos para cada lenguaje (ej. una carpeta `/pypi`, otra `/nuget`, otra `/docker`).
* **Decisión Adoptada:** Emplear OCI como capa común y Content-Addressable Storage (CAS) basado en SHA-256.
* **Justificación:** Los formatos de artefactos modernos convergen hacia OCI (Helm v3 ya es OCI, WebAssembly se distribuye como OCI, e incluso Homebrew/Cosign usan OCI). Al desacoplar el protocolo externo del almacenamiento interno mediante CAS, se logra deduplicación cruzada entre diferentes tipos de artefactos.

### Decisión 2: Enfoque de 5 Formatos en el MVP
* **Alternativa Evaluada:** Incluir soporte para Maven (Java), npm (Node.js), RPM, Debian y RubyGems desde la versión 1.0.
* **Decisión Adoptada:** Limitar el MVP a Docker/OCI, Python, NuGet, Go y Rust.
* **Justificación:** Cubrir de inmediato el espectro de contenedores, el lenguaje líder de Cloud Native (Go), el lenguaje dominante en IA/Scripting (Python), el entorno empresarial tradicional (.NET) y el lenguaje moderno de alto rendimiento (Rust). Permite consolidar la arquitectura de adaptadores sin saturar la deuda técnica inicial.

### Decisión 3: Desacoplamiento Estricto entre Backend y UI
* **Decisión:** La interfaz de administración web es una SPA (*Single Page Application*) que consume exclusivamente la API pública y privada de Kinara, sin acoplamiento con plantillas generadas en el servidor (*server-side rendering* monolítico).
* **Justificación:** Garantiza que el 100% de las funcionalidades disponibles en la interfaz web sean automatizables vía API por pipelines de CI/CD, scripts de Terraform o herramientas CLI.
