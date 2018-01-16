#!/bin/bash
#/ Usage: bin/strap.sh [--debug]
#/ Install development dependencies on macOS.
set -e

# Keep sudo timestamp updated while Strap is running.
if [ "$1" = "--sudo-wait" ]; then
  while true; do
    mkdir -p "/var/db/sudo/$SUDO_USER"
    touch "/var/db/sudo/$SUDO_USER"
    sleep 1
  done
  exit 0
fi

[ "$1" = "--debug" ] && STRAP_DEBUG="1"
STRAP_SUCCESS=""

cleanup() {
  set +e
  if [ -n "$STRAP_SUDO_WAIT_PID" ]; then
    sudo kill "$STRAP_SUDO_WAIT_PID"
  fi
  sudo -k
  rm -f "$CLT_PLACEHOLDER"
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
# STRAP_CONTACT_PHONE=
DAPTIV_DOTFILES_BRANCH="${DAPTIV_DOTFILES_BRANCH:-master}"
USER_DOTFILES_BRANCH="${USER_DOTFILES_BRANCH:-master}"
STRAP_ISSUES_URL="https://github.com/daptiv/strap/issues/new"

STRAP_FULL_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

abort() { STRAP_STEP="";   echo "!!! $*" >&2; exit 1; }
log()   { STRAP_STEP="$*"; echo "--> $*"; }
logn()  { STRAP_STEP="$*"; printf -- "--> %s " "$*"; }
logk()  { STRAP_STEP="";   echo "OK"; }

sw_vers -productVersion | grep $Q -E "^10.(9|10|11|12|13)" || {
  abort "Run Strap on macOS 10.9/10/11/12/13."
}

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
groups | grep $Q admin || abort "Add $USER to the admin group."


# Initialise sudo now to save prompting later.
log "Enter your password (for sudo access):"
sudo -k
sudo /usr/bin/true
[ -f "$STRAP_FULL_PATH" ]
sudo bash "$STRAP_FULL_PATH" --sudo-wait &
STRAP_SUDO_WAIT_PID="$!"
ps -p "$STRAP_SUDO_WAIT_PID" &>/dev/null
logk

# Add user to staff group
if ! groups | grep $Q staff; then
  sudo dseditgroup -o edit -a "$USER" -t user staff
fi

# Set some basic security settings.
logn "Configuring security settings:"
defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled \
  -bool false
defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles \
  -bool false
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null

# Set login window text
if [ -n "$STRAP_CONTACT_PHONE" ]; then
  sudo defaults write /Library/Preferences/com.apple.loginwindow \
    LoginwindowText \
    "Found this computer? Please call $STRAP_CONTACT_PHONE."
fi
logk

# Check and enable full-disk encryption.
logn "Checking full-disk encryption status:"
if fdesetup status | grep $Q -E "FileVault is (On|Off, but will be enabled after the next restart)."; then
  logk
elif [ -n "$STRAP_CI" ]; then
  echo
  logn "Skipping full-disk encryption for CI"
elif [ -n "$STRAP_INTERACTIVE" ]; then
  echo
  log "Enabling full-disk encryption on next reboot:"
  sudo fdesetup enable -user "$USER" \
    | tee ~/Desktop/"FileVault Recovery Key.txt"
  logk
else
  echo
  abort "Run 'sudo fdesetup enable -user \"$USER\"' to enable full-disk encryption."
fi

# Install the Xcode Command Line Tools.
DEVELOPER_DIR=$("xcode-select" -print-path 2>/dev/null || true)
if [ -z "$DEVELOPER_DIR" ] || ! [ -f "$DEVELOPER_DIR/usr/bin/git" ] \
                           || ! [ -f "/usr/include/iconv.h" ]
then
  log "Installing the Xcode Command Line Tools:"
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$CLT_PLACEHOLDER"
  CLT_PACKAGE=$(softwareupdate -l | \
                grep -B 1 -E "Command Line (Developer|Tools)" | \
                awk -F"*" '/^ +\*/ {print $2}' | sed 's/^ *//' | head -n1)
  sudo softwareupdate -i "$CLT_PACKAGE"
  sudo rm -f "$CLT_PLACEHOLDER"
  if ! [ -f "/usr/include/iconv.h" ]; then
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
      sudo xcodebuild -license
      logk
    else
      abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
    fi
  fi
}
xcode_license

