#!/bin/bash
#/ Usage: bin/strap.sh [options]
#/ Install development dependencies on macOS.
set -e

# Reserve empty values for explicitly skipped fields.
for STRAP_VALUE in STRAP_GIT_NAME STRAP_GIT_EMAIL STRAP_GITHUB_USER; do
  if [ -z "${!STRAP_VALUE}" ]; then
    unset "$STRAP_VALUE"
  fi
done
if [ "${STRAP_NO_GIT_NAME:-0}" = "1" ]; then
  STRAP_GIT_NAME=""
fi
if [ "${STRAP_NO_GIT_EMAIL:-0}" = "1" ]; then
  STRAP_GIT_EMAIL=""
fi
if [ "${STRAP_NO_GITHUB_USER:-0}" = "1" ]; then
  STRAP_GITHUB_USER=""
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
  --debug) STRAP_DEBUG="1" ;;
  --no-github) STRAP_NO_GITHUB="1" ;;
  --no-git-name) STRAP_GIT_NAME="" ;;
  --no-git-email) STRAP_GIT_EMAIL="" ;;
  --no-github-user) STRAP_GITHUB_USER="" ;;
  --git-name | --git-email | --github-user)
    if [ "$#" -lt 2 ] || [ -z "$2" ] || [[ $2 == --* ]]; then
      echo "!!! $1 requires a value (use --no-${1#--} to skip it)." >&2
      exit 1
    fi
    case "$1" in
    --git-name) STRAP_GIT_NAME="$2" ;;
    --git-email) STRAP_GIT_EMAIL="$2" ;;
    --github-user) STRAP_GITHUB_USER="$2" ;;
    *) exit 1 ;;
    esac
    shift
    ;;
  --help | -h)
    cat <<'HELP'
Usage: strap.sh [options]
  --debug             Enable debugging output (STRAP_DEBUG=1).
  --no-github          Skip GitHub login and profile lookup (STRAP_NO_GITHUB=1).
  --git-name NAME      Set Git's name (STRAP_GIT_NAME).
  --no-git-name        Skip Git's name (STRAP_NO_GIT_NAME=1).
  --git-email EMAIL    Set Git's email (STRAP_GIT_EMAIL).
  --no-git-email       Skip Git's email (STRAP_NO_GIT_EMAIL=1).
  --github-user USER   Select the dotfiles/Brewfile owner (STRAP_GITHUB_USER).
  --no-github-user     Skip the owner lookup and fetch (STRAP_NO_GITHUB_USER=1).
  --help              Show this help.

Flags override environment variables; the last flag for a field wins.
Use --no-* flags to skip fields without changing existing Git settings.
Empty environment values are ignored.
Existing Git name/email are preserved unless explicitly overridden.
GitHub login is optional and is never prompted for in unattended or CI runs.
GH_TOKEN or GITHUB_TOKEN can supply existing GitHub credentials.
HELP
    exit 0
    ;;
  *)
    echo "!!! Unknown option: $1. Run '$0 --help' for usage." >&2
    exit 1
    ;;
  esac
  shift
done
[[ -o xtrace ]] && STRAP_DEBUG="1"
STRAP_SUCCESS=""

sudo_askpass() {
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass "$@"
  else
    sudo "$@"
  fi
}

cleanup() {
  set +e
  sudo_askpass rm -rf "$CLT_PLACEHOLDER" "$SUDO_ASKPASS" "$SUDO_ASKPASS_DIR"
  sudo --reset-timestamp
  if [ -z "$STRAP_SUCCESS" ]; then
    if [ -n "$STRAP_STEP" ]; then
      echo "!!! $STRAP_STEP FAILED" >&2
    else
      echo "!!! FAILED" >&2
    fi
    if [ -z "$STRAP_DEBUG" ]; then
      echo "!!! Run '$0 --debug' for debugging output." >&2
      if [ -n "$STRAP_ISSUES_URL" ]; then
        echo "!!! If you're stuck: file an issue with debugging output at:" >&2
        echo "!!!   $STRAP_ISSUES_URL" >&2
      fi
    fi
  fi
}

trap "cleanup" EXIT

if [ -n "$STRAP_DEBUG" ]; then
  set -x
else
  STRAP_QUIET_FLAG="-q"
  Q="$STRAP_QUIET_FLAG"
fi

STDIN_FILE_DESCRIPTOR="0"
[ -t "$STDIN_FILE_DESCRIPTOR" ] && STRAP_INTERACTIVE="1"

