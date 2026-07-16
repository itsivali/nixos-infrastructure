package logger

import (
	"io"
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
)

type Level int

const (
	Trace Level = iota - 1
	Debug
	Verbose
	Info
	Warn
	Error
	Fatal
)

type Logger struct {
	inner  zerolog.Logger
	level  Level
	caller bool
}

type Option func(*Logger)

func WithCaller(enabled bool) Option {
	return func(l *Logger) {
		l.caller = enabled
	}
}

func WithLevel(level Level) Option {
	return func(l *Logger) {
		l.level = level
	}
}

func New(level Level, opts ...Option) *Logger {
	l := &Logger{
		level:  level,
		caller: false,
	}

	for _, opt := range opts {
		opt(l)
	}

	output := zerolog.ConsoleWriter{
		Out:        os.Stderr,
		TimeFormat: time.RFC3339,
		NoColor:    false,
		PartsOrder: []string{
			zerolog.TimestampFieldName,
			zerolog.LevelFieldName,
			zerolog.CallerFieldName,
			zerolog.MessageFieldName,
		},
	}

	output.FormatTimestamp = func(i interface{}) string {
		t, ok := i.(string)
		if !ok {
			return "???"
		}
		parsed, err := time.Parse(time.RFC3339, t)
		if err != nil {
			return t
		}
		return parsed.Format("15:04:05")
	}

	output.FormatLevel = func(i interface{}) string {
		ll, ok := i.(string)
		if !ok {
			return "?"
		}
		switch ll {
		case "trace":
			return colorize("TRC", 90)
		case "debug":
			return colorize("DBG", 36)
		case "info":
			return colorize("INF", 32)
		case "warn":
			return colorize("WRN", 33)
		case "error":
			return colorize("ERR", 31)
		case "fatal":
			return colorize("FTL", 35)
		default:
			return ll
		}
	}

	output.FormatCaller = func(i interface{}) string {
		c, ok := i.(string)
		if !ok {
			return ""
		}
		return colorize(shortCaller(c), 90)
	}

	ctx := zerolog.New(output).Level(l.zLevel()).With().Timestamp()

	if l.caller {
		ctx = ctx.Caller()
	}

	return &Logger{
		inner:  ctx.Logger(),
		level:  l.level,
		caller: l.caller,
	}
}

func NewJSON(w io.Writer, level Level) *Logger {
	ctx := zerolog.New(w).Level(zLevel(level)).With().Timestamp()
	return &Logger{
		inner: ctx.Logger(),
		level: level,
	}
}

func (l *Logger) zLevel() zerolog.Level {
	return zLevel(l.level)
}

func zLevel(level Level) zerolog.Level {
	switch level {
	case Trace:
		return zerolog.TraceLevel
	case Debug, Verbose:
		return zerolog.DebugLevel
	case Warn:
		return zerolog.WarnLevel
	case Error:
		return zerolog.ErrorLevel
	case Fatal:
		return zerolog.FatalLevel
	default:
		return zerolog.InfoLevel
	}
}

func (l *Logger) Trace() *zerolog.Event { return l.inner.Trace() }

func (l *Logger) Debug() *zerolog.Event { return l.inner.Debug() }

func (l *Logger) Verbose() *zerolog.Event {
	if l.level <= Verbose {
		return l.inner.Debug().Str("v", "1")
	}
	return nil
}

func (l *Logger) Info() *zerolog.Event  { return l.inner.Info() }
func (l *Logger) Warn() *zerolog.Event  { return l.inner.Warn() }
func (l *Logger) Error() *zerolog.Event { return l.inner.Error() }
func (l *Logger) Fatal() *zerolog.Event { return l.inner.Fatal() }

func (l *Logger) Level() Level { return l.level }

func (l *Logger) SetLevel(level Level) {
	l.level = level
	l.inner = l.inner.Level(l.zLevel())
}

func ParseLevel(s string) Level {
	switch strings.ToLower(s) {
	case "trace":
		return Trace
	case "debug":
		return Debug
	case "verbose":
		return Verbose
	case "warn", "warning":
		return Warn
	case "error":
		return Error
	case "fatal":
		return Fatal
	default:
		return Info
	}
}

func colorize(text string, color int) string {
	return "\033[" + itoa(color) + "m" + text + "\033[0m"
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [3]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}

func shortCaller(caller string) string {
	idx := strings.LastIndex(caller, "/")
	if idx >= 0 {
		rest := caller[idx+1:]
		idx2 := strings.Index(rest, ".")
		if idx2 >= 0 {
			return rest[:idx2+1] + "go"
		}
		return rest
	}
	return caller
}
