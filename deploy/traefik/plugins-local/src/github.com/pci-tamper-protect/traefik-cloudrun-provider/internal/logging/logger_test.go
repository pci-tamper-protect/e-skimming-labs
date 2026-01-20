package logging

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func TestLogger_TextFormat(t *testing.T) {
	var buf bytes.Buffer

	logger := New(&Config{
		Level:  LevelInfo,
		Format: FormatText,
		Output: &buf,
	}).WithPrefix("TestComponent")

	logger.Info("test message",
		String("key1", "value1"),
		Int("count", 42),
	)

	output := buf.String()

	// Check for expected components
	if !strings.Contains(output, "[INFO]") {
		t.Errorf("Expected [INFO] in output, got: %s", output)
	}
	if !strings.Contains(output, "TestComponent:") {
		t.Errorf("Expected TestComponent: in output, got: %s", output)
	}
	if !strings.Contains(output, "test message") {
		t.Errorf("Expected 'test message' in output, got: %s", output)
	}
	if !strings.Contains(output, "key1=value1") {
		t.Errorf("Expected key1=value1 in output, got: %s", output)
	}
	if !strings.Contains(output, "count=42") {
		t.Errorf("Expected count=42 in output, got: %s", output)
	}
}

func TestLogger_JSONFormat(t *testing.T) {
	var buf bytes.Buffer

	logger := New(&Config{
		Level:  LevelInfo,
		Format: FormatJSON,
		Output: &buf,
	}).WithPrefix("TestComponent")

	logger.Info("test message",
		String("key1", "value1"),
		Int("count", 42),
	)

	output := buf.String()

	// Check for expected JSON components
	if !strings.Contains(output, `"level":"INFO"`) {
		t.Errorf("Expected level:INFO in JSON output, got: %s", output)
	}
	if !strings.Contains(output, `"component":"TestComponent"`) {
		t.Errorf("Expected component field in JSON output, got: %s", output)
	}
	if !strings.Contains(output, `"message":"test message"`) {
		t.Errorf("Expected message field in JSON output, got: %s", output)
	}
	if !strings.Contains(output, `"key1":"value1"`) {
		t.Errorf("Expected key1 field in JSON output, got: %s", output)
	}
	if !strings.Contains(output, `"count":"42"`) {
		t.Errorf("Expected count field in JSON output, got: %s", output)
	}
}

func TestLogger_LogLevels(t *testing.T) {
	tests := []struct {
		name          string
		level         Level
		logFunc       func(*Logger, string)
		shouldLog     bool
		expectedLevel string
	}{
		{"Debug at Info level", LevelInfo, func(l *Logger, msg string) { l.Debug(msg) }, false, ""},
		{"Info at Info level", LevelInfo, func(l *Logger, msg string) { l.Info(msg) }, true, "INFO"},
		{"Warn at Info level", LevelInfo, func(l *Logger, msg string) { l.Warn(msg) }, true, "WARN"},
		{"Error at Info level", LevelInfo, func(l *Logger, msg string) { l.Error(msg) }, true, "ERROR"},
		{"Debug at Debug level", LevelDebug, func(l *Logger, msg string) { l.Debug(msg) }, true, "DEBUG"},
		{"Info at Error level", LevelError, func(l *Logger, msg string) { l.Info(msg) }, false, ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var buf bytes.Buffer
			logger := New(&Config{
				Level:  tt.level,
				Format: FormatText,
				Output: &buf,
			})

			tt.logFunc(logger, "test message")

			output := buf.String()
			if tt.shouldLog {
				if output == "" {
					t.Errorf("Expected log output, got empty string")
				}
				if !strings.Contains(output, tt.expectedLevel) {
					t.Errorf("Expected level %s in output, got: %s", tt.expectedLevel, output)
				}
			} else {
				if output != "" {
					t.Errorf("Expected no output, got: %s", output)
				}
			}
		})
	}
}

