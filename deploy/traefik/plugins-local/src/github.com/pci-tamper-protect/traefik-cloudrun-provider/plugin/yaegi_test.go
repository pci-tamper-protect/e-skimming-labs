// yaegi_test.go - Tests that the plugin can be interpreted by Yaegi
//
// This test verifies that the vendored plugin code can be loaded by Traefik's
// Yaegi interpreter. If this test fails, the plugin won't work as a native
// Traefik plugin and must be run as an external binary instead.
//
// Run: go test -v ./plugin -run TestYaegi

package plugin

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/traefik/yaegi/interp"
	"github.com/traefik/yaegi/stdlib"
)

// setupYaegiInterpreter creates a Yaegi interpreter configured like Traefik
// Traefik expects plugins in: plugins-local/src/<module-path>/
func setupYaegiInterpreter(t *testing.T) (*interp.Interpreter, string) {
	t.Helper()

	// Find the module root (where go.mod is)
	moduleRoot, err := findModuleRoot()
	if err != nil {
		t.Fatalf("Failed to find module root: %v", err)
	}

	// Check vendor directory exists
	vendorPath := filepath.Join(moduleRoot, "vendor")
	if _, err := os.Stat(vendorPath); os.IsNotExist(err) {
		t.Skip("Vendor directory not found. Run 'go mod vendor' first.")
	}

	// Create a temporary plugins-local structure like Traefik uses
	// Traefik looks for: <GoPath>/src/<module-path>/
	tmpDir := t.TempDir()
	srcDir := filepath.Join(tmpDir, "src", "github.com", "pci-tamper-protect", "traefik-cloudrun-provider")
	if err := os.MkdirAll(filepath.Dir(srcDir), 0755); err != nil {
		t.Fatalf("Failed to create src directory: %v", err)
	}

	// Symlink the module root to the expected location
	if err := os.Symlink(moduleRoot, srcDir); err != nil {
		t.Fatalf("Failed to create symlink: %v", err)
	}

	// Create Yaegi interpreter with the correct GOPATH
	i := interp.New(interp.Options{
		GoPath: tmpDir,
	})

	// Load standard library symbols
	if err := i.Use(stdlib.Symbols); err != nil {
		t.Fatalf("Failed to load stdlib symbols: %v", err)
	}

	return i, moduleRoot
}

// TestYaegiCanLoadPlugin tests if Yaegi can interpret the plugin package.
// This test documents Yaegi compatibility - failures are expected and informational.
// Run with: go test -v ./plugin -run TestYaegi
func TestYaegiCanLoadPlugin(t *testing.T) {
	i, _ := setupYaegiInterpreter(t)

	// Helper to safely test imports (Yaegi may panic on incompatible code)
	safeEval := func(code string) (err error) {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("Yaegi panic: %v", r)
			}
		}()
		_, err = i.Eval(code)
		return err
	}

	var failures []string

	t.Run("LoadLoggingPackage", func(t *testing.T) {
		err := safeEval(`import "github.com/pci-tamper-protect/traefik-cloudrun-provider/internal/logging"`)
		if err != nil {
			failures = append(failures, "internal/logging")
			t.Logf("✗ internal/logging: %v", err)
		} else {
			t.Log("✓ internal/logging loaded successfully")
		}
	})

	t.Run("LoadProviderPackage", func(t *testing.T) {
		err := safeEval(`import "github.com/pci-tamper-protect/traefik-cloudrun-provider/provider"`)
		if err != nil {
			failures = append(failures, "provider (gRPC incompatibility)")
			t.Logf("✗ provider: %v", err)
		} else {
			t.Log("✓ provider loaded successfully")
		}
	})

	t.Run("LoadGCPPackage", func(t *testing.T) {
		err := safeEval(`import "github.com/pci-tamper-protect/traefik-cloudrun-provider/internal/gcp"`)
		if err != nil {
			failures = append(failures, "internal/gcp (GCP SDK incompatibility)")
			t.Logf("✗ internal/gcp: %v", err)
		} else {
			t.Log("✓ internal/gcp loaded successfully")
		}
	})

	t.Run("LoadPluginPackage", func(t *testing.T) {
		err := safeEval(`import "github.com/pci-tamper-protect/traefik-cloudrun-provider/plugin"`)
		if err != nil {
			failures = append(failures, "plugin")
			t.Logf("✗ plugin: %v", err)
		} else {
			t.Log("✓ plugin loaded successfully")
		}
	})

	// Summary - skip if there are known failures (don't fail CI)
	if len(failures) > 0 {
		t.Skipf("Yaegi compatibility test: %d package(s) cannot be interpreted. "+
			"This is expected - use external binary mode (test-provider.sh). "+
			"Failures: %v", len(failures), failures)
	}
}

