package pypi

// Adapter implementa PEP 503 (Simple Repository API) y endpoints de subida para Wheels/sdist
type Adapter struct{}

func NewAdapter() *Adapter {
	return &Adapter{}
}
