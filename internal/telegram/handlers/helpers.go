package handlers

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"time"
)

// runCmd executes a shell command with a timeout and returns its output.
func runCmd(command string, timeoutSecs int) string {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSecs)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "sh", "-c", command)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	output := stdout.String()
	if stderr.Len() > 0 {
		if output != "" {
			output += "\n"
		}
		output += stderr.String()
	}

	if ctx.Err() == context.DeadlineExceeded {
		return "Command timed out after " + string(rune(timeoutSecs)) + "s"
	}

	if err != nil && output == "" {
		return "Error: " + err.Error()
	}

	return output
}

// runCmdArgs executes a command directly (no shell) with a timeout and
// returns its combined output. Unlike runCmd, it does NOT invoke /bin/sh, so
// shell metacharacters in user-supplied arguments are treated as literal
// arguments rather than interpreted — this prevents command injection from
// commands like /run and /nix that forward user input.
func runCmdArgs(timeoutSecs int, args ...string) string {
	if len(args) == 0 {
		return ""
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSecs)*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()

	output := stdout.String()
	if stderr.Len() > 0 {
		if output != "" {
			output += "\n"
		}
		output += stderr.String()
	}

	if ctx.Err() == context.DeadlineExceeded {
		return fmt.Sprintf("Command timed out after %ds", timeoutSecs)
	}

	if err != nil && output == "" {
		return "Error: " + err.Error()
	}

	return output
}
