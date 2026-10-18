# 09. Investigación Arquitectónica: Desacoplamiento de Aplicaciones y Stack Tecnológico

## 1. Resumen Ejecutivo y Objeto del Estudio

El presente documento evalúa la viabilidad técnica, los compromisos de ingeniería (*trade-offs*) y las recomendaciones de tecnologías para la composición de aplicaciones en **Kinara Registry**.

La premisa inicial del proyecto planteaba una arquitectura clásica de dos componentes:
1. **Un Backend monolítico (API):** Encargado de la lógica de negocio, enrutamiento de protocolos, procesamiento de datos pesados y tareas en segundo plano.
2. **Un Frontend (Dashboard Web UI):** Encargado de la visualización del registro, exploración de paquetes y configuración del desarrollador.

Tras contrastar esta idea con los requisitos definidos en los documentos previos —especialmente la **Separación de Planos** ([`02-arquitectura-del-sistema.md`](file:///home/cesar/Projects/Kinara-Registry/Planification/02-arquitectura-del-sistema.md)), la deduplicación por bloques **FastCDC** y el recolector **Zero-Downtime GC** ([`05-algoritmos-y-optimizaciones.md`](file:///home/cesar/Projects/Kinara-Registry/Planification/05-algoritmos-y-optimizaciones.md)) y los pilares de **Despliegue Zero-Config** y **Baja Huella de Recursos** ([`01-vision-y-alcance.md`](file:///home/cesar/Projects/Kinara-Registry/Planification/01-vision-y-alcance.md))—, se concluye que:

> [!IMPORTANT]
> Un monolito estricto de una sola aplicación backend corre el riesgo de degradar la experiencia de usuario y la estabilidad operativa al mezclar transferencia de datos masiva (*streaming I/O* de gigabytes) con la API transaccional de metadatos y tareas pesadas de mantenimiento en segundo plano. No obstante, fragmentar el sistema prematuramente en múltiples microservicios independientes destruiría el pilar de **Despliegue Zero-Config** (`docker compose up -d`).

Por ello, se propone una arquitectura de **Monolito Modular con Ejecución Multi-Rol (Unified Monorepo & Multi-Binary/Role Runtime)**, complementada por aplicaciones desacoplables según la escala del entorno.

---

## 2. Análisis de Topología: ¿2 Aplicaciones o Servicios Desacoplados?

```mermaid
flowchart TB
    subgraph EnfoqueA["Opción A: Modelo Bi-Aplicación Tradicional"]
        direction TB
        UI1["Frontend SPA"]
        API1["Backend Monolítico\n(Control + Data Plane + Workers + Adapters)"]
        UI1 --> API1
    end

    subgraph EnfoqueB["Opción B: Desacoplamiento Multi-Rol (Recomendado)"]
        direction TB
        UI2["1. Kinara Dashboard (SPA)"]
        CLI2["2. Kinara CLI (Dev & Ops)"]
        
        subgraph CorePlatform["Plataforma Core (Binario Unificado o Roles Segregados)"]
            Control2["Rol: Control Plane & Gateway API"]
            Data2["Rol: Data Plane Engine (FastCDC / CAS)"]
            Worker2["Rol: Background Worker (GC / GDSF / Scanner)"]
        end
        
        UI2 --> Control2
        CLI2 --> Control2
        Control2 <--> Data2
        Worker2 -.-> Data2
    end
```

### 2.1. Evaluación del Enfoque Inicial (2 Aplicaciones)

| Ventajas del Modelo Bi-Aplicación | Riesgos y Limitaciones Técnicas |
| :--- | :--- |
| **Simplicidad de despliegue:** Un único contenedor backend y un contenedor/servidor web para la UI (o incluso la UI embebida dentro del backend). | **Problema del "Vecino Ruidoso" (*Noisy Neighbor*):** El cálculo de hashes SHA-256 o el chunking FastCDC de una imagen Docker de $4\text{ GB}$ compite por ciclos de CPU con las consultas de autenticación y navegación de la UI. |
| **Menor sobrecarga de CI/CD:** Solo dos pipelines de construcción y dos imágenes de contenedor que versionar. | **Incompatibilidad de escalado:** El Plano de Control (ligero, sensible a latencia) escala horizontalmente por peticiones HTTP/s, mientras que el Plano de Datos escala por throughput de red y memoria de buffers. |
| **Desarrollo inicial acelerado:** Menor cantidad de repositorios, contratos de red internos o mecanismos de coordinación entre procesos. | **Riesgo de bloqueo en el ciclo de vida:** Tareas como el *Garbage Collection (Sweep)* de miles de blobs pueden degradar el pool de conexiones de la base de datos compartido con el API público. |

---

### 2.2. Oportunidades Clave de Desacoplamiento Standalone

Identificamos **tres componentes candidatos naturales** para ser desacoplados como aplicaciones o procesos independientes:

#### 1. Kinara Worker (Daemon de Tareas Asíncronas)
* **Responsabilidades:** Ejecución del ciclo de *Mark-and-Sweep* (GC) con período de gracia de 24h, evicción de caché local GDSF, auditoría asíncrona y verificación de integridad criptográfica periódica.
* **Por qué desacoplarlo:** Las operaciones de mantenimiento son intensivas en disco y CPU, pero tolerantes a latencia. En entornos Kubernetes o clústeres de producción, deben correr como un `CronJob` o un `Deployment` independiente con límites de recursos (*resource limits*) estrictos para no restar capacidad al tráfico de usuarios.

#### 2. Kinara Storage / Data Plane (Motor de Streaming y CAS)
* **Responsabilidades:** Recepción de bytes en staging, particionamiento FastCDC con ventana deslizante de Gear, compresión adaptativa `zstd:chunked` y conexión directa con almacenamiento S3/MinIO.
* **Por qué desacoplarlo:** Permite aislar los buffers de memoria de red y los procesos intensivos de streaming I/O. En despliegues distribuidos de alto volumen, múltiples nodos de Data Plane pueden situarse cerca del almacenamiento físico o en zonas de disponibilidad específicas.

#### 3. Kinara CLI (`kinara`)
* **Responsabilidades:** Autenticación rápida desde terminal, configuración automática de entornos de desarrollo (`kinara setup npm|pypi|docker`), inspección forense de blobs, migración de repositorios y operaciones administrativas de emergencia fuera del navegador.
* **Por qué desacoplarlo:** Aporta una experiencia de desarrollador de primer nivel (*DX First*), convirtiéndose en la herramienta favorita de pipelines CI/CD y DevOps sin depender de una interfaz gráfica.

---

### 2.3. La Solución Óptima: "Monolito Modular con Ejecución Multi-Rol"

Para no renunciar al pilar **Zero-Config** (`docker compose up -d` inmediato) ni a la **Escalabilidad Cloud-Native**, la mejor decisión de arquitectura es adoptar el patrón **Single-Binary Multi-Role**:

* **Un único repositorio de código (*Monorepo*):** Todo el backend se construye como una unidad limpia y modular.
* **Un único ejecutable compilado:** El binario resultante puede ejecutarse en distintos modos mediante comandos o variables de entorno:
  * `kinara server --mode=all` (Por defecto: arranca Control Plane, Data Plane y Workers embebidos; ideal para local, edge y CI efímero).
  * `kinara server --mode=api` (Solo Control Plane, API REST y Gateway OCI).
  * `kinara server --mode=storage` (Solo Data Plane de alto rendimiento I/O).
  * `kinara worker` (Solo el daemon de GC, escaneo y evicción GDSF).
* **Frontend SPA independiente:** Se desarrolla y prueba de forma aislada, pero en producción sus artefactos estáticos pueden **embebérsele al binario del backend** o servirse mediante un Ingress/Nginx.

---

## 3. Matriz Comparativa y Recomendación de Lenguajes Backend

Para seleccionar el lenguaje del Backend (Control Plane, Data Plane y Workers), se evaluaron las opciones contra los requisitos críticos de Kinara:

```mermaid
quadrantChart
    title Evaluación de Lenguajes para el Backend de Kinara
    x-axis "Bajo Ecosistema OCI/Cloud-Native" --> "Alto Ecosistema OCI/Cloud-Native"
    y-axis "Mayor Consumo / Latencia" --> "Máximo Rendimiento & Baja Huella"
    quadrant-1 "Zona Ideal (Recomendada)"
    quadrant-2 "Especializado / Alto Esfuerzo"
    quadrant-3 "No Recomendado para Core"
    quadrant-4 "Ecosistema Alto pero Rendimiento Medio"
    "Go (Golang)": [0.94, 0.88]
    "Rust": [0.65, 0.98]
    ".NET 8/9 (C# AOT)": [0.42, 0.80]
    "Node.js / TypeScript": [0.55, 0.38]
    "Python": [0.35, 0.22]
    "Java (JVM)": [0.60, 0.45]
```

### 3.1. Tabla Comparativa de Candidatos Backend

| Criterio de Selección | **Go (Golang)** | **Rust** | **.NET 8/9 (C#)** | **Node.js (TypeScript)** |
| :--- | :--- | :--- | :--- | :--- |
| **Huella de Memoria Base** | 🟢 **Ultra-baja** (15 - 30 MB en reposo) | 🟢 **Mínima** (5 - 15 MB en reposo) | 🟡 **Media** (40 - 90 MB con AOT) | 🔴 **Alta** (80 - 150 MB en reposo) |
| **Rendimiento I/O y Streaming** | 🟢 **Excelente:** Abstracciones `io.Reader/Writer`, `io.Pipe`, `io.TeeReader` nativas y zero-copy. | 🟢 **Insuperable:** Control de memoria manual, procesamiento asíncrono con `tokio` sin pausas GC. | 🟡 **Bueno:** `System.IO.Pipelines` de alto rendimiento, pero mayor complejidad de tuning. | 🔴 **Deficiente:** El event loop se satura al procesar flujos continuos de gigabytes y hashing simultáneo. |
| **Ecosistema OCI & Contenedores** | 🟢 **Estándar de la Industria:** Docker, Kubernetes, containerd, Harbor y Skopeo están en Go. Librerías OCI oficiales disponibles. | 🟡 **Emergente:** Existen crates como `oci-distribution`, pero requieren construir gran parte del protocolo a mano. | 🔴 **Muy limitado:** Prácticamente inexistente; requiere implementar la especificación OCI desde cero. | 🟡 **Moderado:** Existen paquetes comunitarios, pero con bajo mantenimiento para especificaciones modernas. |
| **Implementación FastCDC & Bitwise** | 🟢 **Muy Rápida:** Operaciones a nivel de bit eficientes; throughput de >900 MB/s con `sync.Pool`. | 🟢 **Extrema:** Throughput de 2.5 - 4 GB/s aprovechando vectorización SIMD nativa. | 🟡 **Buena:** `Span<T>` y `Memory<T>` permiten alto throughput si se optimiza a bajo nivel. | 🔴 **Inadecuada:** Los tipos numéricos de JS y el paso por V8 penalizan severamente el cálculo intensivo de hashes. |
| **Concurrencia Nativa** | 🟢 **Goroutines & Canales:** Patrones de concurrencia como `singleflight` (`golang.org/x/sync/singleflight`) incluidos en el ecosistema. | 🟢 **Fearless Concurrency:** Garantías estrictas de ausencia de data races en tiempo de compilación. | 🟡 **Async/Await con ThreadPool:** Robusto, pero más pesado en consumo de memoria por hilo. | 🔴 **Single-Threaded:** Depende de `worker_threads` pesados para tareas de cómputo intensivo. |
| **Tiempo de Compilación y DX** | 🟢 **Instantáneo:** Compilación en segundos, binario estático autocontenido sin dependencias externas. | 🔴 **Lento:** Tiempos de compilación largos con macros complejas; curva de aprendizaje pronunciada. | 🟡 **Moderado:** Compilación cruzada buena, pero Native AOT añade minutos al build. | 🟢 **Rápido:** No requiere compilación tradicional (JIT / esbuild / SWC). |

---

### 3.2. Veredicto Backend: Go (Golang) como Lenguaje Principal

> [!TIP]
> **Recomendación Definitiva para el Backend:** **Go (Golang)** es la elección óptima para el Core de Kinara Registry.
> 
> * **Justificación Estratégica:** Go es el lenguaje vehicular de todo el ecosistema nativo de la nube. Adoptar Go permite reutilizar directamente los paquetes canónicos de la Open Container Initiative (`github.com/opencontainers/image-spec`, `distribution/distribution`), reduciendo meses de ingeniería inversa en la especificación OCI.
> * **Justificación de Concurrencia:** La biblioteca estándar de Go (`io.TeeReader`, `io.MultiWriter`, `sync.Pool`) y extensiones oficiales como `singleflight` resuelven de forma natural y con escasas líneas de código el **Cut-Through Streaming** y la **Supresión de Estampidas** planificados en el [`05-algoritmos-y-optimizaciones.md`](file:///home/cesar/Projects/Kinara-Registry/Planification/05-algoritmos-y-optimizaciones.md).
> * **Alternativa en Módulos Críticos:** Si en fases posteriores el particionamiento FastCDC requiere rendimiento extremo en clusters con hardware específico, dicho algoritmo puede encapsularse en una pequeña librería en **Rust** compilada mediante CGO / C-ABI o WebAssembly, manteniendo el resto del sistema en Go puro.

---

## 4. Investigación Exhaustiva del Entorno UI: Runtimes, Reactividad y Tooling

La interfaz web de Kinara Registry es la cara visible de la plataforma para los desarrolladores y administradores. Este apartado analiza en profundidad el modelo de renderizado idóneo, evalúa si una web estática o soluciones minimalistas bastan, examina el papel disruptivo de **Bun** en la cadena de desarrollo y compara los frameworks de reactividad disponibles.

```mermaid
flowchart TD
    subgraph DeliveryModel["1. Modelo de Renderizado"]
        Static["Web Estática Pura\n(HTML/CSS Plano)"] -.->|"INSUFICIENTE: Sin estado dinámico"| Rejected["Descartada"]
        HTMX["Server-Driven UI\n(Go Templates + HTMX)"] -.->|"VIABLE PERO LIMITADA: Acopla API con HTML"| Partial["Uso Acotado"]
        SPA["Client-Side SPA Reactiva\n(Consumo REST/JSON puro)"] ==>|"RECOMENDADA: Cumple Decisión 3 (Doc 01)"| Approved["Modelo Óptimo"]
    end

    subgraph ToolingAndBuild["2. Motor de Build & CI/CD"]
        Bun["Bun (Runtime, Bundler & Package Manager)\n- bun install (3s vs 45s npm)\n- bun build / bunx vite\n- Codegen TypeScript nativo"]
    end

    subgraph ReactiveOptions["3. Framework de UI en Cliente"]
        React["Opción A: React 19 + shadcn/ui\n(Máximo ecosistema y componentes de dashboard)"]
        Svelte["Opción B: Svelte 5 (Runes)\n(Máximo rendimiento y bundle ultra-ligero para Go embed)"]
    end

    Approved --> Bun
    Bun --> React
    Bun --> Svelte
```

---

### 4.1. Análisis del Modelo de Renderizado: ¿Sirve una Web Estática?

Se entiende por **web estática pura** un sitio web compuesto exclusivamente de documentos HTML y estilos CSS pregenerados (o generados mediante generadores estáticos como Hugo o Astro en modo SSG), sin lógica de cliente compleja ni gestión de estado reactivo.

> [!CAUTION]
> **Conclusión del análisis:** Una web puramente estática **NO es viable** para Kinara Registry. 

Un registro de artefactos empresarial no es un sitio de documentación ni un blog informativo; es una **consola de operaciones de misión crítica** que requiere alta interactividad en los siguientes flujos funcionales:

1. **Generador Interactivo "Set Me Up":** No se limita a mostrar bloques de texto fijos. El usuario selecciona su sistema operativo (Linux, macOS, Windows), el formato deseado (Docker, pip, Cargo, NuGet, Go) y el repositorio (local, proxy o virtual). La interfaz debe generar en tiempo real los fragmentos de configuración (`.npmrc`, `pip.conf`, `nuget.config`), inyectando las URLs canónicas y tokens de sesión de un solo clic con botón de copiado al portapapeles.
2. **Explorador y Búsqueda Facetada en Tiempo Real:** En repositorios con miles de versiones, capas OCI y metadatos de dependencias, recargar la página completa en cada filtrado destruye la experiencia de desarrollo (DX). Se requiere filtrado instantáneo en cliente y paginación virtualizada.
3. **Telemetría y Métricas en Vivo:** El dashboard debe reflejar el estado del almacenamiento en tiempo real: ratio de deduplicación FastCDC (ahorro en GB), latencia de proxies remotos, tasa de aciertos de caché (*cache hit ratio*) y barras de progreso activas durante el recolector de basura (*GC Mark & Sweep*). Esto exige conexión continua (SSE o WebSockets) y renderizado reactivo de gráficos.
4. **Gestión de Repositorios Virtuales (Drag & Drop):** Los repositorios virtuales agrupan repositorios locales y remotos con un orden de precedencia estricto para mitigar ataques de *Dependency Confusion* ([`04-tipos-de-repositorios.md`](file:///home/cesar/Projects/Kinara-Registry/Planification/04-tipos-de-repositorios.md)). Reordenar esta jerarquía exige componentes visuales interactivos de arrastrar y soltar.
5. **Control de Acceso Granular (ACL) y Tokens PAT:** Creación interactiva de tokens de acceso personal con selección dinámica de alcances (*scopes*), cálculo de expiración al vuelo y visualización de matrices de permisos por repositorio.

Por tanto, Kinara Registry requiere imperativamente un **entorno reactivo con gestión de estado en el cliente**.

---

### 4.2. ¿Podría funcionar algo más simple que React? Evaluación del Espectro de Reactividad

Frente al peso habitual de React, se investigaron dos alternativas arquitectónicas: el enfoque *Server-Driven* y los frameworks *Ultraligeros sin Virtual DOM*.

#### Enfoque 1: Server-Driven UI (Go `html/template` + HTMX + Alpine.js)
* **Cómo opera:** El servidor Go renderiza el HTML. HTMX intercepta formularios y enlaces para reemplazar fragmentos del DOM vía AJAX. Alpine.js aporta micro-interactividad (modales, pestañas, menús desplegables).
* **Puntos Fuertes:**
  * **Cero compilación de JS:** El backend Go compila todo; no se requiere Node.js, npm ni Vite.
  * **Huella mínima:** HTMX pesa $\sim 14\text{ KB}$ y Alpine $\sim 15\text{ KB}$.
* **Por qué NO se recomienda para Kinara:**
  * **Violación de la Decisión 3 ([`01-vision-y-alcance.md`](file:///home/cesar/Projects/Kinara-Registry/Planification/01-vision-y-alcance.md)):** Obliga al backend en Go a mantener dos conjuntos de rutas: unas que devuelven JSON (para las herramientas CLI como Docker o Cargo) y otras que devuelven fragmentos HTML (para HTMX), duplicando la lógica de controladores y rompiendo el desacoplamiento estricto.
  * **Deficiencia en telemetría gráfica:** Las mejores librerías de visualización de métricas (gráficos interactivos de líneas, áreas de deduplicación y velocímetros de caché) operan nativamente con datos JSON reactivos; renderizarlas mediante swaps de HTML desde Go genera parpadeos y sobrecarga innecesaria de red.
  * **Falta de componentes de diseño listos:** En HTMX/Alpine no existen bibliotecas con la calidad y accesibilidad de `shadcn/ui`, obligando a diseñar y maquetar cada componente complejo a mano.

#### Enfoque 2: SPAs Ultraligeras (Svelte 5 / Preact / Solid.js)
* **Svelte 5 (con Runes):**
  * Elimina el *Virtual DOM*. El compilador de Svelte transforma los componentes en JavaScript imperativo puro de alta velocidad que actualiza quirúrgicamente el DOM.
  * La versión 5 introduce *Runes* (`$state`, `$derived`, `$effect`), simplificando la reactividad al máximo.
  * **Tamaño del bundle:** Una aplicación completa en Svelte suele pesar entre **$25\text{ KB}$ y $60\text{ KB}$ gzippeada**, frente a los $>150\text{ KB}$ de React.
  * **Idoneidad para Kinara:** Es el candidato ideal si la meta es que los assets embebidos en el binario Go ocupen el menor tamaño en disco posible sin perder reactividad moderna.
* **Preact:**
  * Ofrece la misma interfaz de programación (API) y compatibilidad con componentes React en solo **$3\text{ KB}$**. Permite usar hooks y la mayoría de utilidades de React con `preact/compat`.
* **Solid.js:**
  * Utiliza sintaxis JSX como React, pero implementa reactividad por señales de grano fino (*fine-grained signals*) sin Virtual DOM, logrando el mayor rendimiento de renderizado en navegadores según los benchmarks de JS Framework.

---

### 4.3. El Papel Disruptivo de Bun: Build-Time vs. Run-Time

**Bun** es un runtime de JavaScript/TypeScript, gestor de paquetes y bundler moderno escrito en Zig con el motor JavaScriptCore de WebKit. Para entender su valor en Kinara Registry, es imprescindible distinguir entre dos momentos operativos:

```mermaid
flowchart LR
    subgraph BuildTime["Fase de Desarrollo & CI/CD (BUILD-TIME)"]
        direction TB
        BunTool["Bun Toolkit"]
        B1["bun install (2-3s vs 45s npm)\nCero esperas en CI"]
        B2["bun run codegen\nEjecuta TypeScript sin ts-node"]
        B3["bun build / vite build\nCompilación instantánea a /dist"]
        BunTool --> B1
        BunTool --> B2
        BunTool --> B3
    end

    subgraph RunTime["Fase de Ejecución en Servidor (RUN-TIME)"]
        direction TB
        GoServer["Binario Kinara en Go"]
        Embed["//go:embed web/dist/*\nArchivos estáticos incrustados en RAM"]
        ClientBrowser["Navegador del Usuario"]
        
        GoServer --> Embed
        Embed -->|HTTP 200 / Cache-Control| ClientBrowser
    end

    BuildTime -->|Genera HTML/JS/CSS estáticos| RunTime
```

#### 1. En Tiempo de Ejecución en Producción (*Run-Time*): CERO Dependencias de JS
* Kinara Registry **NO ejecuta Bun ni Node.js en los servidores ni en los contenedores de producción**.
* El frontend se compila previamente a archivos estáticos planos (`index.html`, `app-[hash].js`, `style-[hash].css`).
* El compilador de Go incrusta estos ficheros directamente en el binario compilado usando la directiva nativa:
  ```go
  //go:embed web/dist/*
  var embeddedUI embed.FS
  ```
* **Ventaja Operativa:** El despliegue de Kinara en producción sigue siendo un único ejecutable sin dependencias externas, cumpliendo al 100% el pilar **Zero-Config**.

#### 2. En Tiempo de Construcción y CI/CD (*Build-Time*): El Valor Real de Bun
Donde Bun transforma la productividad del proyecto es en el ciclo de vida de desarrollo y en los pipelines de GitHub Actions / GitLab CI:
* **Instalación Ultrasónica (`bun install`):** Hasta **25 veces más rápido que `npm`** y **4-7 veces más rápido que `pnpm`**. Utiliza llamadas al sistema del kernel (`copy_file_range` en Linux) para clonar paquetes mediante *hardlinks*. Reduce el tiempo del pipeline de CI de 60 segundos a 3 segundos.
* **Ejecución Nativa de TypeScript:** Permite correr scripts `.ts` directamente sin configurar transpiladores (`tsc`) ni herramientas lentas como `ts-node`. Esto es idóneo para el script de **generación de clientes API tipados**:
  * Un script `scripts/generate-api-client.ts` lee la especificación OpenAPI generada por Go y genera los tipos y hooks de `TanStack Query` en $< 200\text{ ms}$ ejecutando `bun run scripts/generate-api-client.ts`.
* **Bundler Nativo de Alta Velocidad (`bun build`):** Puede empaquetar aplicaciones complejas en milisegundos con soporte nativo de JSX y TypeScript, o impulsar a Vite mediante `bunx --bun vite build`.

---

### 4.4. Matriz Comparativa Exhaustiva de Soluciones UI

| Criterio Técnico | **React 19 + Vite (con Bun)** | **Svelte 5 + Vite (con Bun)** | **Go Templates + HTMX** | **Vue 3 + Vite (con Bun)** |
| :--- | :--- | :--- | :--- | :--- |
| **Tamaño de Bundle (Gzipped)** | 🟡 $\sim 140 - 200\text{ KB}$ | 🟢 **$\sim 30 - 60\text{ KB}$** | 🟢 **$\sim 25\text{ KB}$** (HTMX + Alpine) | 🟢 $\sim 70 - 100\text{ KB}$ |
| **Ecosistema de Componentes Dashboard** | 🟢 **Líder absoluto:** `shadcn/ui`, `Tremor` (gráficos de analítica), `Radix UI`, `TanStack Table`. | 🟡 **Medio:** Existen ports como `shadcn-svelte`, pero menor variedad de analítica visual lista. | 🔴 **Muy escaso:** No hay kits prefabricados; requiere maquetación artesanal completa. | 🟡 **Bueno:** `PrimeVue`, `shadcn-vue`, soporte amplio de tablas. |
| **Arquitectura de API** | 🟢 **100% REST/JSON desacoplado** (conforme a Decisión 3). | 🟢 **100% REST/JSON desacoplado** (conforme a Decisión 3). | 🔴 **Acoplada:** El backend debe responder con HTML personalizado para cada vista. | 🟢 **100% REST/JSON desacoplado** (conforme a Decisión 3). |
| **Gestión de Telemetría en Tiempo Real** | 🟢 **Excelente:** `TanStack Query` maneja polling, WebSockets y sincronización de caché en cliente. | 🟢 **Excelente:** Runes nativos (`$state`) se sincronizan con WebSockets de forma trivial. | 🔴 **Torpe:** Requiere extensiones de SSE para HTMX y parcheado fragmentario de etiquetas HTML. | 🟢 **Muy buena:** Composition API reactiva nativa. |
| **Facilidad de Embeber en Binario Go** | 🟢 Ficheros estáticos en `dist/` vía `//go:embed`. | 🟢 Ficheros estáticos en `dist/` vía `//go:embed` (con menor impacto en bytes en el binario). | 🟢 Plantillas embebidas nativamente en Go. | 🟢 Ficheros estáticos en `dist/` vía `//go:embed`. |
| **Velocidad de Instalación y Build con Bun** | 🟢 $\sim 2.8\text{ s}$ en CI (`bun install` + build). | 🟢 **$\sim 1.9\text{ s}$ en CI** (`bun install` + build). | 🟢 Inmediata (sin paso de build de Node). | 🟢 $\sim 2.5\text{ s}$ en CI (`bun install` + build). |
| **Curva de Aprendizaje y Mantenibilidad** | 🟢 Familiar para la inmensa mayoría de ingenieros frontend. | 🟢 Sintaxis muy intuitiva y concisa (menos boilerplate que React). | 🟡 Fácil al inicio, pero compleja de escalar con interacciones ricas. | 🟢 Fácil y progresiva. |

---

### 4.5. Estrategia de Entrega y Empaquetado: "Dual Distribution"

Independientemente del framework reactivo elegido, la UI se empaqueta bajo una estrategia de doble modalidad:

1. **Modo Embebido (Por defecto / Zero-Config):**
   * En el `Makefile` del proyecto:
     ```makefile
     build:
     	cd web && bun install && bun run build
     	go build -ldflags="-s -w" -o bin/kinara ./cmd/kinara
     ```
   * El binario resultante contiene en su sección de datos los archivos de la UI. Cuando un usuario accede a `http://localhost:8080/`, el router en Go sirve los archivos estáticos con encabezados de caché `Cache-Control: public, max-age=31536000` y resuelve las rutas SPA devolviendo `index.html` ante peticiones no reconocidas.
2. **Modo Desacoplado (Clústeres Kubernetes de Alto Tráfico):**
   * La UI se construye como una imagen Docker basada en `nginx:alpine` de solo $15\text{ MB}$.
   * El tráfico de la UI se gestiona en el Ingress de Kubernetes, enrutando `/api/` y `/v2/` hacia los pods de `kinara-core` y la raíz `/` hacia el pod de Nginx o un bucket S3/Cloudflare Pages.

---

### 4.6. Veredicto y Recomendaciones Definitivas para la UI

A partir de la investigación exhaustiva, se formulan **dos escenarios de recomendación claros**:

#### Escenario 1: Elección Primaria (Enfoque Empresarial y Rápido Time-to-Market)
> **Stack: React 19 + TypeScript + Vite + Tailwind CSS + shadcn/ui + Tremor (Gestionado con Bun)**
> 
> * **Por qué:** Kinara Registry necesita un dashboard que transmita confianza y madurez técnica similar a GitHub Packages o Harbor. La disponibilidad de `shadcn/ui` y librerías de visualización de métricas de infraestructura como `Tremor` permite construir en días tablas de auditoría virtualizadas, exploradores de capas Docker y gráficos de deduplicación con acabado profesional.
> * **El rol de Bun:** Se utiliza **Bun** como gestor de paquetes exclusivo (`bun install`) y ejecutor de scripts en el monorepo, reduciendo los tiempos de CI/CD a segundos.

#### Escenario 2: Elección Alternativa (Enfoque Hiper-Ligero y Minimalismo en Binario)
> **Stack: Svelte 5 (Runes) + TypeScript + Vite + Tailwind CSS + shadcn-svelte (Gestionado con Bun)**
> 
> * **Por qué:** Si el equipo de ingeniería prioriza que el tamaño del binario compilado de Go sea lo más pequeño humanamente posible (por ejemplo, para despliegues en dispositivos *edge* o entornos con almacenamiento muy restringido), Svelte 5 genera un bundle de apenas $30 - 40\text{ KB}$ sin sacrificar reactividad moderna ni desacoplamiento de API.


---

## 5. Herramienta de Línea de Comandos: Kinara CLI (`kinara`)

Para elevar la experiencia de desarrollo al nivel de herramientas modernas como `gh` (GitHub CLI) o `flyctl`:

* **Nombre de la Aplicación:** `kinara` (CLI independiente).
* **Lenguaje:** **Go** (aprovechando los frameworks `spf13/cobra` y `spf13/viper`).
* **Interfaz de Usuario de Terminal (TUI):** Utilización de `charmbracelet/bubbletea` y `lipgloss` para tablas, barras de progreso y asistentes interactivos visualmente atractivos.
* **Comandos Principales:**
  * `kinara login https://registry.empresa.com`: Autentica al desarrollador y guarda credenciales seguras en el almacén del sistema operativo (`keyring`).
  * `kinara setup [pypi|docker|cargo|nuget|go]`: Detecta el proyecto local e inyecta la configuración del proxy/repositorio sin edición manual.
  * `kinara repo list / create / delete`: Gestión de repositorios desde la consola.
  * `kinara admin gc trigger`: Permite a los administradores forzar o consultar el estado del recolector de basura.
  * `kinara admin stats`: Muestra estadísticas en tiempo real de deduplicación y ahorro en disco.

---

## 6. Matriz de Decisión Final y Arquitectura de Repositorio

### 6.1. Cuadro Resumen de Aplicaciones y Tecnologías

| Aplicación | Tipo / Rol | Lenguaje | Framework / Librerías Clave | Despliegue en Modo Simple | Despliegue en Modo Cloud-Native |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`kinara-core`** | Backend API & Control Plane | **Go (Golang)** | `chi` / `fiber`, `pgx`, `modernc.org/sqlite`, `opencontainers/image-spec` | Embebido en binario unificado | `Deployment` de K8s con escalado horizontal (HPA) |
| **`kinara-data`** | Data Plane & Motor CAS | **Go (Golang)** | `FastCDC`, `io.Pipe`, `aws-sdk-go-v2`, `klauspost/compress` (zstd) | Embebido en binario unificado | `Deployment` de K8s con afinidad de red y NVMe Hot Tier |
| **`kinara-worker`** | Daemon Asíncrono de Mantenimiento | **Go (Golang)** | Motor de colas interno, GDSF Min-Heap, Mark-and-Sweep GC | Embebido en goroutine de fondo | `Deployment` independiente (1 réplica) o `CronJob` de K8s |
| **`kinara-ui`** | Dashboard Web SPA | **TypeScript** | `React 19` (o `Svelte 5`), `Vite` impulsado por `Bun`, `Tailwind CSS`, `shadcn/ui`, `TanStack Query` | Embebido vía `//go:embed` en el binario Go | Pod Nginx independiente o servidor de estáticos |
| **`kinara-cli`** | Herramienta CLI de Desarrollador | **Go (Golang)** | `cobra`, `viper`, `bubbletea`, `lipgloss` | Binario descargable | Binario distribuido vía Homebrew, Scoop, Go install o AUR |

---

### 6.2. Estructura de Repositorio Recomendada: Monorepo

Para evitar la sobrecarga de sincronización de contratos API entre repositorios separados, se recomienda una estructura **Monorepo**:

```text
kinara/
├── cmd/
│   ├── kinara/             # Punto de entrada unificado (servidor multi-rol y CLI admin)
│   └── kinara-cli/         # CLI independiente para clientes finales
├── internal/
│   ├── controlplane/       # Enrutamiento, Auth, ACL, Resolutores de Repositorios
│   ├── dataplane/          # Streaming Cut-Through, FastCDC, CAS Storage Backend
│   ├── worker/             # GC Mark & Sweep, Evicción GDSF, Indexadores
│   ├── adapters/           # Adaptadores por ecosistema (OCI, PyPI, Cargo, Go, NuGet)
│   └── database/           # Capa de datos dual (PostgreSQL / SQLite) y migraciones
├── web/                    # Código fuente del Frontend SPA (React/Svelte + TypeScript + Vite)
│   ├── src/
│   ├── package.json
│   ├── bun.lockb           # Gestión ultra-rápida de dependencias con Bun
│   └── vite.config.ts
├── deploy/
│   ├── docker-compose/     # Configuración Zero-Config para desarrollo
│   └── helm/               # Chart oficial para Kubernetes
├── Makefile                # Automatización de builds (bun build + go build embed)
└── go.mod
```

---

## 7. Conclusiones y Próximos Pasos

1. **Validación de la Hipótesis del Usuario:** Mantener una separación conceptual entre Frontend y Backend es correcta y necesaria. Sin embargo, para evitar los cuellos de botella inherentes al streaming de gigabytes frente a metadatos ligeros, el Backend debe concebirse internamente como un sistema desacoplado (Control Plane, Data Plane y Workers), aunque empaquetado en un único binario para facilitar el despliegue.
2. **Selección del Stack Tecnológico:** 
   * **Backend, Streaming y CLI:** **Go (Golang)**, por ser el estándar de la industria OCI, su bajo consumo de memoria y sus primitivas nativas de streaming.
   * **Frontend y Reactividad:** **SPA en cliente con React 19 + shadcn/ui** (para máxima riqueza y velocidad de entrega) o **Svelte 5** (si se prioriza minimizar al máximo los bytes embebidos en el binario Go). Una web puramente estática o server-side con HTMX queda descartada por las exigencias de telemetría en tiempo real y asistentes dinámicos.
   * **Cadena de Herramientas UI:** Adopción de **Bun** en tiempo de desarrollo y CI/CD para instalaciones ultrarrápidas (`bun install` en ~2s) y ejecución nativa de scripts TypeScript, manteniendo **cero dependencias de Node/Bun en el servidor de producción** gracias a `//go:embed`.
3. **Impacto en el Roadmap:** Esta arquitectura permite que la **Fase 1 del Roadmap** arranque con un solo comando sin lidiar con orquestaciones complejas de microservicios, dejando las puertas abiertas para desacoplar el Data Plane y los Workers en la **Fase 4** sin tener que reescribir una sola línea de código.

