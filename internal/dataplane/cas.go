package dataplane

import "io"

// CASEngine define el contrato para el almacenamiento direccionable por contenido
type CASEngine interface {
	PutBlob(reader io.Reader) (sha256 string, size int64, err error)
	GetBlob(sha256 string) (io.ReadCloser, error)
	HasBlob(sha256 string) (bool, error)
	DeleteBlob(sha256 string) error
}
