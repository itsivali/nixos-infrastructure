package logger

import (
	"io"
	"os"
	"time"

	"github.com/rs/zerolog"
)

type Level int

const (
	Trace Level = iota - 1
	Debug
	Info
	Warn
	Error
	Fatal
)

type Logger struct {
	inner zerolog.Logger
	level Level
}

func New(level Level) *Logger {
	output := zerolog.ConsoleWriter{
		Out:        os.Stderr,
		TimeFormat: time.RFC3339,
		NoColor:    false,
	}

	zlevel := zerolog.InfoLevel
	switch level {
	case Trace:
		zlevel = zerolog.TraceLevel
	case Debug:
		zlevel = zerolog.DebugLevel
	case Warn:
		zlevel = zerolog.WarnLevel
	case Error:
		zlevel = zerolog.ErrorLevel
	case Fatal:
		zlevel = zerolog.FatalLevel
	}

	inner := zerolog.New(output).Level(zlevel).With().Timestamp().Logger()

	return &Logger{inner: inner, level: level}
}

func NewJSON(w io.Writer, level Level) *Logger {
	zlevel := zerolog.InfoLevel
	switch level {
	case Trace:
		zlevel = zerolog.TraceLevel
	case Debug:
		zlevel = zerolog.DebugLevel
	case Warn:
		zlevel = zerolog.WarnLevel
	case Error:
		zlevel = zerolog.ErrorLevel
	case Fatal:
		zlevel = zerolog.FatalLevel
	}

	inner := zerolog.New(w).Level(zlevel).With().Timestamp().Logger()
	return &Logger{inner: inner, level: level}
}

func (l *Logger) Trace() *zerolog.Event { return l.inner.Trace() }
func (l *Logger) Debug() *zerolog.Event { return l.inner.Debug() }
func (l *Logger) Info() *zerolog.Event  { return l.inner.Info() }
func (l *Logger) Warn() *zerolog.Event  { return l.inner.Warn() }
func (l *Logger) Error() *zerolog.Event { return l.inner.Error() }
func (l *Logger) Fatal() *zerolog.Event { return l.inner.Fatal() }

func (l *Logger) Level() Level { return l.level }