# We want to always prompt for sudo password at least once rather than doing
# root stuff unexpectedly.
sudo --reset-timestamp

# functions for turning off debug for use when handling the user password
clear_debug() {
  set +x
}

reset_debug() {
  if [ -n "$STRAP_DEBUG" ]; then
    set -x
  fi
}

# Initialise (or reinitialise) sudo to save unhelpful prompts later.
sudo_init() {
  if [ -z "$STRAP_INTERACTIVE" ]; then
    return
  fi

  # If TouchID for sudo is setup: use that instead.
  if grep -q pam_tid /etc/pam.d/sudo /etc/pam.d/sudo_local 2>/dev/null; then
    return
  fi

  local SUDO_PASSWORD SUDO_PASSWORD_SCRIPT

  if ! sudo --validate --non-interactive &>/dev/null; then
    while true; do
      read -rsp "--> Enter your password (for sudo access):" SUDO_PASSWORD
      echo
      if sudo --validate --stdin 2>/dev/null <<<"$SUDO_PASSWORD"; then
        break
      fi

      unset SUDO_PASSWORD
      echo "!!! Wrong password!" >&2
    done

    clear_debug
    SUDO_PASSWORD_SCRIPT="$(
      cat <<BASH
#!/bin/bash
echo "$SUDO_PASSWORD"
BASH
    )"
    unset SUDO_PASSWORD
    SUDO_ASKPASS_DIR="$(mktemp -d)"
    SUDO_ASKPASS="$(mktemp "$SUDO_ASKPASS_DIR"/strap-askpass-XXXXXXXX)"
    chmod 700 "$SUDO_ASKPASS_DIR" "$SUDO_ASKPASS"
    bash -c "cat > '$SUDO_ASKPASS'" <<<"$SUDO_PASSWORD_SCRIPT"
    unset SUDO_PASSWORD_SCRIPT
    reset_debug

    export SUDO_ASKPASS
  fi
}

sudo_refresh() {
  clear_debug
  if [ -n "$SUDO_ASKPASS" ]; then
    sudo --askpass --validate
  else
    sudo_init
  fi
  reset_debug
}

abort() {
  STRAP_STEP=""
  echo "!!! $*" >&2
  exit 1
}

log() {
  STRAP_STEP="$*"
  echo "--> $*"
  sudo_refresh
}

logn() {
  STRAP_STEP="$*"
  printf -- "--> %s " "$*"
  sudo_refresh
}

logk() {
  STRAP_STEP=""
  echo "OK"
}

logskip() {
  STRAP_STEP=""
  echo "SKIPPED"
  echo "$*"
}

escape() {
  printf '%s' "${1//\'/\'}"
}

# Given a list of scripts in the dotfiles repo, run the first one that exists
run_dotfile_scripts() {
  if [ -d ~/.dotfiles ]; then
    (
      cd ~/.dotfiles
      for i in "$@"; do
        if [ -f "$i" ] && [ -x "$i" ]; then
          log "Running dotfiles $i:"
          "$i"
          logk
          break
        fi
      done
    )
  fi
}

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
groups | grep $Q -E "\b(admin)\b" || abort "Add $USER to the admin group."

# Prevent sleeping during script execution, as long as the machine is on AC power
caffeinate -s -w $$ &

# Check and, if necessary, enable sudo authentication using TouchID.
# Don't care about non-alphanumeric filenames when doing a specific match
# shellcheck disable=SC2010
if ls /usr/lib/pam | grep $Q "pam_tid.so"; then
  logn "Configuring sudo authentication using TouchID:"
  if [[ -f /etc/pam.d/sudo_local || -f /etc/pam.d/sudo_local.template ]]; then
    # New in macOS Sonoma, survives updates.
    PAM_FILE="/etc/pam.d/sudo_local"
    FIRST_LINE="# sudo_local: local config file which survives system update and is included for sudo"
    if [[ ! -f "/etc/pam.d/sudo_local" ]]; then
      echo "$FIRST_LINE" | sudo_askpass tee "$PAM_FILE" >/dev/null
    fi
  else
    PAM_FILE="/etc/pam.d/sudo"
    FIRST_LINE="# sudo: auth account password session"
  fi
  if grep $Q pam_tid.so "$PAM_FILE"; then
    logk
  elif ! head -n1 "$PAM_FILE" | grep $Q "$FIRST_LINE"; then
    logskip "$PAM_FILE is not in the expected format!"
  else
    TOUCHID_LINE="auth       sufficient     pam_tid.so"
    sudo_askpass sed -i .bak -e \
      "s/$FIRST_LINE/$FIRST_LINE\n$TOUCHID_LINE/" \
      "$PAM_FILE"
    sudo_askpass rm "$PAM_FILE.bak"
    logk
  fi
