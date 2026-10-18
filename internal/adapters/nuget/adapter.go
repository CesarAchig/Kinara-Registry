package nuget

// Adapter implementa NuGet Server API v3 (Service Index, Registration, Package Content)
type Adapter struct{}

func NewAdapter() *Adapter {
	return &Adapter{}
}
