package goadapter

// Adapter implementa Go Module Proxy Protocol (@v/list, .info, .mod, .zip)
type Adapter struct{}

func NewAdapter() *Adapter {
	return &Adapter{}
}