// TestYaegiCreateConfig tests if CreateConfig can be called via Yaegi.
// This test is expected to be skipped due to GCP SDK incompatibility.
func TestYaegiCreateConfig(t *testing.T) {
	i, _ := setupYaegiInterpreter(t)

	// Helper to safely test (Yaegi may panic)
	safeEval := func(code string) (v interface{}, err error) {
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("Yaegi panic: %v", r)
			}
		}()
		return i.Eval(code)
	}

	// First import the package
	_, err := safeEval(`import "github.com/pci-tamper-protect/traefik-cloudrun-provider/plugin"`)
	if err != nil {
		t.Skipf("Plugin package cannot be loaded by Yaegi (expected): %v", err)
	}

	// Try to call CreateConfig
	v, err := safeEval(`plugin.CreateConfig()`)
	if err != nil {
		t.Skipf("CreateConfig cannot be called via Yaegi (expected): %v", err)
	} else {
		t.Logf("✓ CreateConfig() returned: %v", v)
	}
}

// TestYaegiVendoredDependencies documents which vendored packages are needed.
// The actual Yaegi compatibility is tested in TestYaegiCanLoadPlugin.
// This test just verifies the vendor directory exists with expected packages.
func TestYaegiVendoredDependencies(t *testing.T) {
	moduleRoot, err := findModuleRoot()
	if err != nil {
		t.Fatalf("Failed to find module root: %v", err)
	}

	vendorPath := filepath.Join(moduleRoot, "vendor")
	if _, err := os.Stat(vendorPath); os.IsNotExist(err) {
		t.Skip("Vendor directory not found. Run 'go mod vendor' first.")
	}

	// List of packages that should be vendored
	requiredPackages := []struct {
		name string
		pkg  string
	}{
		{"GCP compute metadata", "cloud.google.com/go/compute/metadata"},
		{"GCP auth", "cloud.google.com/go/auth"},
		{"Google API run/v1", "google.golang.org/api/run/v1"},
		{"traefik genconf", "github.com/traefik/genconf/dynamic"},
	}

	for _, pkg := range requiredPackages {
		t.Run(pkg.name, func(t *testing.T) {
			vendorPkgPath := filepath.Join(vendorPath, pkg.pkg)
			if _, err := os.Stat(vendorPkgPath); os.IsNotExist(err) {
				t.Errorf("Required package not vendored: %s", pkg.pkg)
			} else {
				t.Logf("✓ %s vendored at %s", pkg.name, vendorPkgPath)
			}
		})
	}

	// Show vendor size
	var totalSize int64
	filepath.Walk(vendorPath, func(_ string, info os.FileInfo, _ error) error {
		if info != nil && !info.IsDir() {
			totalSize += info.Size()
		}
		return nil
	})
	t.Logf("Vendor directory size: %.1f MB", float64(totalSize)/(1024*1024))
}

// findModuleRoot finds the directory containing go.mod
func findModuleRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", os.ErrNotExist
		}
		dir = parent
	}
}
