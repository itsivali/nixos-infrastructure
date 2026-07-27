// Package renderer provides consistent Telegram response formatting.
package renderer

import (
	"fmt"
	"strings"
)

// Card represents a formatted response card.
type Card struct {
	Title  string
	Icon   string
	Lines  []string
	Footer string
	Status CardStatus
}

// CardStatus represents the visual status of a card.
type CardStatus int

const (
	StatusNeutral CardStatus = iota
	StatusSuccess
	StatusWarning
	StatusError
)

// BuildCard produces a Markdown-formatted card string.
func BuildCard(card Card) string {
	var lines []string

	icon := card.Icon
	if icon == "" {
		switch card.Status {
		case StatusSuccess:
			icon = "✅"
		case StatusWarning:
			icon = "⚠️"
		case StatusError:
			icon = "❌"
		default:
			icon = "📋"
		}
	}

	if card.Title != "" {
		lines = append(lines, fmt.Sprintf("*%s %s*", icon, card.Title))
		lines = append(lines, "")
	}

	lines = append(lines, card.Lines...)

	if card.Footer != "" {
		lines = append(lines, "")
		lines = append(lines, fmt.Sprintf("_%s_", card.Footer))
	}

	return strings.Join(lines, "\n")
}

// KeyValue produces a formatted key: `value` line.
func KeyValue(key, value string) string {
	return fmt.Sprintf("*%s:* `%s`", key, value)
}

// KeyValueBold produces a formatted key: **value** line.
func KeyValueBold(key, value string) string {
	return fmt.Sprintf("*%s:* %s", key, value)
}

// StatusIcon returns an icon for a boolean status.
func StatusIcon(active bool) string {
	if active {
		return "✅"
	}
	return "❌"
}

// ServiceStatusLine produces a formatted service status line.
func ServiceStatusLine(name, status string) string {
	icon := "✅"
	if status != "active" {
		icon = "❌"
	}
	return fmt.Sprintf("%s `%-20s` %s", icon, name, status)
}

// CodeBlock wraps text in a Markdown code block.
func CodeBlock(text string) string {
	return "```\n" + text + "\n```"
}

// Bold wraps text in Markdown bold.
func Bold(text string) string {
	return "*" + text + "*"
}

// Italic wraps text in Markdown italic.
func Italic(text string) string {
	return "_" + text + "_"
}

// InlineCode wraps text in Markdown inline code.
func InlineCode(text string) string {
	return "`" + text + "`"
}

// JoinLines joins lines with newlines.
func JoinLines(lines ...string) string {
	return strings.Join(lines, "\n")
}

// Section produces a titled section with a separator.
func Section(title string, lines ...string) string {
	var parts []string
	parts = append(parts, fmt.Sprintf("*%s*", title))
	parts = append(parts, "")
	parts = append(parts, lines...)
	return strings.Join(parts, "\n")
}

// Table produces a simple two-column table in Markdown.
func Table(rows [][]string) string {
	var lines []string
	for _, row := range rows {
		if len(row) >= 2 {
			lines = append(lines, fmt.Sprintf("`%-20s` %s", row[0], row[1]))
		} else if len(row) == 1 {
			lines = append(lines, row[0])
		}
	}
	return strings.Join(lines, "\n")
}

// Progress produces a simple text progress bar.
func Progress(current, total int, width int) string {
	if total == 0 {
		return "[.]"
	}
	ratio := float64(current) / float64(total)
	filled := int(ratio * float64(width))
	if filled > width {
		filled = width
	}
	bar := strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
	return fmt.Sprintf("[%s] %d/%d", bar, current, total)
}

// Confirmation produces a confirmation prompt card.
func Confirmation(action, description string) string {
	return BuildCard(Card{
		Title:  "Confirm " + action,
		Status: StatusWarning,
		Lines:  []string{description},
		Footer: "Press Confirm or Cancel below.",
	})
}

// Success produces a success response card.
func Success(title, detail string) string {
	return BuildCard(Card{
		Title:  title,
		Status: StatusSuccess,
		Lines:  []string{detail},
	})
}

// Error produces an error response card.
func Error(title, reason string) string {
	return BuildCard(Card{
		Title:  title,
		Status: StatusError,
		Lines:  []string{reason},
	})
}
