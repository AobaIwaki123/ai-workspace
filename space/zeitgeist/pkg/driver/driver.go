package driver

import (
	"context"
	"fmt"
	"sync"

	"github.com/AobaIwaki123/zeitgeist/pkg/model"
)

// Driver defines the interface for fetching items from a specific source endpoint.
type Driver interface {
	Fetch(ctx context.Context, src model.Source) ([]model.Item, error)
}

// Registry maintains the registered drivers by their driver key.
type Registry struct {
	mu      sync.RWMutex
	drivers map[string]Driver
}

// NewRegistry creates an initialized Registry.
func NewRegistry() *Registry {
	return &Registry{
		drivers: make(map[string]Driver),
	}
}

// Register registers a driver under a specific key name.
func (r *Registry) Register(name string, d Driver) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.drivers[name] = d
}

// Get retrieves a driver by key name.
func (r *Registry) Get(name string) (Driver, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	d, ok := r.drivers[name]
	if !ok {
		return nil, fmt.Errorf("driver %q not registered", name)
	}
	return d, nil
}
