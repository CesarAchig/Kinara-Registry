package main

import (
	"fmt"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		printHelp()
		return
	}

	command := os.Args[1]
	switch command {
	case "login":
		fmt.Println("🔑 Autenticando desarrollador con Kinara Registry...")
	case "setup":
		fmt.Println("⚙️  Generando configuración de desarrollo (Set Me Up)...")
	case "repo":
		fmt.Println("📦 Gestión de repositorios locales, remotos y virtuales...")
	case "admin":
		fmt.Println("🛡️  Operaciones administrativas (GC trigger, stats, telemetría)...")
	case "version":
		fmt.Println("Kinara CLI v0.1.0-dev")
	default:
		fmt.Printf("Comando desconocido: %s\n\n", command)
		printHelp()
	}
}

func printHelp() {
	fmt.Println("Kinara CLI — Herramienta de línea de comandos para desarrolladores y DevOps")
	fmt.Println("\nUso:")
	fmt.Println("  kinara [comando] [argumentos]")
	fmt.Println("\nComandos disponibles:")
	fmt.Println("  login       Inicia sesión en una instancia de Kinara y almacena credenciales")
	fmt.Println("  setup       Configura automáticamente gestores de dependencias (npm, pip, cargo, docker, go)")
	fmt.Println("  repo        Administra repositorios (list, create, delete)")
	fmt.Println("  admin       Tareas de administración (trigger GC, estadísticas de deduplicación)")
	fmt.Println("  version     Muestra la versión de la CLI")
}
