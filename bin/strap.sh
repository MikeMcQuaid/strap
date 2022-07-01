#!/usr/bin/env bash
#/ Usage: bin/strap.sh [--debug]
#/ Install development dependencies on macOS.
set -eo pipefail

RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
OCHRE="\033[38;5;95m"
BLUE="\033[0;34m"
WHITE="\033[0;37m"
RESET="\033[0m"

[[ $1 == "--debug" || -o xtrace ]] && STRAP_DEBUG="1"

  SUDO_WAIT_PATH="/var/db/sudo/$SUDO_USER"
  echo $SUDO_WAIT_PATH
  exit -1
  rm -f "$SUDO_WAIT_PATH/endwait"

    mkdir -p "$SUDO_WAIT_PATH"
    touch "$SUDO_WAIT_PATH"
    if [ -f "$SUDO_WAIT_PATH/endwait" ]; then
      rm -f "$SUDO_WAIT_PATH/endwait"
      exit 0
    fi
    sleep 1
  done
  exit 0
fi

#arg parsing
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--debug)
      STRAP_DEBUG="1"
      shift
      ;;
    -k|--parallels-key)
      if [ -z "$2" ]; then
        echo "--parallels-key argument requires a value. Ex: --parallels-key XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX"
        exit 1
      fi
      
      # write license key to file
      echo -n "$2" > "$HOME/.parallels-lk"
      shift
      shift
      ;;
    --keep-sudo-waiting)
      KEEP_SUDO_WAITING=1
      shift
      ;;
    *)
      echo "Unknown command line option: $1"
      exit 1
      ;;
  esac
done

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
      echo "!!! If you're stuck: file an issue with debugging output at:" >&2
      echo "!!!   $STRAP_ISSUES_URL" >&2
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

# Set by web/app.rb
# STRAP_GIT_NAME=
# STRAP_GIT_EMAIL=
# STRAP_GITHUB_USER=
# STRAP_GITHUB_TOKEN=
# CUSTOM_HOMEBREW_TAP=
# CUSTOM_BREW_COMMAND=
STRAP_ISSUES_URL='https://github.com/MikeMcQuaid/strap/issues/new'
# DOCKER_USERNAME=
# DOCKER_PASSWORD=

DAPTIV_DOTFILES_BRANCH="${DAPTIV_DOTFILES_BRANCH:-master}"
USER_DOTFILES_BRANCH="${USER_DOTFILES_BRANCH:-master}"
STRAP_ISSUES_URL='https://github.com/daptiv/strap/issues/new'

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
  if grep -q pam_tid /etc/pam.d/sudo; then
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
  PAM_FILE="/etc/pam.d/sudo"
  FIRST_LINE="# sudo: auth account password session"
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
sudo_askpass defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled \
  -bool false
sudo_askpass defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles \
  -bool false
sudo_askpass defaults write com.apple.screensaver askForPassword -int 1
sudo_askpass defaults write com.apple.screensaver askForPasswordDelay -int 0
sudo_askpass defaults write /Library/Preferences/com.apple.alf globalstate -int 1
sudo_askpass launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null

if [ -n "$STRAP_GIT_NAME" ] && [ -n "$STRAP_GIT_EMAIL" ]; then
  LOGIN_TEXT=$(escape "Found this computer? Please contact $STRAP_GIT_NAME at $STRAP_GIT_EMAIL.")
  echo "$LOGIN_TEXT" | grep -q '[()]' && LOGIN_TEXT="'$LOGIN_TEXT'"
  sudo_askpass defaults write /Library/Preferences/com.apple.loginwindow \
    LoginwindowText \
    "$LOGIN_TEXT"
fi
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
  sudo_askpass fdesetup enable -user "$USER" \
    | tee ~/Desktop/"FileVault Recovery Key.txt"
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

  CLT_PACKAGE=$(softwareupdate -l \
    | grep -B 1 "Command Line Tools" \
    | awk -F"*" '/^ *\*/ {print $2}' \
    | sed -e 's/^ *Label: //' -e 's/^ *//' \
    | sort -V \
    | tail -n1)
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

# Setup Git configuration.
logn "Configuring Git..."
if [ -n "$STRAP_GIT_NAME" ] && ! git config user.name >/dev/null; then
  git config --global user.name "$STRAP_GIT_NAME"
fi

if [ -n "$STRAP_GIT_EMAIL" ] && ! git config user.email >/dev/null; then
  git config --global user.email "$STRAP_GIT_EMAIL"
fi

if [ -n "$STRAP_GITHUB_USER" ] && [ "$(git config github.user)" != "$STRAP_GITHUB_USER" ]; then
  git config --global github.user "$STRAP_GITHUB_USER"
