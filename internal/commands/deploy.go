package commands

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/operations"
)

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CMD DEPLOY — rich deployment with real-time progress
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func CmdDeploy(a *app.App) *cobra.Command {
	var host string
	var skipConfirm bool

	cmd := &cobra.Command{
		Use:   "deploy",
		Short: "🚀  Deploy configuration to the local system",
		Long: `Deploy the current NixOS configuration with rich real-time progress.

Runs the full rebuild pipeline:
  📡  Git fetch from origin
  🔄  Rebase on origin/main
  🔧  Validate hardware UUIDs
  🦫  Check Go vendor hashes (conditional)
  🔍  Evaluate Nix configuration
  ❄️  Validate flake schema
  🏗️  Build and activate system

Shows real-time progress for each stage with icons and timing.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			f := newFlowCtx(a, false)
			f.header("Deploy")

			repoDir := a.Repo.Root
			detectedHost := host
			if detectedHost == "" {
				detectedHost = detectDefaultHost(repoDir)
			}

			// ── Pre-flight: show current state ──────────────────────────
			f.stepStart("Pre-flight checks")

			// Current branch
			branch, _ := gitBranch(repoDir)
			if branch != "" {
				f.stepInfo(fmt.Sprintf("Branch:     %s", f.term.Code(branch)))
			}

			// Current commit
			if out, err := gitRun(repoDir, "git", "rev-parse", "--short", "HEAD"); err == nil {
				f.stepInfo(fmt.Sprintf("Commit:     %s", f.term.Code(strings.TrimSpace(out))))
			}

			// Current generation
			if out, err := gitRun(repoDir, "nix-env", "--list-generations", "--profile", "/nix/var/nix/profiles/system"); err == nil {
				lines := strings.Split(strings.TrimSpace(out), "\n")
				for _, line := range lines {
					if strings.Contains(line, "*") {
						fields := strings.Fields(line)
						if len(fields) > 0 {
							f.stepInfo(fmt.Sprintf("Generation: %s (current)", f.term.Code(fields[0])))
							break
						}
					}
				}
			}

			// Host
			f.stepInfo(fmt.Sprintf("Host:       %s", f.term.Code(detectedHost)))
			f.stepDone()

			// ── Confirmation ────────────────────────────────────────────
			fmt.Println()
			if skipConfirm {
				f.stepInfo("  Skipping confirmation (--yes)")
			} else {
				fmt.Printf("  %s %s %s\n",
					f.term.ColoredIcon("", f.term.Color.Yellow),
					fmt.Sprintf("Deploy to %s?", f.term.Code(detectedHost)),
					f.term.Dim("[y/N]"))
				reader := bufio.NewReader(os.Stdin)
				fmt.Printf("  ")
				response, _ := reader.ReadString('\n')
				response = strings.TrimSpace(strings.ToLower(response))
				if response != "y" && response != "yes" {
					f.stepInfo("Cancelled")
					return nil
				}
			}

			// ── Deployment pipeline ─────────────────────────────────────
			fmt.Println()
			f.stepStart("Running rebuild pipeline")
			fmt.Println()

			startTime := time.Now()

			// Run the rebuild script for rich real-time progress
			rebuildScript := filepath.Join(repoDir, "scripts", "rebuild.sh")
			if _, err := os.Stat(rebuildScript); os.IsNotExist(err) {
				// Fallback to operations deployment service
				return f.deployWithOperationsService(a, repoDir, detectedHost, "")
			}

			// Set environment for rebuild script
			env := os.Environ()
			env = append(env, fmt.Sprintf("REPO_DIR=%s", repoDir))
			env = append(env, fmt.Sprintf("HOST_NAME=%s", detectedHost))

			rebuildCmd := exec.Command("bash", rebuildScript)
			rebuildCmd.Dir = repoDir
			rebuildCmd.Env = env
			rebuildCmd.Stdout = os.Stdout
			rebuildCmd.Stderr = os.Stderr

			buildErr := rebuildCmd.Run()
			duration := time.Since(startTime)

			fmt.Println()

			if buildErr != nil {
				f.stepFail("Deployment failed")
				fmt.Println()
				fmt.Println(f.term.ErrorBox(fmt.Sprintf("  Deployment failed after %s\n  Error: %v", formatDuration(duration), buildErr)))
				return fmt.Errorf("deploy failed: %w", buildErr)
			}

			// ── Success summary ─────────────────────────────────────────
			fmt.Println()
			f.divider()
			fmt.Println()

			// Get new generation
			newGen := ""
			if out, err := gitRun(repoDir, "nix-env", "--list-generations", "--profile", "/nix/var/nix/profiles/system"); err == nil {
				lines := strings.Split(strings.TrimSpace(out), "\n")
				for _, line := range lines {
					if strings.Contains(line, "*") {
						fields := strings.Fields(line)
						if len(fields) > 0 {
							newGen = fields[0]
							break
						}
					}
				}
			}

			// Get new commit
			newCommit := ""
			if out, err := gitRun(repoDir, "git", "rev-parse", "--short", "HEAD"); err == nil {
				newCommit = strings.TrimSpace(out)
			}

			fmt.Println(f.term.Bold("  🎉  Deploy Complete"))
			fmt.Println()
			fmt.Println(f.term.KeyValue("Host:", f.term.Code(detectedHost)))
			if newGen != "" {
				fmt.Println(f.term.KeyValue("Generation:", f.term.Code(newGen)))
			}
			if newCommit != "" {
				fmt.Println(f.term.KeyValue("Commit:", f.term.Code(newCommit)))
			}
			fmt.Println(f.term.KeyValue("Duration:", f.term.Code(formatDuration(duration))))
			fmt.Println()
			fmt.Println(f.term.Dim("  Next: ivali status     — check system health"))
			fmt.Println()

			if a.JSONOutput {
				result := map[string]string{
					"action":     "deploy",
					"host":       detectedHost,
					"generation": newGen,
					"commit":     newCommit,
					"duration":   formatDuration(duration),
					"status":     "success",
				}
				data, _ := json.MarshalIndent(result, "", "  ")
				fmt.Println(string(data))
			}

			return nil
		},
	}

	cmd.Flags().StringVar(&host, "host", "", "Target NixOS host (default: auto-detect)")
	cmd.Flags().BoolVarP(&skipConfirm, "yes", "y", false, "Skip confirmation prompt")

	return cmd
}

// deployWithOperationsService is a fallback that uses the Go deployment service.
func (f *flowCtx) deployWithOperationsService(a *app.App, repoDir, host, commit string) error {
	f.stepInfo("  Using operations deployment engine...")

	audit := operations.NewAuditLogger()
	deploy := operations.NewDeploymentService(repoDir, audit)

	startTime := time.Now()
	record, err := deploy.Deploy(context.Background(), operations.DeployOpts{
		Commit: commit,
		Actor:  "ivali-cli",
		Source: "cli",
	})
	duration := time.Since(startTime)

	if err != nil {
		f.stepFail("Deployment failed")
		fmt.Println()
		fmt.Println(f.term.ErrorBox(fmt.Sprintf("  Deployment failed after %s\n  Error: %v", formatDuration(duration), err)))
		return fmt.Errorf("deploy failed: %w", err)
	}

	// Success summary
	fmt.Println()
	f.divider()
	fmt.Println()
	fmt.Println(f.term.Bold("  🎉  Deploy Complete"))
	fmt.Println()
	fmt.Println(f.term.KeyValue("Status:", f.term.Code(record.Status)))
	fmt.Println(f.term.KeyValue("Generation:", f.term.Code(fmt.Sprintf("%d", record.Generation))))
	fmt.Println(f.term.KeyValue("Duration:", f.term.Code(record.Duration)))
	fmt.Println()
	fmt.Println(f.term.Dim("  Next: ivali status     — check system health"))
	fmt.Println()

	return nil
}

func formatDuration(d time.Duration) string {
	mins := int(d.Minutes())
	secs := int(d.Seconds()) % 60
	if mins > 0 {
		return fmt.Sprintf("%dm%ds", mins, secs)
	}
	return fmt.Sprintf("%ds", secs)
}
