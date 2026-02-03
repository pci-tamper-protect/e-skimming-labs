package logging

import (
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"
)

// Level represents log levels
type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarn
	LevelError
)

var levelNames = map[Level]string{
	LevelDebug: "DEBUG",
	LevelInfo:  "INFO",
	LevelWarn:  "WARN",
	LevelError: "ERROR",
}

// Format represents log output formats
type Format string

const (
	FormatText Format = "text" // Human-readable text
	FormatJSON Format = "json" // JSON structured logs
)

// Config represents logger configuration
type Config struct {
	Level  Level  // Minimum log level
	Format Format // Output format
	Output io.Writer
}

// Logger provides structured logging with configurable output
type Logger struct {
	level  Level
	format Format
	output io.Writer
	prefix string
}

// New creates a new logger with the given configuration
func New(config *Config) *Logger {
	if config.Output == nil {
		config.Output = os.Stdout
	}
	return &Logger{
		level:  config.Level,
		format: config.Format,
		output: config.Output,
	}
}

// WithPrefix returns a new logger with the given prefix
func (l *Logger) WithPrefix(prefix string) *Logger {
	return &Logger{
		level:  l.level,
		format: l.format,
		output: l.output,
		prefix: prefix,
	}
}

// Debug logs a debug message
func (l *Logger) Debug(msg string, fields ...Field) {
	l.log(LevelDebug, msg, fields...)
}

// Info logs an info message
func (l *Logger) Info(msg string, fields ...Field) {
	l.log(LevelInfo, msg, fields...)
}

// Warn logs a warning message
func (l *Logger) Warn(msg string, fields ...Field) {
	l.log(LevelWarn, msg, fields...)
}

// Error logs an error message
func (l *Logger) Error(msg string, fields ...Field) {
	l.log(LevelError, msg, fields...)
}

// Debugf logs a formatted debug message
func (l *Logger) Debugf(format string, args ...interface{}) {
	l.log(LevelDebug, fmt.Sprintf(format, args...))
}

// Infof logs a formatted info message
func (l *Logger) Infof(format string, args ...interface{}) {
	l.log(LevelInfo, fmt.Sprintf(format, args...))
}

// Warnf logs a formatted warning message
func (l *Logger) Warnf(format string, args ...interface{}) {
	l.log(LevelWarn, fmt.Sprintf(format, args...))
}

// Errorf logs a formatted error message
func (l *Logger) Errorf(format string, args ...interface{}) {
	l.log(LevelError, fmt.Sprintf(format, args...))
}

// log writes a log entry
func (l *Logger) log(level Level, msg string, fields ...Field) {
	if level < l.level {
		return
	}

	timestamp := time.Now().UTC().Format(time.RFC3339)
	levelName := levelNames[level]

	if l.format == FormatJSON {
		l.logJSON(timestamp, levelName, msg, fields)
	} else {
		l.logText(timestamp, levelName, msg, fields)
	}
}

// logText writes a text-formatted log entry
func (l *Logger) logText(timestamp, level, msg string, fields []Field) {
	var parts []string

	// Build: timestamp [LEVEL] prefix: message key=value key=value
	parts = append(parts, timestamp)
	parts = append(parts, fmt.Sprintf("[%s]", level))

	if l.prefix != "" {
		parts = append(parts, l.prefix+":")
	}

	parts = append(parts, msg)

	// Add fields
	for _, f := range fields {
		parts = append(parts, fmt.Sprintf("%s=%v", f.Key, f.Value))
	}

	fmt.Fprintln(l.output, strings.Join(parts, " "))
}

// logJSON writes a JSON-formatted log entry
func (l *Logger) logJSON(timestamp, level, msg string, fields []Field) {
	// Simple JSON without external dependencies
	var parts []string

	parts = append(parts, fmt.Sprintf(`"timestamp":"%s"`, timestamp))
	parts = append(parts, fmt.Sprintf(`"level":"%s"`, level))

	if l.prefix != "" {
		parts = append(parts, fmt.Sprintf(`"component":"%s"`, l.prefix))
	}

	parts = append(parts, fmt.Sprintf(`"message":"%s"`, escapeJSON(msg)))

	// Add fields
	for _, f := range fields {
		parts = append(parts, fmt.Sprintf(`"%s":"%v"`, f.Key, f.Value))
	}

	fmt.Fprintf(l.output, "{%s}\n", strings.Join(parts, ","))
}

// Field represents a structured log field
type Field struct {
	Key   string
	Value interface{}
}

// String creates a string field
func String(key, value string) Field {
	return Field{Key: key, Value: value}
}

// Int creates an int field
func Int(key string, value int) Field {
	return Field{Key: key, Value: value}
}

// Duration creates a duration field
func Duration(key string, value time.Duration) Field {
	return Field{Key: key, Value: value}
}

// Error creates an error field
func Error(err error) Field {
	if err == nil {
		return Field{Key: "error", Value: "nil"}
	}
	return Field{Key: "error", Value: err.Error()}
}

// Any creates a field with any value
func Any(key string, value interface{}) Field {
	return Field{Key: key, Value: value}
}

// escapeJSON escapes special characters in JSON strings
func escapeJSON(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	s = strings.ReplaceAll(s, "\n", `\n`)
	s = strings.ReplaceAll(s, "\r", `\r`)
	s = strings.ReplaceAll(s, "\t", `\t`)
	return s
}

// ParseLevel parses a log level from string
func ParseLevel(s string) (Level, error) {
	switch strings.ToUpper(s) {
	case "DEBUG":
		return LevelDebug, nil
	case "INFO":
		return LevelInfo, nil
	case "WARN", "WARNING":
		return LevelWarn, nil
	case "ERROR":
		return LevelError, nil
	default:
		return LevelInfo, fmt.Errorf("unknown log level: %s", s)
	}
}

// ParseFormat parses a log format from string
func ParseFormat(s string) (Format, error) {
	switch strings.ToLower(s) {
	case "text", "":
		return FormatText, nil
	case "json":
		return FormatJSON, nil
	default:
		return FormatText, fmt.Errorf("unknown log format: %s", s)
	}
}

// SetupStdLogger configures the standard library logger to use our format
func SetupStdLogger(logger *Logger) {
	log.SetOutput(logger.output)
	log.SetFlags(0) // We handle our own formatting
}