fi

# Set some basic security settings.
logn "Configuring security settings:"
sudo_askpass defaults write com.apple.screensaver askForPassword -int 1
sudo_askpass defaults write com.apple.screensaver askForPasswordDelay -int 0
sudo_askpass defaults write /Library/Preferences/com.apple.alf globalstate -int 1
sudo_askpass launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null

logk

# Check and enable full-disk encryption.
logn "Checking full-disk encryption status:"
if fdesetup status | grep $Q -E "FileVault is (On|Off, but will be enabled after the next restart)."; then
  logk
elif [ -n "$STRAP_CI" ]; then
  echo "SKIPPED (for CI)"
elif [ -n "$STRAP_INTERACTIVE" ]; then
  echo
  log "Enabling full-disk encryption on next reboot:"
  sudo_askpass fdesetup enable -user "$USER" |
    tee ~/Desktop/"FileVault Recovery Key.txt"
  logk
else
  echo
  abort "Run 'sudo fdesetup enable -user \"$USER\"' to enable full-disk encryption."
fi

# Install the Xcode Command Line Tools.
if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
  log "Installing the Xcode Command Line Tools:"
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo_askpass touch "$CLT_PLACEHOLDER"

  for CLT_RETRY_DELAY in 0 10 20; do
    sleep "$CLT_RETRY_DELAY"
    CLT_PACKAGE=$(softwareupdate -l |
      tee /dev/stderr |
      grep -B 1 "Command Line Tools" |
      awk -F"*" '/^ *\*/ {print $2}' |
      sed -e 's/^ *Label: //' -e 's/^ *//' |
      sort -V |
      tail -n1)
    if [ -n "$CLT_PACKAGE" ]; then
      sudo_askpass softwareupdate -i "$CLT_PACKAGE"
      break
    fi
  done
  sudo_askpass rm -f "$CLT_PLACEHOLDER"
  if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]; then
    if [ -n "$STRAP_INTERACTIVE" ]; then
      echo
      logn "Requesting user install of Xcode Command Line Tools:"
      xcode-select --install
    else
      echo
      abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
    fi
  fi
  logk
fi

# Check if the Xcode license is agreed to and agree if not.
xcode_license() {
  if /usr/bin/xcrun clang 2>&1 | grep $Q license; then
    if [ -n "$STRAP_INTERACTIVE" ]; then
      logn "Asking for Xcode license confirmation:"
      sudo_askpass xcodebuild -license
      logk
    else
      abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
    fi
  fi
}
xcode_license

