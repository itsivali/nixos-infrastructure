package handlers

import (
	"strings"
)

// quoteSh single-quotes a string for safe embedding in `sh -c '...'`,
// escaping any embedded single quotes.
func quoteSh(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}
