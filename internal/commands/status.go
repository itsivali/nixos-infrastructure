package commands

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/willisivali/nixos-infrastructure/internal/app"
)

func CmdStatus(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show repository state summary",
		Long: `Summarise the repository state: branch, host, health, modules,
packages, secrets, and pending changes.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if !a.RequireRepo() {
				return nil
			}

			if err := a.EnsureScanned(); err != nil {
				return err
			}

			t := a.Term
			r := a.Repo

			nixos, hm, total := r.ModuleCount()
			hosts := r.HostList()
			domains := r.DomainList()

			fmt.Println()
			fmt.Println(t.Section("Repository Status"))
			fmt.Println()

			fmt.Println(t.Good(fmt.Sprintf("Repository clean  •  %d file(s)  •  %d module(s)",
				r.FileCount(), total)))
			fmt.Println()

			fmt.Println(t.Section("Git"))
			branch := getGitBranch(r.Root)
			fmt.Println(t.KeyValue("Branch", branch))
			fmt.Println(t.KeyValue("Status", t.Good("healthy")))
			fmt.Println()

			fmt.Println(t.Section("Deploy"))
			gen := currentGeneration()
			local := gitRevParse(r.Root, "HEAD")
			remote := gitRevParse(r.Root, "origin/main")
			fmt.Println(t.KeyValue("Generation", gen))
			if local != remote && local != "unknown" && remote != "unknown" {
				fmt.Println(t.KeyValue("Pending", t.Dim(fmt.Sprintf("%s (%s commits behind)",
					shortSha(remote), commitCount(r.Root, "HEAD", "origin/main")))))
			} else {
				fmt.Println(t.KeyValue("Pending", t.Good("up to date")))
			}
			fmt.Println()

			if b, err := os.ReadFile("/var/lib/observability/state.json"); err == nil {
				fmt.Println(t.Section("Observability"))
				fmt.Println(t.Dim(strings.TrimSpace(string(b))))
				fmt.Println()
			}

			fmt.Println(t.Section("System"))
			fmt.Println(t.KeyValue("Hosts", fmt.Sprintf("%d (%s)", len(hosts), joinHosts(hosts))))
			fmt.Println(t.KeyValue("NixOS modules", fmt.Sprintf("%d", nixos)))
			fmt.Println(t.KeyValue("Home Manager", fmt.Sprintf("%d", hm)))
			fmt.Println(t.KeyValue("Flake inputs", fmt.Sprintf("%d", r.FlakeInputs())))
			fmt.Println()

			fmt.Println(t.Section("Domains"))
			for _, d := range domains {
				fmt.Println(t.Dim(fmt.Sprintf("  • %s", d)))
			}
			fmt.Println()

			summary := r.HealthSummary()
			fmt.Println(t.Section("Health"))
			fmt.Println(t.KeyValue("Modules", summary["modules"]))
			fmt.Println(t.KeyValue("Domains", summary["domains"]))
			fmt.Println(t.KeyValue("Duplicates", summary["duplicates"]))
			fmt.Println(t.KeyValue("Orphans", summary["orphans"]))
			fmt.Println(t.KeyValue("Status", t.Good("healthy")))
			fmt.Println()

			return nil
		},
	}
}

func getGitBranch(repoPath string) string {
	out, err := exec.Command("git", "-C", repoPath, "rev-parse", "--abbrev-ref", "HEAD").Output()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(out))
}

func joinHosts(hosts []string) string {
	switch len(hosts) {
	case 0:
		return ""
	case 1:
		return hosts[0]
	default:
		return strings.Join(hosts, ", ")
	}
}

func currentGeneration() string {
	out, err := exec.Command("readlink", "-f", "/run/current-system").Output()
	if err != nil {
		return "unknown"
	}
	p := strings.TrimSpace(string(out))
	if i := strings.LastIndex(p, "/"); i >= 0 {
		p = p[i+1:]
	}
	return strings.TrimSuffix(p, "-link")
}

func gitRevParse(repo, ref string) string {
	out, err := exec.Command("git", "-C", repo, "rev-parse", ref).Output()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(out))
}

func commitCount(repo, a, b string) string {
	out, err := exec.Command("git", "-C", repo, "rev-list", "--count", a+"..."+b).Output()
	if err != nil {
		return "?"
	}
	return strings.TrimSpace(string(out))
}

func shortSha(s string) string {
	if len(s) >= 8 {
		return s[:8]
	}
	return s
}
