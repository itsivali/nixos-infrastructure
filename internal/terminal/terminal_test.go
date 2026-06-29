package terminal

import (
	"strings"
	"testing"
)

func newTestTerminal() *Terminal {
	return New(WithTheme("dark"))
}

func TestNew_Defaults(t *testing.T) {
	tm := New(WithTheme("dark"))
	if tm.Theme != ThemeDark {
		t.Errorf("expected dark theme, got %v", tm.Theme)
	}
	if tm.Width <= 0 {
		t.Errorf("expected positive width, got %d", tm.Width)
	}
}

func TestNew_LightTheme(t *testing.T) {
	tm := New(WithTheme("light"))
	if tm.DarkBg {
		t.Error("expected light theme to have DarkBg=false")
	}
}

// ── Text Styling ─────────────────────────────────────────────────────

func TestHeader(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Header("test")
	if !strings.Contains(out, "test") {
		t.Errorf("expected header to contain text, got %q", out)
	}
}

func TestH1(t *testing.T) {
	tm := newTestTerminal()
	out := tm.H1("title")
	if !strings.Contains(out, "title") {
		t.Errorf("expected H1 to contain text, got %q", out)
	}
}

func TestH2(t *testing.T) {
	tm := newTestTerminal()
	out := tm.H2("subtitle")
	if !strings.Contains(out, "subtitle") {
		t.Errorf("expected H2 to contain text, got %q", out)
	}
}

func TestSection(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Section("Test")
	if !strings.Contains(out, "Test") {
		t.Errorf("expected section to contain text, got %q", out)
	}
}

func TestSubsection(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Subsection("Aliases")
	if !strings.Contains(out, "Aliases") || !strings.Contains(out, "▸") {
		t.Errorf("expected subsection with arrow, got %q", out)
	}
}

func TestGood(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Good("ok")
	if !strings.Contains(out, "✓") || !strings.Contains(out, "ok") {
		t.Errorf("expected checkmark + text, got %q", out)
	}
}

func TestBad(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Bad("fail")
	if !strings.Contains(out, "✗") || !strings.Contains(out, "fail") {
		t.Errorf("expected xmark + text, got %q", out)
	}
}

func TestWarn(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Warn("warning")
	if !strings.Contains(out, "⚠") || !strings.Contains(out, "warning") {
		t.Errorf("expected warning + text, got %q", out)
	}
}

func TestInfo(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Info("info text")
	if !strings.Contains(out, "ℹ") || !strings.Contains(out, "info text") {
		t.Errorf("expected info + text, got %q", out)
	}
}

func TestDim(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Dim("faded")
	if !strings.Contains(out, "faded") {
		t.Errorf("expected faded text, got %q", out)
	}
}

func TestBold(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Bold("emphasis")
	if !strings.Contains(out, "emphasis") {
		t.Errorf("expected bold text, got %q", out)
	}
}

func TestCode(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Code("import nix")
	if !strings.Contains(out, "import nix") {
		t.Errorf("expected code text, got %q", out)
	}
}

// ── KeyValue / HelpCommand ───────────────────────────────────────────

func TestKeyValue(t *testing.T) {
	tm := newTestTerminal()
	out := tm.KeyValue("Key", "value")
	if !strings.Contains(out, "Key") || !strings.Contains(out, "value") {
		t.Errorf("expected Key and value, got %q", out)
	}
}

func TestKeyValue_WithExtra(t *testing.T) {
	tm := newTestTerminal()
	out := tm.KeyValue("Key", "value", "extra")
	if !strings.Contains(out, "extra") {
		t.Errorf("expected extra text, got %q", out)
	}
}

func TestHelpCommand(t *testing.T) {
	tm := newTestTerminal()
	out := tm.HelpCommand("cmd", "description")
	if !strings.Contains(out, "cmd") || !strings.Contains(out, "description") {
		t.Errorf("expected cmd and description, got %q", out)
	}
}

// ── Boxes ────────────────────────────────────────────────────────────

func TestSuccessBox(t *testing.T) {
	tm := newTestTerminal()
	out := tm.SuccessBox("done")
	if !strings.Contains(out, "done") {
		t.Errorf("expected success box with content, got %q", out)
	}
}