# Setup Git configuration.
logn "Configuring Git:"
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
if git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain"
then
  if [ "$(git config --global credential.helper)" != "osxkeychain" ]
  then
    git config --global credential.helper osxkeychain
  fi

  if [ -n "$STRAP_GITHUB_USER" ] && [ -n "$STRAP_GITHUB_TOKEN" ]
  then
    printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase
    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" \
          "$STRAP_GITHUB_USER" "$STRAP_GITHUB_TOKEN" \
          | git credential-osxkeychain store
  fi
fi

# add ssh key to github
if ! [ -f "$HOME/.ssh/id_rsa" ]; then
  ssh-keygen -t rsa -b 4096 -C "$STRAP_GIT_EMAIL" -N "" -f "$HOME/.ssh/id_rsa"
  eval "$(ssh-agent -s)"
  ssh-add -K ~/.ssh/id_rsa

  PUBLIC_KEY="$(cat $HOME/.ssh/id_rsa.pub)"
  POST_BODY="{\"title\":\"MacOSX Key - strap\",\"key\":\"$PUBLIC_KEY\"}"
  curl $Q -H "Content-Type: application/json" -H "Authorization: token $STRAP_GITHUB_TOKEN" -X POST -d "$POST_BODY" https://api.github.com/user/keys
fi

logk

# Setup Homebrew directory and permissions.
logn "Installing Homebrew:"
HOMEBREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
[ -n "$HOMEBREW_PREFIX" ] || HOMEBREW_PREFIX="/usr/local"
[ -d "$HOMEBREW_PREFIX" ] || sudo mkdir -p "$HOMEBREW_PREFIX"
if [ "$HOMEBREW_PREFIX" = "/usr/local" ]
then
  sudo chown "root:wheel" "$HOMEBREW_PREFIX" 2>/dev/null || true
fi
(
  cd "$HOMEBREW_PREFIX"
  sudo mkdir -p               Cellar Frameworks bin etc include lib opt sbin share var
  sudo chown -R "$USER:admin" Cellar Frameworks bin etc include lib opt sbin share var
)

# Download Homebrew.
HOMEBREW_REPOSITORY="$(brew --repository 2>/dev/null || true)"
[ -n "$HOMEBREW_REPOSITORY" ] || HOMEBREW_REPOSITORY="/usr/local/Homebrew"
[ -d "$HOMEBREW_REPOSITORY" ] || sudo mkdir -p "$HOMEBREW_REPOSITORY"
sudo chown -R "$USER:admin" "$HOMEBREW_REPOSITORY"

if ! [ -d "$HOMEBREW_REPOSITORY/.git" ] ; then
  git clone --depth=1 https://github.com/Homebrew/brew.git "$HOMEBREW_REPOSITORY"

  cd "$HOMEBREW_REPOSITORY"
  git fetch --tags --depth=1
  git checkout 1.3.2
fi

if [ $HOMEBREW_PREFIX != $HOMEBREW_REPOSITORY ]
then
  ln -sf "$HOMEBREW_REPOSITORY/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
fi

logk

# Update Homebrew.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
log "Updating Homebrew:"
brew update
logk

# Install Homebrew Bundle, Cask and Services tap.
log "Installing Homebrew taps and extensions:"
brew bundle --file=- <<EOF
tap 'caskroom/cask'
tap 'homebrew/core'
tap 'homebrew/services'
EOF
logk

# Check and install any remaining software updates.
logn "Checking for software updates:"
if softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  logk
else
  echo
  log "Installing software updates:"
  if [ -z "$STRAP_CI" ]; then
    sudo softwareupdate --install --all
    xcode_license
  else
    echo "Skipping software updates for CI"
  fi
  logk
fi

