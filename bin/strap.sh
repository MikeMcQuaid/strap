#!/bin/bash
#/ Usage: bin/strap.sh [--debug]
#/ Install development dependencies on macOS.
set -e

RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
OCHRE="\033[38;5;95m"
BLUE="\033[0;34m"
WHITE="\033[0;37m"
RESET="\033[0m"

# Keep sudo timestamp updated while Strap is running.
if [ "$1" = "--sudo-wait" ]; then
  while true; do
    mkdir -p "/var/db/sudo/$SUDO_USER"
    touch "/var/db/sudo/$SUDO_USER"
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
    *)
      echo "Unknown command line option: $1"
      exit 1
      ;;
  esac
done

STRAP_SUCCESS=""

cleanup() {
  set +e
  if [ -n "$STRAP_SUDO_WAIT_PID" ]; then
    sudo kill "$STRAP_SUDO_WAIT_PID"
  fi
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

# used by CI build, not set by web/app.rb
# DOCKER_USERNAME=
# DOCKER_PASSWORD=

DAPTIV_DOTFILES_BRANCH="${DAPTIV_DOTFILES_BRANCH:-master}"
USER_DOTFILES_BRANCH="${USER_DOTFILES_BRANCH:-master}"
STRAP_ISSUES_URL='https://github.com/daptiv/strap/issues/new'

STRAP_FULL_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

abort()  { STRAP_STEP="";   echo "!!! $*" >&2; exit 1; }
log()    { STRAP_STEP="$*"; echo "--> $*"; }
logn()   { STRAP_STEP="$*"; printf -- "--> %s " "$*"; }
logk()   { STRAP_STEP="";   echo -e "${GREEN}✔${RESET}"; }
logdebug(){ STRAP_STEP="$*"; if [ -n "$STRAP_DEBUG" ]; then echo -e "\n$*" ; fi }

sw_vers -productVersion | grep $Q -E "^10.(9|10|11|12|13|14|15)" || {
  abort "Strap is only supported on macOS versions 10.9/10/11/12/13/14/15."
}

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
groups | grep $Q admin || abort "Add $USER to the admin group."


# Initialise sudo now to save prompting later.
echo "Enter your password (for sudo access):"
sudo /usr/bin/true
[ -f "$STRAP_FULL_PATH" ]
sudo bash "$STRAP_FULL_PATH" --sudo-wait &
STRAP_SUDO_WAIT_PID="$!"
ps -p "$STRAP_SUDO_WAIT_PID" &>/dev/null

# Add user to staff group
if ! groups | grep $Q staff; then
  sudo dseditgroup -o edit -a "$USER" -t user staff
fi

# Set some basic security settings.
logn "Configuring security settings..."
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
logn "Checking full-disk encryption status..."
if fdesetup status | grep $Q -E "FileVault is (On|Off, but will be enabled after the next restart)."; then
  logk
elif [ -n "$STRAP_CI" ]; then
  logdebug "Skipping full-disk encryption for CI"
elif [ -n "$STRAP_INTERACTIVE" ]; then
  logdebug "Enabling full-disk encryption on next reboot:"
  sudo fdesetup enable -user "$USER" \
    | tee ~/Desktop/"FileVault Recovery Key.txt"
  logk
else
  echo
  abort "Run 'sudo fdesetup enable -user \"$USER\"' to enable full-disk encryption."
fi

# Install the Xcode Command Line Tools.
logn "Install Xcode Command Line Tools..."
if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]
then
  logdebug "Installing the Xcode Command Line Tools:"
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$CLT_PLACEHOLDER"

  if [ -z "$MACOS_VERSION" ]; then
    MACOS_VERSION="$(defaults read loginwindow SystemVersionStampAsString)"
  fi

  # shellcheck disable=SC2086,SC2183
  printf -v MACOS_VERSION_NUMERIC "%02d%02d%02d" ${MACOS_VERSION//./ }
  if [ "$MACOS_VERSION_NUMERIC" -ge "100900" ] &&
     [ "$MACOS_VERSION_NUMERIC" -lt "101000" ]
  then
    CLT_MACOS_VERSION="Mavericks"
  else
    CLT_MACOS_VERSION="$(echo "$MACOS_VERSION" | grep -E -o "10\\.\\d+")"
  fi
  if [ "$MACOS_VERSION_NUMERIC" -ge "101300" ]
  then
    CLT_SORT="sort -V"
  else
    CLT_SORT="sort"
  fi

  CLT_PACKAGE=$(softwareupdate -l | \
                grep -B 1 -E "Command Line (Developer|Tools)" | \
                awk -F"*" '/^ +\*/ {print $2}' | \
                sed 's/^ *//' | \
                grep "$CLT_MACOS_VERSION" |
                $CLT_SORT |
                tail -n1)
  sudo softwareupdate -i "$CLT_PACKAGE"
  sudo rm -f "$CLT_PLACEHOLDER"
  if ! [ -f "/Library/Developer/CommandLineTools/usr/bin/git" ]
  then
    if [ -n "$STRAP_INTERACTIVE" ]; then
      logdebug "Requesting user install of Xcode Command Line Tools:"
      xcode-select --install
    else
      echo
      abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
    fi
  fi
fi
logk

# Check if the Xcode license is agreed to and agree if not.
xcode_license() {
  if /usr/bin/xcrun clang 2>&1 | grep $Q license; then
    if [ -n "$STRAP_INTERACTIVE" ]; then
      logn "Asking for Xcode license confirmation..."
      sudo xcodebuild -license
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
logk

# Setup GitHub HTTPS credentials.
logn "Setting up GitHub HTTPS credentials..."
if git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain" ; then
  if [ "$(git config --global credential.helper)" != "osxkeychain" ]; then
    logdebug "setting git credential helper to osxkeychain"
    git config --global credential.helper osxkeychain
  fi

  if [ -n "$STRAP_GITHUB_USER" ] && [ -n "$STRAP_GITHUB_TOKEN" ]; then
    logdebug "storing https credentials for github"
    printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase
    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" \
          "$STRAP_GITHUB_USER" "$STRAP_GITHUB_TOKEN" \
          | git credential-osxkeychain store
  fi
fi
logk

# add ssh key to github
logn "Setting up GitHub SSH key..."
if ! [ -f "$HOME/.ssh/id_rsa" ]; then
  logdebug 'adding ssh key to github'
  ssh-keygen -t rsa -b 4096 -C "$STRAP_GIT_EMAIL" -N "" -f "$HOME/.ssh/id_rsa"
  eval "$(ssh-agent -s)"
  ssh-add -K ~/.ssh/id_rsa

  PUBLIC_KEY="$(cat $HOME/.ssh/id_rsa.pub)"
  POST_BODY="{\"title\":\"MacOSX Key - strap\",\"key\":\"$PUBLIC_KEY\"}"
  curl $Q -H "Content-Type: application/json" -H "Authorization: token $STRAP_GITHUB_TOKEN" -X POST -d "$POST_BODY" https://api.github.com/user/keys

  logdebug "checking for known_hosts file"
  if ! [ -f "$HOME/.ssh/known_hosts"]; then
    logdebug  "creating known_hosts file"
    touch ~/.ssh/known_hosts
    chmod 644 ~/.ssh/known_hosts
  fi

  logdebug "ensure github.com is a known host"
  if [ `ssh-keygen -H -F github.com | wc -l` = 0 ]; then
    ssh-keyscan -H github.com >> ~/.ssh/known_hosts
  fi
fi

logk

# Setup Homebrew directory and permissions.
logn "Check for Homebrew..."
if ! type brew 1>/dev/null 2>&1 ; then
  logdebug "Installing Homebrew"
  BREW_INSTALL_SCRIPT="/tmp/brew-install.rb"
  curl -fsSL --output $BREW_INSTALL_SCRIPT https://raw.githubusercontent.com/Homebrew/install/master/install
  /usr/bin/ruby $BREW_INSTALL_SCRIPT
fi
logk

# Update Homebrew.
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
logn "Updating Homebrew..."
if [ -n "$STRAP_DEBUG" ]; then
  brew update
else
  brew update 1>/dev/null 2>&1
fi
logk

# Install Homebrew Bundle, Cask and Services tap.
logn "Installing Homebrew taps and extensions..."
if [ -n "$STRAP_DEBUG" ]; then
brew bundle --file=- <<EOF
tap 'homebrew/cask'
tap 'homebrew/core'
tap 'homebrew/services'
tap 'daptiv/homebrew-tap'
EOF
else
brew bundle --file=- 1>/dev/null 2>&1 <<EOF
tap 'homebrew/cask'
tap 'homebrew/core'
tap 'homebrew/services'
tap 'daptiv/homebrew-tap'
EOF
fi
logk

# Check and install any remaining software updates.
logn "Checking for software updates..."
if ! softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  logdebug "Installing software updates:"
  if [ -z "$STRAP_CI" ]; then
    sudo softwareupdate --install --all
    xcode_license
  else
    logdebug "Skipping software updates for CI"
  fi
fi
logk

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
USER_DOTFILES_EXISTS=
if [ -n "$STRAP_GITHUB_USER" ]; then
  DOTFILES_REPO="$STRAP_GITHUB_USER/dotfiles"
  if [ -n "$STRAP_CI" ]; then
    DOTFILES_REPO="daptiv/dotfiles-template"
  fi

  DOTFILES_URL="git@github.com:$DOTFILES_REPO"
  logn "Checking for remotes on $DOTFILES_URL..."
  if git ls-remote "$DOTFILES_URL" &>/dev/null; then USER_DOTFILES_EXISTS=1; fi
  logk
  if [ -n "$USER_DOTFILES_EXISTS" ]; then
    logn "Fetching $DOTFILES_REPO from GitHub..."
    if [ ! -d "$HOME/.dotfiles" ]; then
      logdebug "Cloning to ~/.dotfiles..."
      git clone $Q "$DOTFILES_URL" ~/.dotfiles
    else
      (
        cd ~/.dotfiles
        git pull $Q --rebase --autostash
      )
    fi
    logk
    (
      logn "Updating local ~/.dotfiles repository..."
      cd ~/.dotfiles
      CURRENT_USER_DOTFILES_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
      if [ "$USER_DOTFILES_BRANCH" != "$CURRENT_USER_DOTFILES_BRANCH" ]; then
        # check to make sure there are no pending changes in current branch
        if git diff-index --quiet HEAD -- ; then
          logdebug "Changing branch from '$CURRENT_USER_DOTFILES_BRANCH' to '$USER_DOTFILES_BRANCH'"
          git checkout $USER_DOTFILES_BRANCH
          git pull $Q --rebase --autostash
        else
          abort "Pending changes in ~/.dotfiles, unable to switch to branch: $USER_DOTFILES_BRANCH. If you want to run in this branch run strap with: USER_DOTFILES_BRANCH=$CURRENT_USER_DOTFILES_BRANCH"
        fi
      fi
      logk
    )
  else
    log "Couldn't get remotes for $DOTFILES_URL"
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

  for i in script/setup script/bootstrap; do
    if [ -f "$i" ] && [ -x "$i" ]; then
      logn "Running dotfiles $i..."
      "$i" 1>/dev/null 2>&1
      logk
      break
    fi
  done
)

STRAP_SUCCESS="1"
echo -e "${GREEN}Box strap is complete."
echo -e "Next steps:"
echo -e "1. run 'strap-daptiv' to run daptiv-dotfiles scripts/setup"
echo -e "2. run 'strap-user' to run user dotfiles scripts/setup${RESET}"
