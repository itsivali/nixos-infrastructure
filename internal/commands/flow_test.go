package commands

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

// initTestRepo creates a bare git repo with a local clone, a "main" commit,
// and optionally a feature branch with its own remote tracking ref.
// Returns the local repo path.
func initTestRepo(t *testing.T) string {
	t.Helper()

	tmp := t.TempDir()

	// Create bare repo
	bare := filepath.Join(tmp, "bare.git")
	if out, err := exec.Command("git", "init", "--bare", bare).CombinedOutput(); err != nil {
		t.Fatalf("git init --bare: %v\n%s", err, out)
	}

	// Clone into local repo
	local := filepath.Join(tmp, "local")
	if out, err := exec.Command("git", "clone", bare, local).CombinedOutput(); err != nil {
		t.Fatalf("git clone: %v\n%s", err, out)
	}

	// Configure user and force branch to main
	for _, args := range [][]string{
		{"git", "-C", local, "config", "user.email", "test@test.com"},
		{"git", "-C", local, "config", "user.name", "Test"},
		{"git", "-C", local, "checkout", "-b", "main"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// Create initial commit on main
	if err := os.WriteFile(filepath.Join(local, "readme.txt"), []byte("hello"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", local, "add", "."},
		{"git", "-C", local, "commit", "-m", "initial"},
		{"git", "-C", local, "push", "-u", "origin", "main"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	return local
}

func TestGitUnpushed_NoBranchRef(t *testing.T) {
	local := initTestRepo(t)

	// Create feature branch (no remote tracking ref yet)
	for _, args := range [][]string{
		{"git", "-C", local, "checkout", "-b", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// Add a commit on the feature branch
	if err := os.WriteFile(filepath.Join(local, "feat.txt"), []byte("feature"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", local, "add", "."},
		{"git", "-C", local, "commit", "-m", "feature commit"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// A never-pushed feature branch has no origin/feature/test ref, so
	// gitUnpushed falls back to origin/main and reports the branch commits
	// as unpushed (they are — a first push would carry them).
	commits, hasCommits := gitUnpushed(local, "feature/test")
	if !hasCommits {
		t.Error("expected the branch commit to be reported as unpushed (no remote ref yet)")
	}
	if !strings.Contains(commits, "feature commit") {
		t.Errorf("expected 'feature commit' in unpushed list, got: %q", commits)
	}
}

func TestGitUnpushed_BranchPushed(t *testing.T) {
	local := initTestRepo(t)

	// Create and push feature branch
	for _, args := range [][]string{
		{"git", "-C", local, "checkout", "-b", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	if err := os.WriteFile(filepath.Join(local, "feat.txt"), []byte("feature"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", local, "add", "."},
		{"git", "-C", local, "commit", "-m", "feature commit"},
		{"git", "-C", local, "push", "-u", "origin", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// Branch is fully pushed — should report no unpushed commits.
	commits, hasCommits := gitUnpushed(local, "feature/test")
	if hasCommits {
		t.Errorf("expected no unpushed commits, got: %q", commits)
	}
}

func TestGitUnpushed_BranchAhead(t *testing.T) {
	local := initTestRepo(t)

	// Create and push feature branch
	for _, args := range [][]string{
		{"git", "-C", local, "checkout", "-b", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	if err := os.WriteFile(filepath.Join(local, "feat.txt"), []byte("feature"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", local, "add", "."},
		{"git", "-C", local, "commit", "-m", "feature commit"},
		{"git", "-C", local, "push", "-u", "origin", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// Now add another commit (not pushed)
	if err := os.WriteFile(filepath.Join(local, "feat2.txt"), []byte("feature2"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", local, "add", "."},
		{"git", "-C", local, "commit", "-m", "unpushed commit"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// Should report the unpushed commit.
	commits, hasCommits := gitUnpushed(local, "feature/test")
	if !hasCommits {
		t.Error("expected unpushed commits, got none")
	}
	if commits == "" {
		t.Error("expected non-empty commit list")
	}
}

func TestGitUnpushed_NotMain(t *testing.T) {
	// Verify that passing "main" checks origin/main, NOT origin/<current branch>.
	// This was the old bug: MR flow used gitUnpushed(repo, "main") for feature branches.
	local := initTestRepo(t)

	// Create and push feature branch with one commit
	for _, args := range [][]string{
		{"git", "-C", local, "checkout", "-b", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	if err := os.WriteFile(filepath.Join(local, "feat.txt"), []byte("feature"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", local, "add", "."},
		{"git", "-C", local, "commit", "-m", "feature commit"},
		{"git", "-C", local, "push", "-u", "origin", "feature/test"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	// Using "main" as the branch arg (the old buggy code):
	// gitUnpushed(repo, "main") → git log origin/main..HEAD
	// This would show the feature commit as "unpushed" relative to main.
	_, hasCommits := gitUnpushed(local, "main")
	if !hasCommits {
		t.Error("gitUnpushed('main') should show commits ahead of origin/main")
	}

	// Using the correct branch name (the fix):
	// gitUnpushed(repo, "feature/test") → git log origin/feature/test..HEAD
	// This shows nothing because it's fully pushed.
	commits, hasCommits := gitUnpushed(local, "feature/test")
	if hasCommits {
		t.Errorf("gitUnpushed('feature/test') should report no unpushed commits, got: %q", commits)
	}
}

func TestGitBranch(t *testing.T) {
	local := initTestRepo(t)

	branch, err := gitBranch(local)
	if err != nil {
		t.Fatalf("gitBranch: %v", err)
	}
	if branch != "main" {
		t.Errorf("expected 'main', got %q", branch)
	}

	// Switch to feature branch
	for _, args := range [][]string{
		{"git", "-C", local, "checkout", "-b", "feature/foo"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	branch, err = gitBranch(local)
	if err != nil {
		t.Fatalf("gitBranch: %v", err)
	}
	if branch != "feature/foo" {
		t.Errorf("expected 'feature/foo', got %q", branch)
	}
}

func TestGitBranch_NotRepo(t *testing.T) {
	_, err := gitBranch(t.TempDir())
	if err == nil {
		t.Error("expected error for non-git directory")
	}
}

// TestFlowMRTitle_AIKeepsCommitMessage verifies the regression where
// `ivali flow mr` in AI mode (non-interactive stdin) clobbered the title
// derived from the last commit message: newFlowCtx forces aiMode=true for
// non-TTY stdin, but the caller's local `aiMode` stayed false, so the
// interactive "Use custom title?" path ran and prompt() returned "".
func TestFlowMRTitle_AIKeepsCommitMessage(t *testing.T) {
	tmp := t.TempDir()
	if out, err := exec.Command("git", "init", tmp).CombinedOutput(); err != nil {
		t.Fatalf("git init: %v\n%s", err, out)
	}
	for _, args := range [][]string{
		{"git", "-C", tmp, "config", "user.email", "test@test.com"},
		{"git", "-C", tmp, "config", "user.name", "Test"},
		{"git", "-C", tmp, "checkout", "-b", "main"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}
	if err := os.WriteFile(filepath.Join(tmp, "file.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	const commitMsg = "docs: stabilization acceptance documentation"
	for _, args := range [][]string{
		{"git", "-C", tmp, "add", "."},
		{"git", "-C", tmp, "commit", "-m", commitMsg},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	f := &flowCtx{aiMode: true, repoDir: tmp, term: terminal.New()}
	title := flowMRTitle(f, "feature/test", nil)
	if title != commitMsg {
		t.Fatalf("AI mode must use last commit as title, got %q", title)
	}
}

// TestFlowMRTitle_ArgWins verifies an explicit title argument is preferred
// over the last commit message in any mode.
func TestFlowMRTitle_ArgWins(t *testing.T) {
	tmp := t.TempDir()
	if out, err := exec.Command("git", "init", tmp).CombinedOutput(); err != nil {
		t.Fatalf("git init: %v\n%s", err, out)
	}
	for _, args := range [][]string{
		{"git", "-C", tmp, "config", "user.email", "test@test.com"},
		{"git", "-C", tmp, "config", "user.name", "Test"},
		{"git", "-C", tmp, "checkout", "-b", "main"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}
	if err := os.WriteFile(filepath.Join(tmp, "file.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{
		{"git", "-C", tmp, "add", "."},
		{"git", "-C", tmp, "commit", "-m", "some previous commit"},
	} {
		if out, err := exec.Command(args[0], args[1:]...).CombinedOutput(); err != nil {
			t.Fatalf("%v: %v\n%s", args, err, out)
		}
	}

	f := &flowCtx{aiMode: true, repoDir: tmp, term: terminal.New()}
	title := flowMRTitle(f, "feature/test", []string{"explicit title"})
	if title != "explicit title" {
		t.Fatalf("explicit argument must win, got %q", title)
	}
}
