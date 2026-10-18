package database

// DB representa la abstracción de persistencia relacional (PostgreSQL / SQLite)
type DB struct {
	// Driver connection pool
}

// NewConnection inicializa la conexión con la base de datos configurada
func NewConnection(dsn string) (*DB, error) {
	return &DB{}, nil
}
