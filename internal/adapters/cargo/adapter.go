package cargo

// Adapter implementa Cargo Sparse Registry Protocol y publicación de crates
type Adapter struct{}

func NewAdapter() *Adapter {
	return &Adapter{}
}