# Setup Homebrew directory and permissions.
if [[ "$(uname -m)" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
  HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
  export PATH="/opt/homebrew/bin:$PATH"
else
  HOMEBREW_PREFIX="/usr/local"
  HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  export PATH="/usr/local/bin:$PATH"
fi

if ! command -v brew &>/dev/null; then
  logn "Installing Homebrew:"
  [ -d "$HOMEBREW_PREFIX" ] || sudo_askpass mkdir -p "$HOMEBREW_PREFIX"
  if [ "$HOMEBREW_PREFIX" = "/usr/local" ]; then
    sudo_askpass chown "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
  fi
  (
    cd "$HOMEBREW_PREFIX"
    sudo_askpass mkdir -p Cellar Caskroom Frameworks bin etc include lib opt sbin share var
    sudo_askpass chown "$USER:admin" Cellar Caskroom Frameworks bin etc include lib opt sbin share var
  )

  [ -d "$HOMEBREW_REPOSITORY" ] || sudo_askpass mkdir -p "$HOMEBREW_REPOSITORY"
  sudo_askpass chown -R "$USER:admin" "$HOMEBREW_REPOSITORY"

  if [ $HOMEBREW_PREFIX != $HOMEBREW_REPOSITORY ]; then
    ln -sf "$HOMEBREW_REPOSITORY/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
  fi

  # Download Homebrew.
  export GIT_DIR="$HOMEBREW_REPOSITORY/.git" GIT_WORK_TREE="$HOMEBREW_REPOSITORY"
  git init $Q
  git config remote.origin.url "https://github.com/Homebrew/brew"
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch $Q --tags --force
  git reset $Q --hard origin/master
  unset GIT_DIR GIT_WORK_TREE
  logk
fi

# Update Homebrew.
log "Updating Homebrew:"
brew update --quiet
logk

# Set up GitHub before accessing dotfiles or Brewfiles.
if [ -z "${STRAP_GIT_NAME+x}" ]; then
  STRAP_GIT_NAME=$(git config user.name) || unset STRAP_GIT_NAME
fi
if [ -z "${STRAP_GIT_EMAIL+x}" ]; then
  STRAP_GIT_EMAIL=$(git config user.email) || unset STRAP_GIT_EMAIL
fi

STRAP_GITHUB_AUTHENTICATED=""
if [ "${STRAP_NO_GITHUB:-0}" != "1" ] && [ -z "$STRAP_CI" ]; then
  if command -v gh &>/dev/null && gh auth status --active --hostname github.com &>/dev/null; then
    STRAP_GITHUB_AUTHENTICATED="1"
  else
    STRAP_GITHUB_SETUP=""
    if [ -n "${GH_TOKEN:+1}" ] || [ -n "${GITHUB_TOKEN:+1}" ]; then
      STRAP_GITHUB_SETUP="1"
    elif [ -n "$STRAP_INTERACTIVE" ]; then
      read -rp "--> Log in to GitHub to configure Git and fetch your dotfiles? [Y/n] " STRAP_GITHUB_SETUP || STRAP_GITHUB_SETUP="n"
      case "$STRAP_GITHUB_SETUP" in
      "" | y | Y | yes | YES) STRAP_GITHUB_SETUP="1" ;;
      *) STRAP_GITHUB_SETUP="" ;;
      esac
    fi

    if [ -n "$STRAP_GITHUB_SETUP" ]; then
      if ! command -v gh &>/dev/null; then
        log "Installing GitHub CLI:"
        brew install gh
      fi
      if [ -n "${GH_TOKEN:+1}" ] || [ -n "${GITHUB_TOKEN:+1}" ]; then
        if gh auth status --active --hostname github.com &>/dev/null; then
          STRAP_GITHUB_AUTHENTICATED="1"
        fi
      else
        STRAP_GITHUB_LOGIN_ARGS=(--hostname github.com --git-protocol https --web)
        if [ -z "${STRAP_GIT_EMAIL+x}" ]; then
          STRAP_GITHUB_LOGIN_ARGS+=(--scopes user:email)
        fi
        if gh auth login "${STRAP_GITHUB_LOGIN_ARGS[@]}"; then
          STRAP_GITHUB_AUTHENTICATED="1"
        fi
      fi
      if [ -z "$STRAP_GITHUB_AUTHENTICATED" ]; then
        logskip "GitHub authentication failed; continuing without GitHub profile lookup."
      fi
    fi
  fi
fi

if [ -n "$STRAP_GITHUB_AUTHENTICATED" ]; then
  gh auth setup-git --hostname github.com
  if [ -z "${STRAP_GITHUB_USER+x}" ]; then
    STRAP_GITHUB_USER=$(gh api user --hostname github.com --jq .login) || true
  fi
  if [ -z "${STRAP_GIT_NAME+x}" ]; then
    STRAP_GIT_NAME=$(gh api user --hostname github.com --jq '.name // empty') || true
  fi
  if [ -z "${STRAP_GIT_EMAIL+x}" ]; then
    STRAP_GIT_EMAIL=$(gh api user/emails --hostname github.com --paginate --jq '.[] | select(.primary and .verified) | .email') ||
      logskip "Set --git-email explicitly or grant email access with 'gh auth refresh --hostname github.com --scopes user:email'."
  fi
fi

# Setup Git configuration.
logn "Configuring Git:"
if [ -n "$STRAP_GIT_NAME" ] && [ "$(git config user.name)" != "$STRAP_GIT_NAME" ]; then
  git config --global user.name "$STRAP_GIT_NAME"
fi
if [ -n "$STRAP_GIT_EMAIL" ] && [ "$(git config user.email)" != "$STRAP_GIT_EMAIL" ]; then
  git config --global user.email "$STRAP_GIT_EMAIL"
fi
if [ -n "$STRAP_GITHUB_USER" ] && [ "$(git config github.user)" != "$STRAP_GITHUB_USER" ]; then
  git config --global github.user "$STRAP_GITHUB_USER"
