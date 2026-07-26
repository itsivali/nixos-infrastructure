package commands

import (
	"github.com/itsivali/nixos-infrastructure/internal/platform/health"
	"github.com/itsivali/nixos-infrastructure/internal/state"
	"github.com/itsivali/nixos-infrastructure/internal/terminal"
)

func toTerminalStatus(s state.State) terminal.CheckStatus {
	switch s {
	case state.StateDegraded, state.StateOffline:
		return terminal.StatusFail
	case state.StateWarning:
		return terminal.StatusWarn
	default:
		return terminal.StatusPass
	}
}

func checkResultToItem(r health.CheckResult) terminal.CheckItem {
	detail := r.Message
	if r.Detail != "" {
		detail = r.Detail
	}
	return terminal.CheckItem{Label: r.Name, Status: toTerminalStatus(r.State), Detail: detail}
}

func systemHealthChecks() []terminal.CheckItem {
	results := health.RunAllSystemChecks()
	items := make([]terminal.CheckItem, len(results))
	for i, r := range results {
		items[i] = checkResultToItem(r)
	}
	return items
}

func checkNixFormatting(root string) terminal.CheckItem {
	return checkResultToItem(health.CheckNixFormatting(root))
}