func TestErrorBox(t *testing.T) {
	tm := newTestTerminal()
	out := tm.ErrorBox("error")
	if !strings.Contains(out, "error") {
		t.Errorf("expected error box with content, got %q", out)
	}
}

func TestInfoBox(t *testing.T) {
	tm := newTestTerminal()
	out := tm.InfoBox("info")
	if !strings.Contains(out, "info") {
		t.Errorf("expected info box with content, got %q", out)
	}
}

// ── Table ────────────────────────────────────────────────────────────

func TestTable_Empty(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Table([]string{"A", "B"}, nil)
	if !strings.Contains(out, "(none)") {
		t.Errorf("expected empty table message, got %q", out)
	}
}

func TestTable_WithRows(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Table(
		[]string{"Name", "Value"},
		[][]string{
			{"foo", "1"},
			{"bar", "2"},
		},
	)
	if !strings.Contains(out, "foo") || !strings.Contains(out, "bar") {
		t.Errorf("expected table with rows, got %q", out)
	}
}

// ── BulletList / CheckList ───────────────────────────────────────────

func TestBulletList(t *testing.T) {
	tm := newTestTerminal()
	out := tm.BulletList([]string{"item1", "item2"}, 0)
	if !strings.Contains(out, "item1") || !strings.Contains(out, "item2") {
		t.Errorf("expected bullet list items, got %q", out)
	}
}

func TestBulletList_Indent(t *testing.T) {
	tm := newTestTerminal()
	out := tm.BulletList([]string{"item"}, 1)
	if !strings.Contains(out, "•") {
		t.Errorf("expected bullets, got %q", out)
	}
}

func TestCheckList_AllStatuses(t *testing.T) {
	tm := newTestTerminal()
	items := []CheckItem{
		{Label: "pass", Status: StatusPass},
		{Label: "fail", Status: StatusFail},
		{Label: "warn", Status: StatusWarn},
		{Label: "pending", Status: StatusPending},
	}
	out := tm.CheckList(items)
	if !strings.Contains(out, "pass") || !strings.Contains(out, "fail") ||
		!strings.Contains(out, "warn") || !strings.Contains(out, "pending") {
		t.Errorf("expected all statuses, got %q", out)
	}
}

func TestCheckList_WithDetail(t *testing.T) {
	tm := newTestTerminal()
	items := []CheckItem{
		{Label: "test", Status: StatusPass, Detail: "detail text"},
	}
	out := tm.CheckList(items)
	if !strings.Contains(out, "detail text") {
		t.Errorf("expected detail text, got %q", out)
	}
}

// ── Summary / Count / Timestamp / Separator / Blank ──────────────────

func TestSummary(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Summary("Label", "value")
	if !strings.Contains(out, "value") {
		t.Errorf("expected value in output, got %q", out)
	}
}

func TestCount(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Count(3, 10)
	if !strings.Contains(out, "3/10") {
		t.Errorf("expected 3/10, got %q", out)
	}
}

func TestCount_ZeroTotal(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Count(0, 0)
	if !strings.Contains(out, "0/0") {
		t.Errorf("expected 0/0, got %q", out)
	}
}

func TestTimestamp(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Timestamp()
	if out == "" {
		t.Error("expected non-empty timestamp")
	}
}

func TestSeparator(t *testing.T) {
	tm := newTestTerminal()
	out := tm.Separator()
	if !strings.Contains(out, "─") {
		t.Errorf("expected separator with dashes, got %q", out)
	}
}

func TestBlank(t *testing.T) {
	tm := newTestTerminal()
	if out := tm.Blank(); out != "" {
		t.Errorf("expected empty string, got %q", out)
	}
}

// ── Splash ───────────────────────────────────────────────────────────

func TestRenderSplash(t *testing.T) {
	tm := newTestTerminal()
	out := tm.RenderSplash()
	if !strings.Contains(out, "IVALI") {
		t.Errorf("expected splash with IVALI, got %q", out)
	}
}

// ── IsInteractive ────────────────────────────────────────────────────

func TestIsInteractive(t *testing.T) {
	// In test environment, stdout is not a terminal
	if IsInteractive() {
		t.Error("expected non-interactive in test environment")
	}
}
