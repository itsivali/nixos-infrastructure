# home/shell/bitwarden.nix

{ config, pkgs, lib, ... }:

let
  cacheDir = "${config.xdg.cacheHome}/bitwarden";
  sessionFile = "${cacheDir}/session";

  # Fully integrated interactive password search & copy engine
  bwp = pkgs.writeShellScriptBin "bwp" ''
    set -e

    # 1. Sync session variables
    if [ -z "$BW_SESSION" ] && [ -f "${sessionFile}" ]; then
      export BW_SESSION=$(cat "${sessionFile}")
    fi

    if [ -z "$BW_SESSION" ]; then
      echo "❌ No active session found. Attempting automatic unlock..."
    fi

    # 2. Match OS clipboard environment
    if [ -n "$WAYLAND_DISPLAY" ]; then
      CLIP_CMD="${pkgs.wl-clipboard}/bin/wl-copy"
    else
      CLIP_CMD="${pkgs.xclip}/bin/xclip -selection clipboard"
    fi

    echo "🔄 Fetching vault items..."

    # 3. Stream filtered vault metadata to fzf, isolate ID, extract raw secret cleanly
    SELECTED_ID=$(${pkgs.bitwarden-cli}/bin/bw list items | ${pkgs.jq}/bin/jq -r '.[] | "\(.name) (u: \(.login.username // "none")) [\(.id)]"' | ${pkgs.fzf}/bin/fzf --height 40% --reverse --prompt="🔑 Select Account: " | grep -o '[a-f0-9-]\{36\}')

    if [ -n "$SELECTED_ID" ]; then
      ${pkgs.bitwarden-cli}/bin/bw get password "$SELECTED_ID" | tr -d '\n' | $CLIP_CMD
      echo "✅ Password copied to clipboard safely!"
    else
      echo "⚠️ No item selected."
    fi
  '';
in
{
  ###############################################################
  # Packages
  ###############################################################

  home.packages = with pkgs; [
    bitwarden-cli
    jq
    fzf
    wl-clipboard
    xclip
    libsecret # Used to interact natively with your GNOME Keyring / KWallet
    bwp       # Custom search utility script
  ];

  ###############################################################
  # Environment Context Tracking
  ###############################################################

  home.file.".cache/bitwarden/.keep".text = "";

  home.sessionVariables = {
    BW_SESSION_FILE = sessionFile;
  };

  ###############################################################
  # Shell Optimization Aliases
  ###############################################################

  programs.zsh.shellAliases = {
    bws  = "bw status | jq";
    bwu  = "bwunlock";
    bwl  = "bwlock";
    bwc  = "bwclear";
    bwsy = "bwsync";
  };

  ###############################################################
  # Core System Keyring Integration & Shell Hooks
  ###############################################################

  # Using initContent with lib.mkAfter so it appends to ivali.nix cleanly
  programs.zsh.initContent = lib.mkAfter ''
    # --- Seamless System Keyring Automation Functions ---

    bwunlock() {
      # 1. Safely poll Secret Service for stored API string
      local api_secret
      api_secret=$(secret-tool lookup service bitwarden account login 2>/dev/null)

      if [ -z "$api_secret" ]; then
        echo "🔑 No Bitwarden API token registered inside the system keyring."
        echo -n "Please enter your client_secret: "
        read -s api_secret
        echo ""

        echo -n "Please enter your client_id (e.g. user.xxxxxx): "
        read -r api_id

        # Bind the client_secret string contextually inside system keyring
        echo "$api_secret" | secret-tool store --label="Bitwarden API Secret" service bitwarden account login
        echo "$api_id" | secret-tool store --label="Bitwarden API Client ID" service bitwarden account id
        echo "✅ API credentials saved to keyring securely."
      else
        local api_id
        api_id=$(secret-tool lookup service bitwarden account id 2>/dev/null)
      fi

      # 2. Bind parameters to background subshell
      export BW_CLIENTID="$api_id"
      export BW_CLIENTSECRET="$api_secret"

      # 3. Non-interactive login handshake via API
      bw login --apikey > /dev/null 2>&1

      # 4. Prompt for Master Password exactly *once* to unpack local keysets
      local session
      echo "🔐 Unlocking local secure vault..."
      session=$(bw unlock --raw)

      if [ -n "$session" ]; then
        export BW_SESSION="$session"
        mkdir -p "${cacheDir}"
        printf "%s" "$BW_SESSION" > "${sessionFile}"
        chmod 600 "${sessionFile}"
        echo "🔒 Session initialized. Subshells are now fully authenticated."
      fi
    }

    bwlock() {
      bw lock
      rm -f "${sessionFile}"
      unset BW_SESSION
      echo "🔓 Local cache evicted. Vault locked."
    }

    bwlogout() {
      bw logout
      rm -f "${sessionFile}"
      unset BW_SESSION
    }

    bwsync() {
      if [ -f "${sessionFile}" ]; then
        export BW_SESSION=$(cat "${sessionFile}")
      fi
      bw sync
    }

    bwclear() {
      rm -f "${sessionFile}"
      unset BW_SESSION
    }

    # --- Runtime Initialization Hook ---
    # Silently restore session if available; never block shell startup
    if [[ -f "${sessionFile}" ]] && [[ -z "$BW_SESSION" ]]; then
      export BW_SESSION=$(<"${sessionFile}")
    fi
  '';
}
