package renderer

import (
	"strings"
	"testing"
)

func TestBuildCard(t *testing.T) {
	card := BuildCard(Card{
		Title:  "Test Card",
		Lines:  []string{"Line 1", "Line 2"},
		Footer: "footer text",
	})

	if !strings.Contains(card, "Test Card") {
		t.Errorf("expected title in card, got %q", card)
	}
	if !strings.Contains(card, "Line 1") {
		t.Errorf("expected Line 1 in card, got %q", card)
	}
	if !strings.Contains(card, "_footer text_") {
		t.Errorf("expected footer in card, got %q", card)
	}
}

func TestBuildCardStatusIcons(t *testing.T) {
	tests := []struct {
		status CardStatus
		icon   string
	}{
		{StatusSuccess, "✅"},
		{StatusWarning, "⚠️"},
		{StatusError, "❌"},
		{StatusNeutral, "📋"},
	}

	for _, tt := range tests {
		card := BuildCard(Card{Title: "Test", Status: tt.status})
		if !strings.Contains(card, tt.icon) {
			t.Errorf("status %v: expected icon %q in card", tt.status, tt.icon)
		}
	}
}

func TestKeyValue(t *testing.T) {
	result := KeyValue("Key", "value")
	if result != "*Key:* `value`" {
		t.Errorf("KeyValue() = %q, want '*Key:* `value`'", result)
	}
}

func TestCodeBlock(t *testing.T) {
	result := CodeBlock("hello")
	if result != "```\nhello\n```" {
		t.Errorf("CodeBlock() = %q", result)
	}
}

func TestBold(t *testing.T) {
	result := Bold("text")
	if result != "*text*" {
		t.Errorf("Bold() = %q, want '*text*'", result)
	}
}

func TestItalic(t *testing.T) {
	result := Italic("text")
	if result != "_text_" {
		t.Errorf("Italic() = %q, want '_text_'", result)
	}
}

func TestInlineCode(t *testing.T) {
	result := InlineCode("code")
	if result != "`code`" {
		t.Errorf("InlineCode() = %q, want '`code`'", result)
	}
}

func TestStatusIcon(t *testing.T) {
	if StatusIcon(true) != "✅" {
		t.Error("expected ✅ for true")
	}
	if StatusIcon(false) != "❌" {
		t.Error("expected ❌ for false")
	}
}

func TestServiceStatusLine(t *testing.T) {
	result := ServiceStatusLine("nginx", "active")
	if !strings.Contains(result, "✅") {
		t.Errorf("expected ✅ for active service, got %q", result)
	}
	if !strings.Contains(result, "nginx") {
		t.Errorf("expected service name, got %q", result)
	}

	result = ServiceStatusLine("nginx", "inactive")
	if !strings.Contains(result, "❌") {
		t.Errorf("expected ❌ for inactive service, got %q", result)
	}
}

func TestSuccess(t *testing.T) {
	result := Success("Done", "All good")
	if !strings.Contains(result, "✅") {
		t.Error("expected ✅ in success card")
	}
	if !strings.Contains(result, "Done") {
		t.Error("expected title in success card")
	}
}

func TestError(t *testing.T) {
	result := Error("Failed", "Something broke")
	if !strings.Contains(result, "❌") {
		t.Error("expected ❌ in error card")
	}
}

func TestConfirmation(t *testing.T) {
	result := Confirmation("deploy", "Really deploy?")
	if !strings.Contains(result, "Confirm deploy") {
		t.Error("expected action name in confirmation")
	}
}

func TestJoinLines(t *testing.T) {
	result := JoinLines("a", "b", "c")
	if result != "a\nb\nc" {
		t.Errorf("JoinLines() = %q", result)
	}
}

func TestProgress(t *testing.T) {
	result := Progress(5, 10, 20)
	if !strings.Contains(result, "5/10") {
		t.Errorf("expected 5/10 in progress, got %q", result)
	}
	if !strings.Contains(result, "█") {
		t.Error("expected filled bar in progress")
	}
}
