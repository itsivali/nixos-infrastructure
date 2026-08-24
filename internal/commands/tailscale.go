package commands

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
)

func CmdTailscale(a *app.App) *cobra.Command {
	return &cobra.Command{
		Use:   "tailscale",
		Short: "🌐  Show Tailscale VPN status",
		Long: `Display comprehensive Tailscale VPN status including:
  • Connection state and IP addresses
  • Key expiry information
  • Peer list with online status and throughput
  • Tailscale Serve/Funnel endpoints
  • Exit node status`,
		RunE: func(cmd *cobra.Command, args []string) error {
			t := a.Term

			fmt.Println(t.Header("🌐 Tailscale Status"))
			fmt.Println()

			out, err := exec.Command("tailscale", "status", "--json").CombinedOutput()
			if err != nil {
				fmt.Println(t.Bad("Tailscale not available or not connected"))
				fmt.Println(t.Dim(string(out)))
				return nil
			}

			var status struct {
				BackendState string `json:"BackendState"`
				Self         struct {
					HostName     string   `json:"HostName"`
					TailscaleIPs []string `json:"TailscaleIPs"`
					OS           string   `json:"OS"`
					Online       bool     `json:"Online"`
					KeyExpiry    string   `json:"KeyExpiry"`
					TxnBytes     int64    `json:"TxnBytes"`
					RxBytes      int64    `json:"RxBytes"`
				} `json:"Self"`
				Peer map[string]struct {
					HostName     string   `json:"HostName"`
					TailscaleIPs []string `json:"TailscaleIPs"`
					OS           string   `json:"OS"`
					Online       bool     `json:"Online"`
					TxBytes      int64    `json:"TxBytes"`
					RxBytes      int64    `json:"RxBytes"`
				} `json:"Peer"`
			}

			if err := json.Unmarshal(out, &status); err != nil {
				fmt.Println(t.Bad("Failed to parse Tailscale status"))
				fmt.Println(t.Dim(string(out)))
				return nil
			}

			fmt.Println(t.Section("Connection"))
			if status.BackendState == "Running" {
				fmt.Println(t.KeyValue("State", t.Good("Connected")))
			} else {
				fmt.Println(t.KeyValue("State", t.Bad(status.BackendState)))
			}
			fmt.Println(t.KeyValue("Hostname", status.Self.HostName))
			if len(status.Self.TailscaleIPs) > 0 {
				fmt.Println(t.KeyValue("IP", strings.Join(status.Self.TailscaleIPs, ", ")))
			}
			fmt.Println(t.KeyValue("OS", status.Self.OS))

			// Key expiry
			if status.Self.KeyExpiry != "" && status.Self.KeyExpiry != "none" {
				fmt.Println(t.KeyValue("Key Expiry", status.Self.KeyExpiry))
			} else {
				fmt.Println(t.KeyValue("Key Expiry", t.Dim("no expiry")))
			}

			// Throughput
			if status.Self.TxnBytes > 0 || status.Self.RxBytes > 0 {
				fmt.Println(t.KeyValue("TX", formatBytes(status.Self.TxnBytes)))
				fmt.Println(t.KeyValue("RX", formatBytes(status.Self.RxBytes)))
			}
			fmt.Println()

			if len(status.Peer) > 0 {
				onlineCount := 0
				for _, peer := range status.Peer {
					if peer.Online {
						onlineCount++
					}
				}
				fmt.Println(t.Section(fmt.Sprintf("Peers (%d online / %d total)", onlineCount, len(status.Peer))))
				for _, peer := range status.Peer {
					online := t.Bad("offline")
					if peer.Online {
						online = t.Good("online")
					}
					throughput := ""
					if peer.TxBytes > 0 || peer.RxBytes > 0 {
						throughput = fmt.Sprintf("  %s↑ %s↓", formatBytes(peer.TxBytes), formatBytes(peer.RxBytes))
					}
					fmt.Println(t.Dim(fmt.Sprintf("  • %-20s  %-15s  %s%s",
						peer.HostName, strings.Join(peer.TailscaleIPs, ", "), online, throughput)))
				}
			}

			return nil
		},
	}
}

// formatBytes formats bytes into a human-readable string.
func formatBytes(bytes int64) string {
	const (
		KB = 1024
		MB = 1024 * KB
		GB = 1024 * MB
	)
	switch {
	case bytes >= GB:
		return fmt.Sprintf("%.1f GB", float64(bytes)/float64(GB))
	case bytes >= MB:
		return fmt.Sprintf("%.1f MB", float64(bytes)/float64(MB))
	case bytes >= KB:
		return fmt.Sprintf("%.1f KB", float64(bytes)/float64(KB))
	default:
		return fmt.Sprintf("%d B", bytes)
	}
}
