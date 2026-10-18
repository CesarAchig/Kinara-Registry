package config

import (
	"os"
	"strconv"
)

// Config almacena la configuración global del sistema
type Config struct {
	Port         int
	Env          string
	DatabaseDSN  string
	S3Endpoint   string
	S3Bucket     string
	S3AccessKey  string
	S3SecretKey  string
	S3Region     string
	StoragePath  string
	LogLevel     string
}

// Load carga la configuración a partir de variables de entorno con valores por defecto
func Load() *Config {
	port, _ := strconv.Atoi(getEnv("KINARA_PORT", "8080"))

	return &Config{
		Port:        port,
		Env:         getEnv("KINARA_ENV", "development"),
		DatabaseDSN: getEnv("KINARA_DB_DSN", "postgres://postgres:postgres@localhost:5432/kinara_dev?sslmode=disable"),
		S3Endpoint:  getEnv("KINARA_S3_ENDPOINT", "http://localhost:3900"),
		S3Bucket:    getEnv("KINARA_S3_BUCKET", "kinara-cas"),
		S3AccessKey: getEnv("KINARA_S3_ACCESS_KEY", "GKkinaradev0000000000000000"),
		S3SecretKey: getEnv("KINARA_S3_SECRET_KEY", "7d37d093435a41f2aab8f13c19ba067d9776c90215f56614adad6ece597dbb34"),
		S3Region:    getEnv("KINARA_S3_REGION", "garage"),
		StoragePath: getEnv("KINARA_STORAGE_PATH", "/tmp/kinara-cas"),
		LogLevel:    getEnv("KINARA_LOG_LEVEL", "info"),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