# Halt if requested before Daptiv-specific setup
if [ -n "$EXIT_BEFORE_DAPTIV" ]; then
  log "You requested exit before Daptiv-specific setup. Strap process not completed."
  STRAP_SUCCESS=1
  exit
fi

# Setup Daptiv dotfiles
DOTFILES_URL="https://github.com/daptiv/dotfiles"
DOTFILES_DIR="$HOME/.daptiv-dotfiles"
if git ls-remote "$DOTFILES_URL" &>/dev/null; then
  log "Fetching daptiv/dotfiles from GitHub:"
  if [ ! -d "$DOTFILES_DIR" ]; then
    log "Cloning to $DOTFILES_DIR:"
    git clone $Q "$DOTFILES_URL" "$DOTFILES_DIR"
  else
    (
      cd "$DOTFILES_DIR"
      git pull $Q --rebase --autostash
    )
  fi
  (
    cd "$DOTFILES_DIR"
    CURRENT_DAPTIV_DOTFILES_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$DAPTIV_DOTFILES_BRANCH" != "$CURRENT_DAPTIV_DOTFILES_BRANCH" ]; then
      # check to make sure there are no pending changes in current branch
      if git diff-index --quiet HEAD -- ; then
        log "Changing branch from '$CURRENT_DAPTIV_DOTFILES_BRANCH' to '$DAPTIV_DOTFILES_BRANCH'"
        git checkout $DAPTIV_DOTFILES_BRANCH
        git pull $Q --rebase --autostash
      else
        abort "Pending changes in $DOTFILES_DIR, unable to switch to branch: $DAPTIV_DOTFILES_BRANCH. If you want to run in this branch run strap with: DAPTIV_DOTFILES_BRANCH=$CURRENT_DAPTIV_DOTFILES_BRANCH"
      fi
    fi

    for i in script/setup script/bootstrap; do
      if [ -f "$i" ] && [ -x "$i" ]; then
        log "Running dotfiles $i:"
        "$i" 2>/dev/null
        break
      fi
    done
  )
  logk
fi

# Uninstall non-Brew hostess
if [ "$GOPATH/go/bin/hostess" -ef /usr/local/bin/hostess ]; then
  log "Uninstalling non-Brew hostess"
  rm -f /usr/local/bin/hostess
  rm -f "$GOPATH/go/bin/hostess"
fi

# Check for broken cask installs
DAPTIV_DOTFILES="$HOME/.daptiv-dotfiles"
if [ -f "$DAPTIV_DOTFILES/script/fix-cask-installs.py" ]; then

  python "$DAPTIV_DOTFILES/script/fix-cask-installs.py" '.Daptiv.Brewfile' "${STRAP_DEBUG:+--debug}"
fi

# Install from Daptiv Brewfile
DAPTIV_BREWFILE="$HOME/.Daptiv.Brewfile"
DAPTIV_BREWFILE_BLACKLIST="$DAPTIV_BREWFILE.blacklist"
if [ -f "$DAPTIV_BREWFILE" ]; then
  log "Installing from Daptiv Brewfile:"
  if [ ! -f "$DAPTIV_BREWFILE_BLACKLIST" ]; then
    brew bundle check --file="$DAPTIV_BREWFILE" || brew bundle --file="$DAPTIV_BREWFILE"
  else
    log "Generating brewfile blacklist"
    while read BLACKLIST_LINE
    do
      if [ ! -z $BLACKLIST_REGEX ]; then BLACKLIST_REGEX+="|"; fi
      BLACKLIST_REGEX+="\"$BLACKLIST_LINE\""
    done < $DAPTIV_BREWFILE_BLACKLIST

    BREWFILE_CLEAN='/tmp/daptiv.brewfile.clean'
    log "Using clean brewfile: $BREWFILE_CLEAN"
    sed -E "/$BLACKLIST_REGEX/d" $DAPTIV_BREWFILE > $BREWFILE_CLEAN

    brew bundle check --file="$BREWFILE_CLEAN" || brew bundle --file="$BREWFILE_CLEAN"
  fi
  logk
