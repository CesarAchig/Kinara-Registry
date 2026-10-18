import {
  Activity,
  HardDrive,
  Layers,
  Package,
  ShieldCheck,
  Terminal,
} from "lucide-react";
import { useState } from "react";

export function App() {
  const [activeTab, setActiveTab] = useState<
    "dashboard" | "repositories" | "setmeup"
  >("dashboard");

  return (
    <div className="flex h-screen bg-slate-950 text-slate-100 font-sans">
      {/* Sidebar */}
      <aside className="w-64 border-r border-slate-800 bg-slate-900/50 p-6 flex flex-col justify-between">
        <div className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-xl bg-linear-to-tr from-cyan-500 to-blue-600 flex items-center justify-center font-bold text-white shadow-lg shadow-cyan-500/20">
              K
            </div>
            <div>
              <h1 className="font-semibold text-base leading-none">
                Kinara Registry
              </h1>
              <span className="text-xs text-slate-400">
                Universal Artifacts
              </span>
            </div>
          </div>

          <nav className="space-y-1">
            <button
              onClick={() => setActiveTab("dashboard")}
              className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                activeTab === "dashboard"
                  ? "bg-cyan-500/10 text-cyan-400"
                  : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
              }`}
            >
              <Activity className="h-4 w-4" />
              Telemetría y Estado
            </button>
            <button
              onClick={() => setActiveTab("repositories")}
              className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                activeTab === "repositories"
                  ? "bg-cyan-500/10 text-cyan-400"
                  : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
              }`}
            >
              <Package className="h-4 w-4" />
              Repositorios
            </button>
            <button
              onClick={() => setActiveTab("setmeup")}
              className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                activeTab === "setmeup"
                  ? "bg-cyan-500/10 text-cyan-400"
                  : "text-slate-400 hover:text-slate-200 hover:bg-slate-800/50"
              }`}
            >
              <Terminal className="h-4 w-4" />
              Asistente "Set Me Up"
            </button>
          </nav>
        </div>

        <div className="pt-6 border-t border-slate-800/60 text-xs text-slate-500 flex items-center justify-between">
          <span>v0.1.0-dev</span>
          <span className="inline-flex items-center gap-1 text-emerald-400">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400"></span>
            Online
          </span>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto p-8">
        <header className="mb-8 flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">
              Panel de Control
            </h2>
            <p className="text-sm text-slate-400 mt-1">
              Supervisión de almacenamiento CAS, deduplicación FastCDC y estado
              de repositorios.
            </p>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-xs bg-slate-800 px-3 py-1.5 rounded-full text-slate-300 font-mono">
              Backend: Go 1.27
            </span>
            <span className="text-xs bg-cyan-950 text-cyan-400 border border-cyan-800/50 px-3 py-1.5 rounded-full font-mono">
              Tooling: Bun
            </span>
          </div>
        </header>

        {/* Telemetry Metric Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-sm">
            <div className="flex items-center justify-between text-slate-400 mb-3">
              <span className="text-xs font-semibold uppercase tracking-wider">
                Ahorro Deduplicación
              </span>
              <HardDrive className="h-4 w-4 text-cyan-400" />
            </div>
            <div className="text-3xl font-extrabold text-slate-50">75.0%</div>
            <p className="text-xs text-slate-400 mt-2">
              Ratio CAS 4.0x con particionamiento FastCDC
            </p>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-sm">
            <div className="flex items-center justify-between text-slate-400 mb-3">
              <span className="text-xs font-semibold uppercase tracking-wider">
                Tasa de Acierto Caché
              </span>
              <Layers className="h-4 w-4 text-emerald-400" />
            </div>
            <div className="text-3xl font-extrabold text-slate-50">94.8%</div>
            <p className="text-xs text-slate-400 mt-2">
              Evicción inteligente con algoritmo GDSF
            </p>
          </div>

          <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800/80 shadow-sm">
            <div className="flex items-center justify-between text-slate-400 mb-3">
              <span className="text-xs font-semibold uppercase tracking-wider">
                Dependency Confusion
              </span>
              <ShieldCheck className="h-4 w-4 text-indigo-400" />
            </div>
            <div className="text-3xl font-extrabold text-slate-50">
              Blindado
            </div>
            <p className="text-xs text-slate-400 mt-2">
              Aislamiento Local-First activo en repositorios virtuales
            </p>
          </div>
        </div>

        {/* Status Callout */}
        <div className="p-6 rounded-2xl bg-linear-to-r from-slate-900 to-slate-900/40 border border-slate-800">
          <h3 className="text-base font-semibold text-slate-100 flex items-center gap-2">
            <span>🚀</span> Entorno de Desarrollo Inicializado
          </h3>
          <p className="text-sm text-slate-400 mt-2 leading-relaxed">
            El entorno de desarrollo está completamente preparado con soporte
            para el backend unificado en Go, base de datos relacional PostgreSQL
            efímera, almacenamiento S3 en Garage y la interfaz de usuario en
            React 19 administrada con Bun.
          </p>
        </div>
      </main>
    </div>
  );
}
export default App;
