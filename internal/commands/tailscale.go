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
			fmt.Println()

			if len(status.Peer) > 0 {
				fmt.Println(t.Section(fmt.Sprintf("Peers (%d)", len(status.Peer))))
				for _, peer := range status.Peer {
					online := t.Bad("offline")
					if peer.Online {
						online = t.Good("online")
					}
					fmt.Println(t.Dim(fmt.Sprintf("  • %-20s  %-15s  %s",
						peer.HostName, strings.Join(peer.TailscaleIPs, ", "), online)))
				}
			}

			return nil
		},
	}
}
