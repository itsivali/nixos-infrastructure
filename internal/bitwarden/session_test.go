package bitwarden

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadMasterPasswordFromFile_Success(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "password")
	if err := os.WriteFile(path, []byte("my-secret-password\n"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("BW_MASTER_PASSWORD_FILE", path)

	got, err := ReadMasterPasswordFromFile()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "my-secret-password" {
		t.Errorf("got %q, want %q", got, "my-secret-password")
	}
}

func TestReadMasterPasswordFromFile_LeadingTrailingWhitespace(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "password")
	if err := os.WriteFile(path, []byte("  \n  my-pass  \n  "), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("BW_MASTER_PASSWORD_FILE", path)

	got, err := ReadMasterPasswordFromFile()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "my-pass" {
		t.Errorf("got %q, want %q", got, "my-pass")
	}
}

func TestReadMasterPasswordFromFile_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "password")
	if err := os.WriteFile(path, []byte(""), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("BW_MASTER_PASSWORD_FILE", path)

	got, err := ReadMasterPasswordFromFile()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "" {
		t.Errorf("got %q, want empty string", got)
	}
}

func TestReadMasterPasswordFromFile_MissingFile(t *testing.T) {
	t.Setenv("BW_MASTER_PASSWORD_FILE", "/nonexistent/path/password")

	got, err := ReadMasterPasswordFromFile()
	if err == nil {
		t.Fatal("expected error for missing file, got nil")
	}
	if got != "" {
		t.Errorf("got %q, want empty string", got)
	}
}

func TestReadMasterPasswordFromFile_EnvUnset(t *testing.T) {
	_ = os.Unsetenv("BW_MASTER_PASSWORD_FILE")

	got, err := ReadMasterPasswordFromFile()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "" {
		t.Errorf("got %q, want empty string", got)
	}
}

func TestReadSopsEmailFromFile_Success(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "email")
	if err := os.WriteFile(path, []byte("user@example.com\n"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("BW_SOPS_EMAIL_FILE", path)

	got, err := ReadSopsEmailFromFile()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "user@example.com" {
		t.Errorf("got %q, want %q", got, "user@example.com")
	}
}

func TestReadSopsEmailFromFile_MissingFile(t *testing.T) {
	t.Setenv("BW_SOPS_EMAIL_FILE", "/nonexistent/path/email")

	got, err := ReadSopsEmailFromFile()
	if err == nil {
		t.Fatal("expected error for missing file, got nil")
	}
	if got != "" {
		t.Errorf("got %q, want empty string", got)
	}
}

func TestReadSopsEmailFromFile_EnvUnset(t *testing.T) {
	_ = os.Unsetenv("BW_SOPS_EMAIL_FILE")

	got, err := ReadSopsEmailFromFile()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "" {
		t.Errorf("got %q, want empty string", got)
	}
}