fi

# Squelch git 2.x warning message when pushing
if ! git config push.default >/dev/null; then
  git config --global push.default simple
fi


# Setup GitHub HTTPS credentials.
if git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain"; then
  # Actually execute the credential in case it's a wrapper script for credential-osxkeychain
  if git "credential-$(git config --global credential.helper 2>/dev/null)" 2>&1 \
    | grep -v $Q "git.credential-osxkeychain"; then
    git config --global credential.helper osxkeychain
  fi

  if [ -n "$STRAP_GITHUB_USER" ] && [ -n "$STRAP_GITHUB_TOKEN" ]; then
    printf 'protocol=https\nhost=github.com\n' | git credential reject
    printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n' \

      "$STRAP_GITHUB_USER" "$STRAP_GITHUB_TOKEN" \
      | git credential approve
  fi
fi
logk

# Setup Homebrew directory and permissions.
logn "Installing Homebrew:"
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

# Update Homebrew.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
logn "Updating Homebrew:"
brew update --quiet

logk

# Install Homebrew Bundle, Cask and Services tap.
log "Installing Homebrew taps and extensions:"
brew bundle --quiet --file=- <<RUBY
tap "homebrew/cask"
tap "homebrew/core"
tap "homebrew/services"
RUBY
tap 'daptiv/homebrew-tap'
EOF
else
brew bundle --file=- 1>/dev/null 2>&1 <<EOF
tap 'homebrew/cask'

tap 'daptiv/homebrew-tap'

fi
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


# clone strap locally
STRAP_SRC_DIR="$HOME/src/strap"
logn "Ensure strap is cloned locally and up to date..."
if [ ! -d "$STRAP_SRC_DIR" ]; then
  log "Cloning to $STRAP_SRC_DIR:"
  git clone $Q "git@github.com:daptiv/strap" "$STRAP_SRC_DIR"
else
  (
    logdebug "Updating local repository."
    cd "$STRAP_SRC_DIR"
    git pull $Q --rebase --autostash
  )
fi
logk

# Setup dotfiles

if [ -n "$STRAP_GITHUB_USER" ]; then
  DOTFILES_URL="https://github.com/$STRAP_GITHUB_USER/dotfiles"

  if git ls-remote "$DOTFILES_URL" &>/dev/null; then
    log "Fetching $STRAP_GITHUB_USER/dotfiles from GitHub:"
    if [ ! -d "$HOME/.dotfiles" ]; then
      log "Cloning to ~/.dotfiles:"
      git clone $Q "$DOTFILES_URL" ~/.dotfiles
    else
      (
        cd ~/.dotfiles
        git pull $Q --rebase --autostash
      )
    fi
    run_dotfile_scripts script/setup script/bootstrap







    logk
  fi
fi

# Setup Daptiv dotfiles
DOTFILES_URL="git@github.com:daptiv/dotfiles"
DOTFILES_DIR="$HOME/.daptiv-dotfiles"

logn "Fetching daptiv/dotfiles from GitHub..."
if [ ! -d "$DOTFILES_DIR" ]; then
  logdebug "Cloning to $DOTFILES_DIR:"
  git clone $Q "$DOTFILES_URL" "$DOTFILES_DIR" 1>/dev/null 2>&1

else
  (
    logdebug "Updating local repository."
    cd "$DOTFILES_DIR"
    git pull $Q --rebase --autostash 1>/dev/null 2>&1
  )
fi
run_dotfile_scripts script/setup script/bootstrap
logk
(
  logn "Check current branch of daptiv/dotfiles against requested branch..."
  cd "$DOTFILES_DIR"
  CURRENT_DAPTIV_DOTFILES_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$DAPTIV_DOTFILES_BRANCH" != "$CURRENT_DAPTIV_DOTFILES_BRANCH" ]; then
    # check to make sure there are no pending changes in current branch
    if git diff-index --quiet HEAD -- ; then
      logdebug "Changing branch from '$CURRENT_DAPTIV_DOTFILES_BRANCH' to '$DAPTIV_DOTFILES_BRANCH'"
      git checkout $DAPTIV_DOTFILES_BRANCH
      git pull $Q --rebase --autostash
    else
      abort "Pending changes in $DOTFILES_DIR, unable to switch to branch: $DAPTIV_DOTFILES_BRANCH. If you want to run in this branch run strap with: DAPTIV_DOTFILES_BRANCH=$CURRENT_DAPTIV_DOTFILES_BRANCH"
    fi
  fi
  logk

# Install from local Brewfile
if [ -f "$HOME/.Brewfile" ]; then
  log "Installing from user Brewfile on GitHub:"
  brew bundle check --global || brew bundle --global
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