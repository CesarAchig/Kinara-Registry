package oci

// Adapter implementa la especificación OCI Distribution Spec v1.1+ y Docker Registry v2
type Adapter struct{}

func NewAdapter() *Adapter {
	return &Adapter{}
}