fi

# Run postbrew script from daptiv dotfiles
if [ -f "$DAPTIV_DOTFILES/script/postbrew" ] && [ -x "$DAPTIV_DOTFILES/script/postbrew" ]; then
  "$DAPTIV_DOTFILES/script/postbrew" 2>/dev/null
fi

# Setup dotfiles
if [ -n "$STRAP_GITHUB_USER" ]; then
  DOTFILES_REPO="$STRAP_GITHUB_USER/dotfiles"
  if [ -n "$STRAP_CI" ]; then
    DOTFILES_REPO="daptiv/dotfiles-template"
  fi

  DOTFILES_URL="https://github.com/$DOTFILES_REPO"
  if git ls-remote "$DOTFILES_URL" &>/dev/null; then
    log "Fetching $DOTFILES_REPO from GitHub:"
    if [ ! -d "$HOME/.dotfiles" ]; then
      log "Cloning to ~/.dotfiles:"
      git clone $Q "$DOTFILES_URL" ~/.dotfiles
    else
      (
        cd ~/.dotfiles
        git pull $Q --rebase --autostash
      )
    fi
    (
      cd ~/.dotfiles
      CURRENT_USER_DOTFILES_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
      if [ "$USER_DOTFILES_BRANCH" != "$CURRENT_USER_DOTFILES_BRANCH" ]; then
        # check to make sure there are no pending changes in current branch
        if git diff-index --quiet HEAD -- ; then
          log "Changing branch from '$CURRENT_USER_DOTFILES_BRANCH' to '$USER_DOTFILES_BRANCH'"
          git checkout $USER_DOTFILES_BRANCH
          git pull $Q --rebase --autostash
        else
          abort "Pending changes in ~/.dotfiles, unable to switch to branch: $USER_DOTFILES_BRANCH. If you want to run in this branch run strap with: USER_DOTFILES_BRANCH=$CURRENT_USER_DOTFILES_BRANCH"
        fi
      fi
      for i in script/setup script/bootstrap; do
        if [ -f "$i" ] && [ -x "$i" ]; then
          log "Running dotfiles $i:"
          "$i" 2>/dev/null
          break
        fi
      done
    )
    logk
  fi
fi

# Check for broken cask installs in user brewfile
if [ -f "$DAPTIV_DOTFILES/script/fix-cask-installs.py" ]; then
  python "$DAPTIV_DOTFILES/script/fix-cask-installs.py" '.Brewfile' "${STRAP_DEBUG:+--debug}"
fi

# Setup User Brewfile
if [ -n "$STRAP_GITHUB_USER" ] && ! [ -f "$HOME/.Brewfile" ]; then
  HOMEBREW_BREWFILE_URL="https://github.com/$STRAP_GITHUB_USER/homebrew-brewfile"

  if git ls-remote "$HOMEBREW_BREWFILE_URL" &>/dev/null; then
    log "Fetching $STRAP_GITHUB_USER/homebrew-brewfile from GitHub:"
    if [ ! -d "$HOME/.homebrew-brewfile" ]; then
      log "Cloning to ~/.homebrew-brewfile:"
      git clone $Q "$HOMEBREW_BREWFILE_URL" ~/.homebrew-brewfile
      logk
    else
      (
        cd ~/.homebrew-brewfile
        git pull $Q
      )
    fi
    ln -sf ~/.homebrew-brewfile/Brewfile ~/.Brewfile
    logk
  fi
fi

# Install from local Brewfile
if [ -f "$HOME/.Brewfile" ]; then
  log "Installing from user Brewfile on GitHub:"
  brew bundle check --global || brew bundle --global
  logk
fi

# Run postbrew script from user dotfiles
USER_DOTFILES="$HOME/.dotfiles"
if [ -f "$USER_DOTFILES/script/postbrew" ] && [ -x "$USER_DOTFILES/script/postbrew" ]; then
  "$USER_DOTFILES/script/postbrew" 2>/dev/null
fi

STRAP_SUCCESS="1"
log "Your system is now Strap'd!"
