package commands

import (
	"encoding/json"
	"fmt"

	"github.com/spf13/cobra"

	"github.com/itsivali/nixos-infrastructure/internal/app"
	"github.com/itsivali/nixos-infrastructure/internal/inventory"
)

func CmdInventory(a *app.App) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "inventory",
		Short: "📋  Show host inventory",
		Long: `Display comprehensive system inventory including hardware,
software, services, network, firewall, and deployment info.`,
		RunE: func(cmd *cobra.Command, args []string) error {
			inv := inventory.Collect()

			if a.JSONOutput {
				return json.NewEncoder(cmd.OutOrStdout()).Encode(inv)
			}

			t := a.Term

			fmt.Println()
			fmt.Println(t.Header("📋  Host Inventory"))
			fmt.Println()

			fmt.Println(t.Section("System"))
			fmt.Println(t.KeyValue("Hostname", inv.Hostname))
			fmt.Println(t.KeyValue("OS", inv.OS))
			fmt.Println(t.KeyValue("Kernel", inv.Kernel))
			uptime := fmt.Sprintf("%.0fd %dh",
				inv.Uptime.Hours()/24,
				int(inv.Uptime.Hours())%24)
			fmt.Println(t.KeyValue("Uptime", uptime))
			fmt.Println()

			fmt.Println(t.Section("CPU"))
			fmt.Println(t.KeyValue("Model", inv.CPU.Model))
			fmt.Println(t.KeyValue("Cores", fmt.Sprintf("%d", inv.CPU.Cores)))
			fmt.Println(t.KeyValue("Threads", fmt.Sprintf("%d", inv.CPU.Threads)))
			fmt.Println(t.KeyValue("Load (1/5/15)", fmt.Sprintf("%.2f / %.2f / %.2f",
				inv.CPU.Load1, inv.CPU.Load5, inv.CPU.Load15)))
			fmt.Println()

			fmt.Println(t.Section("GPU"))
			if len(inv.GPU) == 0 {
				fmt.Println(t.Dim("  No GPU detected"))
			} else {
				for _, gpu := range inv.GPU {
					vendor := gpu.Vendor
					if vendor == "" {
						vendor = "Unknown"
					}
					fmt.Println(t.KeyValue(vendor, gpu.Model))
				}
			}
			fmt.Println()

			fmt.Println(t.Section("Memory"))
			fmt.Println(t.KeyValue("Total", fmt.Sprintf("%.1f GB", inv.Memory.TotalGB)))
			fmt.Println(t.KeyValue("Used", fmt.Sprintf("%.1f GB (%d%%)", inv.Memory.UsedGB, inv.Memory.UsedPercent)))
			fmt.Println(t.KeyValue("Available", fmt.Sprintf("%.1f GB", inv.Memory.AvailableGB)))
			fmt.Println()

			fmt.Println(t.Section("Storage"))
			for _, d := range inv.Storage {
				fmt.Println(t.KeyValue(d.MountPoint,
					fmt.Sprintf("%.0f/%.0f GB (%d%%) [%s]", d.UsedGB, d.TotalGB, d.UsedPercent, d.FSType)))
			}
			fmt.Println()

			fmt.Println(t.Section("Network"))
			fmt.Println(t.KeyValue("Hostname", inv.Network.Hostname))
			for _, ip := range inv.Network.IPAddresses {
				fmt.Println(t.KeyValue("IP", ip))
			}
			for _, dns := range inv.Network.DNSServers {
				fmt.Println(t.KeyValue("DNS", dns))
			}
			fmt.Println()

			fmt.Println(t.Section("Firewall"))
			if inv.Firewall.Enabled {
				fmt.Println(t.KeyValue("nftables", t.Good("enabled")))
			} else {
				fmt.Println(t.KeyValue("nftables", t.Dim("not detected")))
			}
			fmt.Println()

			fmt.Println(t.Section("Tailscale"))
			if inv.Tailscale.Installed {
				status := t.Good("connected")
				if !inv.Tailscale.Connected {
					status = t.Warn("disconnected")
				}
				fmt.Println(t.KeyValue("Status", status))
				if inv.Tailscale.IP != "" {
					fmt.Println(t.KeyValue("IP", inv.Tailscale.IP))
				}
			} else {
				fmt.Println(t.Dim("  Not installed"))
			}
			fmt.Println()

			fmt.Println(t.Section("Boot"))
			fmt.Println(t.KeyValue("Bootloader", inv.Bootloader))
			fmt.Println()

			fmt.Println(t.Section("Encryption"))
			if inv.Encryption.LUKS {
				fmt.Println(t.KeyValue("LUKS", t.Good("enabled")))
			}
			if inv.Encryption.SOPS {
				fmt.Println(t.KeyValue("SOPS", t.Good("configured")))
			}
			fmt.Println()

			return nil
		},
	}

	return cmd
}