func TestLogger_FormattedLogging(t *testing.T) {
	var buf bytes.Buffer
	logger := New(&Config{
		Level:  LevelInfo,
		Format: FormatText,
		Output: &buf,
	})

	logger.Infof("formatted %s with %d", "message", 123)

	output := buf.String()
	if !strings.Contains(output, "formatted message with 123") {
		t.Errorf("Expected formatted message in output, got: %s", output)
	}
}

func TestLogger_Fields(t *testing.T) {
	var buf bytes.Buffer
	logger := New(&Config{
		Level:  LevelInfo,
		Format: FormatText,
		Output: &buf,
	})

	logger.Info("test",
		String("str", "value"),
		Int("int", 42),
		Duration("dur", 5*time.Second),
		Any("any", []string{"a", "b"}),
	)

	output := buf.String()

	if !strings.Contains(output, "str=value") {
		t.Errorf("Expected str field in output, got: %s", output)
	}
	if !strings.Contains(output, "int=42") {
		t.Errorf("Expected int field in output, got: %s", output)
	}
	if !strings.Contains(output, "dur=5s") {
		t.Errorf("Expected dur field in output, got: %s", output)
	}
	if !strings.Contains(output, "any=[a b]") {
		t.Errorf("Expected any field in output, got: %s", output)
	}
}

func TestLogger_ErrorField(t *testing.T) {
	var buf bytes.Buffer
	logger := New(&Config{
		Level:  LevelInfo,
		Format: FormatText,
		Output: &buf,
	})

	logger.Error("test error", Error(nil))
	output1 := buf.String()
	if !strings.Contains(output1, "error=nil") {
		t.Errorf("Expected error=nil for nil error, got: %s", output1)
	}

	buf.Reset()
	testErr := &testError{"test error message"}
	logger.Error("test error", Error(testErr))
	output2 := buf.String()
	if !strings.Contains(output2, "error=test error message") {
		t.Errorf("Expected error message in output, got: %s", output2)
	}
}

func TestLogger_JSONEscaping(t *testing.T) {
	var buf bytes.Buffer
	logger := New(&Config{
		Level:  LevelInfo,
		Format: FormatJSON,
		Output: &buf,
	})

	logger.Info("message with \"quotes\" and \nnewlines")

	output := buf.String()
	if !strings.Contains(output, `\"quotes\"`) {
		t.Errorf("Expected escaped quotes in output, got: %s", output)
	}
	if !strings.Contains(output, `\n`) {
		t.Errorf("Expected escaped newline in output, got: %s", output)
	}
}

func TestParseLevel(t *testing.T) {
	tests := []struct {
		input    string
		expected Level
		hasError bool
	}{
		{"DEBUG", LevelDebug, false},
		{"debug", LevelDebug, false},
		{"INFO", LevelInfo, false},
		{"info", LevelInfo, false},
		{"WARN", LevelWarn, false},
		{"WARNING", LevelWarn, false},
		{"ERROR", LevelError, false},
		{"INVALID", LevelInfo, true},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			level, err := ParseLevel(tt.input)
			if tt.hasError {
				if err == nil {
					t.Errorf("Expected error for input %s", tt.input)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error for input %s: %v", tt.input, err)
				}
				if level != tt.expected {
					t.Errorf("Expected level %v for input %s, got %v", tt.expected, tt.input, level)
				}
			}
		})
	}
}

func TestParseFormat(t *testing.T) {
	tests := []struct {
		input    string
		expected Format
		hasError bool
	}{
		{"text", FormatText, false},
		{"TEXT", FormatText, false},
		{"json", FormatJSON, false},
		{"JSON", FormatJSON, false},
		{"", FormatText, false},
		{"invalid", FormatText, true},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			format, err := ParseFormat(tt.input)
			if tt.hasError {
				if err == nil {
					t.Errorf("Expected error for input %s", tt.input)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error for input %s: %v", tt.input, err)
				}
				if format != tt.expected {
					t.Errorf("Expected format %v for input %s, got %v", tt.expected, tt.input, format)
				}
			}
		})
	}
}

// testError is a simple error implementation for testing
type testError struct {
	msg string
}

func (e *testError) Error() string {
	return e.msg
}
