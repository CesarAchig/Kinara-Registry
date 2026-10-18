package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	mode := flag.String("mode", "all", "Modo de ejecución: all | api | storage | worker")
	port := flag.Int("port", 8080, "Puerto HTTP del servidor")
	flag.Parse()

	fmt.Printf("🚀 Iniciando Kinara Registry en modo [%s] sobre el puerto %d...\n", *mode, *port)

	switch *mode {
	case "all":
		fmt.Println("ℹ️  Ejecutando Control Plane, Data Plane y Workers en modo unificado (Zero-Config).")
	case "api":
		fmt.Println("ℹ️  Ejecutando exclusivamente Control Plane & API Gateway.")
	case "storage":
		fmt.Println("ℹ️  Ejecutando exclusivamente Data Plane & Motor CAS.")
	case "worker":
		fmt.Println("ℹ️  Ejecutando exclusivamente Daemon de Tareas en Segundo Plano (GC & Evicción).")
	default:
		fmt.Fprintf(os.Stderr, "❌ Modo desconocido: %s (opciones válidas: all, api, storage, worker)\n", *mode)
		os.Exit(1)
	}
}