fi
logk

# Check and install any remaining software updates.
logn "Checking for software updates:"
if softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  logk
else
  echo
  log "Installing software updates:"
  if [ -z "$STRAP_CI" ] && [ -z "$STRAP_NO_SOFTWAREUPDATE" ]; then
    sudo_askpass softwareupdate --install --all
    xcode_license
    logk
  elif [ -n "$STRAP_CI" ]; then
    echo "SKIPPED (for CI)"
  else
    echo "SKIPPED (by STRAP_NO_SOFTWAREUPDATE)"
  fi
fi

if [ -n "$STRAP_GIT_NAME" ] && [ -n "$STRAP_GIT_EMAIL" ]; then
  logn "Configuring login-screen message:"
  LOGIN_TEXT=$(escape "Found this computer? Please contact $STRAP_GIT_NAME at $STRAP_GIT_EMAIL.")
  if [[ $LOGIN_TEXT == *"("* || $LOGIN_TEXT == *")"* ]]; then
    LOGIN_TEXT="'$LOGIN_TEXT'"
  fi
  sudo_askpass defaults write /Library/Preferences/com.apple.loginwindow \
    LoginwindowText \
    "$LOGIN_TEXT"
  logk
fi

# Setup dotfiles
if [ -n "$STRAP_GITHUB_USER" ]; then
  DOTFILES_URL="https://github.com/$STRAP_GITHUB_USER/dotfiles"

  if GIT_TERMINAL_PROMPT=0 git ls-remote "$DOTFILES_URL" &>/dev/null; then
    log "Fetching $STRAP_GITHUB_USER/dotfiles from GitHub:"
    if [ ! -d "$HOME/.dotfiles" ]; then
      log "Cloning to ~/.dotfiles:"
      git clone $Q "$DOTFILES_URL" ~/.dotfiles
    else
      logn "Updating ~/.dotfiles:"
      git -C ~/.dotfiles pull $Q --rebase --autostash
    fi
    run_dotfile_scripts script/setup script/bootstrap
    logk
  fi
fi

# Setup Brewfile
if [ -n "$STRAP_GITHUB_USER" ] && { [ ! -f "$HOME/.Brewfile" ] || [ "$HOME/.Brewfile" -ef "$HOME/.homebrew-brewfile/Brewfile" ]; }; then
  HOMEBREW_BREWFILE_URL="https://github.com/$STRAP_GITHUB_USER/homebrew-brewfile"

  if GIT_TERMINAL_PROMPT=0 git ls-remote "$HOMEBREW_BREWFILE_URL" &>/dev/null; then
    log "Fetching $STRAP_GITHUB_USER/homebrew-brewfile from GitHub:"
    if [ ! -d "$HOME/.homebrew-brewfile" ]; then
      log "Cloning to ~/.homebrew-brewfile:"
      git clone $Q "$HOMEBREW_BREWFILE_URL" ~/.homebrew-brewfile
      logk
    else
      log "Updating ~/.homebrew-brewfile:"
      git -C ~/.homebrew-brewfile pull $Q
    fi
    ln -sf ~/.homebrew-brewfile/Brewfile ~/.Brewfile
    logk
  fi
fi

# Install from local Brewfile
if [ -f "$HOME/.Brewfile" ]; then
  log "Installing from ~/.Brewfile:"
  brew bundle check --global &>/dev/null || brew bundle --global
  logk
fi

# Tap a custom Homebrew tap
if [ -n "$CUSTOM_HOMEBREW_TAP" ]; then
  read -ra CUSTOM_HOMEBREW_TAP <<<"$CUSTOM_HOMEBREW_TAP"
  log "Running 'brew tap ${CUSTOM_HOMEBREW_TAP[*]}':"
  brew tap "${CUSTOM_HOMEBREW_TAP[@]}"
  logk
fi

# Run a custom `brew` command
if [ -n "$CUSTOM_BREW_COMMAND" ]; then
  log "Executing 'brew $CUSTOM_BREW_COMMAND':"
  # Want to expand even if empty or multiple arguments
  # shellcheck disable=SC2086
  brew $CUSTOM_BREW_COMMAND
  logk
fi

# Run post-install dotfiles script
run_dotfile_scripts script/strap-after-setup

STRAP_SUCCESS="1"
log "Your system is now Strap'd!"
