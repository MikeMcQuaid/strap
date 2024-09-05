#!/bin/bash
#/ Usage: strap.sh [--debug]
#/ Install development dependencies on macOS.
set -e

[[ $1 == "--debug" || -o xtrace ]] && STRAP_DEBUG="1"
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
  sudo_refresh
  echo "--> $*"
}

logn() {
  STRAP_STEP="$*"
  sudo_refresh
  printf -- "--> %s " "$*"
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
          if [ -z "$STRAP_DEBUG" ]; then
            "$i" 2>/dev/null
          else
            "$i"
          fi
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

  CLT_PACKAGE=$(softwareupdate -l |
    grep -B 1 "Command Line Tools" |
    awk -F"*" '/^ *\*/ {print $2}' |
    sed -e 's/^ *Label: //' -e 's/^ *//' |
    sort -V |
    tail -n1)
  sudo_askpass softwareupdate -i "$CLT_PACKAGE"
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

logn "Installing Homebrew:"
if [[ ! -f "/opt/workbrew/bin/brew" ]]; then
  # Setup Homebrew directory and permissions.
  HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
  if [ -z "$HOMEBREW_PREFIX" ] || [ -z "$HOMEBREW_REPOSITORY" ]; then
    UNAME_MACHINE="$(/usr/bin/uname -m)"
    if [[ $UNAME_MACHINE == "arm64" ]]; then
      HOMEBREW_PREFIX="/opt/homebrew"
      HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
    else
      HOMEBREW_PREFIX="/usr/local"
      HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
    fi
  fi
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
else
  logskip "Workbrew is already installed so not trying to install Homebrew."
fi

# Update Homebrew.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
log "Updating Homebrew:"
brew update --quiet
logk

# Check and install any remaining software updates.
logn "Checking for software updates:"
if softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  logk
else
  echo
  log "Installing software updates:"
  if [ -z "$STRAP_CI" ]; then
    sudo_askpass softwareupdate --install --all
    xcode_license
    logk
  else
    echo "SKIPPED (for CI)"
  fi
fi

# Setup dotfiles
if [ -d "$HOME/.dotfiles/.git" ]; then
  logn "Updating ~/.dotfiles:"
  (
    cd ~/.dotfiles
    git pull $Q --rebase --autostash
  )
  logk
  run_dotfile_scripts script/setup script/bootstrap
fi

# Setup Brewfile
if [ -d "$HOME/.homebrew-brewfile/.git" ]; then
  log "Updating ~/.homebrew-brewfile:"
  (
    cd ~/.homebrew-brewfile
    git pull $Q
  )
  ln -sf ~/.homebrew-brewfile/Brewfile ~/.Brewfile
  logk
fi

# Install from local Brewfile
if [ -f "$HOME/.Brewfile" ]; then
  log "Installing from ~/.Brewfile:"
  brew bundle check --global &>/dev/null || brew bundle --global
  logk
fi

# Run post-install dotfiles script
run_dotfile_scripts script/strap-after-setup

STRAP_SUCCESS="1"
log "Your system is now Strap'd!"
