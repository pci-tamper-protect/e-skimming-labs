// Package traefikcloudrunprovider provides the root-level plugin wrapper for Traefik v3.0
// This file re-exports the plugin functions from the plugin package
// Traefik v3.0 expects plugin functions to be in the module root
package traefikcloudrunprovider

import (
	"context"

	"github.com/pci-tamper-protect/traefik-cloudrun-provider/plugin"
)

// Config re-exports the plugin.Config type
type Config = plugin.Config

// CreateConfig re-exports the plugin.CreateConfig function
// This is called by Traefik when it discovers the plugin
func CreateConfig() *Config {
	return plugin.CreateConfig()
}

// New re-exports the plugin.New function
// This is called by Traefik to create a new plugin instance
func New(ctx context.Context, config *Config, name string) (*plugin.PluginProvider, error) {
	return plugin.New(ctx, config, name)
}
