#!/usr/bin/env bash
# commands/deploy.sh — /deploy — Deploy NixOS configuration
##############################################################################

_cmd_deploy() {
  local chat="$1" args="$2"
  send_typing "$chat"

  # Check for confirmation token
  if [[ "$args" == *"confirm"* ]]; then
    send_msg "$chat" "🚀 Deploying NixOS configuration..."
    local start_time=$(date +%s)
    
    # Pull latest changes, then rebuild
    cd "${REPO_DIR}" && git pull --ff-only 2>&1 || true
    sudo nixos-rebuild switch --flake ".#${HOST}" 2>&1 | tail -20
    local result=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $result -eq 0 ]]; then
      send_msg "$chat" "✅ Deployment successful! (${duration}s)
      
*Generation:* $(nix_current_generation)
*Host:* ${HOST}"
    else
      send_msg "$chat" "❌ Deployment failed (${duration}s)

Check logs with \`/log nixos-rebuild-switch\`"
    fi
    return
  fi

  # Show confirmation with inline keyboard
  local msg="⚠️ *Confirm Deployment*

Are you sure you want to deploy NixOS configuration?

*Host:* ${HOST}
*Current generation:* $(nix_current_generation)

This action will:
• Pull latest changes from Git
• Build and activate new NixOS generation
• May take several minutes to complete"
  
  send_inline_keyboard "$chat" "$msg" "✅ Yes, deploy:deploy_confirm" "❌ Cancel:deploy_cancel"
}

# Handle callback queries
_cmd_deploy_callback() {
  local chat="$1" callback_id="$2" data="$3"

  case "$data" in
    deploy_confirm)
      answer_callback "$callback_id" "Deploying..."
      _cmd_deploy "$chat" "confirm"
      ;;
    deploy_cancel)
      answer_callback "$callback_id" "Deployment cancelled"
      send_msg "$chat" "✅ Deployment cancelled"
      ;;
  esac
}

register_command "deploy" "_cmd_deploy" "🚀 Deploy NixOS configuration"
register_callback "deploy_confirm" "_cmd_deploy_callback"
register_callback "deploy_cancel" "_cmd_deploy_callback"
