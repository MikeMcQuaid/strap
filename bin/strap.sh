#!/bin/bash
#/ Usage: bin/strap.sh [--debug]
#/ Install development dependencies on Mac OS X.
set -e

[ "$1" = "--debug" ] && STRAP_DEBUG="1"

if [ -n "$STRAP_DEBUG" ]; then
  set -x
else
  STRAP_QUIET_FLAG="-q"
  Q="$STRAP_QUIET_FLAG"
fi

STDIN_FILE_DESCRIPTOR="0"
[ -t "$STDIN_FILE_DESCRIPTOR" ] && STRAP_INTERACTIVE="1"

STRAP_GIT_NAME=
STRAP_GIT_EMAIL=
STRAP_GITHUB_USER=
STRAP_GITHUB_TOKEN=

abort() { echo "!!! $@" >&2; exit 1; }
log()   { echo "--> $@"; }
logn()  { printf -- "--> $@ "; }
logk()  { echo "OK"; }

sw_vers -productVersion | grep $Q -E "^10.(9|10|11)" || {
  abort "Run Strap on Mac OS X 10.9/10/11."
}

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
groups | grep $Q admin || abort "Add $USER to the admin group."

# Initialise sudo now to save prompting later.
log "Enter your password (for sudo access):"
sudo -k
sudo /usr/bin/true
logk

# Install the Xcode Command Line Tools if Xcode isn't installed.
DEVELOPER_DIR=$("xcode-select" -print-path 2>/dev/null || true)
[ -z "$DEVELOPER_DIR" ] || ! [ -f "$DEVELOPER_DIR/usr/bin/git" ] && {
  log "Installing the Xcode Command Line Tools:"
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$CLT_PLACEHOLDER"
  CLT_PACKAGE=$(softwareupdate -l | \
                grep -B 1 -E "Command Line (Developer|Tools)" | \
                awk -F"*" '/^ +\*/ {print $2}' | sed 's/^ *//' | head -n1)
  sudo softwareupdate -i "$CLT_PACKAGE"
  sudo rm -f "$CLT_PLACEHOLDER"
  logk
}

# Check if the Xcode license is agreed to and agree if not.
/usr/bin/xcrun clang 2>&1 | grep $Q license && {
  if [ -n "$STRAP_INTERACTIVE" ]; then
    logn "Asking for Xcode license confirmation:"
    sudo xcodebuild -license
    logk
  else
    abort 'Run `sudo xcodebuild -license` to agree to the Xcode license.'
  fi
}

# Setup Git
logn "Configuring Git:"
if [ -n "$STRAP_GIT_NAME" ] && ! git config user.name >/dev/null; then
  git config --global user.name "$STRAP_GIT_NAME"
fi

if [ -n "$STRAP_GIT_EMAIL" ] && ! git config user.email >/dev/null; then
  git config --global user.email "$STRAP_GIT_EMAIL"
fi

if [ -n "$STRAP_GITHUB_USER" ] && [ -n "$STRAP_GITHUB_TOKEN" ] \
  && git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain"
then
  if [ "$(git config credential.helper)" != "osxkeychain" ]
  then
    git config --global credential.helper osxkeychain
  fi

  if [ -z "$(printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain get)" ]
  then
    printf "protocol=https\nhost=github.com\nusername=$STRAP_GITHUB_USER\npassword=$STRAP_GITHUB_TOKEN\n" \
      | git credential-osxkeychain store
  fi
fi
logk

# Setup Homebrew directories and permissions.
logn "Installing Homebrew:"
HOMEBREW_PREFIX="/usr/local"
HOMEBREW_CACHE="/Library/Caches/Homebrew"
for dir in "$HOMEBREW_PREFIX" "$HOMEBREW_CACHE"; do
  [ -d "$dir" ] || sudo mkdir -p "$dir"
  sudo chmod -R g+rwx "$dir"
done
sudo chgrp -R admin "$HOMEBREW_PREFIX" "$HOMEBREW_CACHE"
sudo chown root "$HOMEBREW_PREFIX"

# Download Homebrew.
export GIT_DIR="$HOMEBREW_PREFIX/.git" GIT_WORK_TREE="$HOMEBREW_PREFIX"
git init $Q
git config remote.origin.url "https://github.com/Homebrew/homebrew"
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git rev-parse --verify --quiet origin/master >/dev/null || {
  git fetch $Q origin master:refs/remotes/origin/master --no-tags --depth=1
  git reset $Q --hard origin/master
}
unset GIT_DIR GIT_WORK_TREE
logk

# Install Homebrew Bundle, Cask, Services and Versions tap.
log "Installing Homebrew taps and extensions:"
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
brew update
brew tap | grep -i $Q Homebrew/bundle || brew tap Homebrew/bundle
cat > /tmp/Brewfile.strap <<EOF
tap 'caskroom/cask'
tap 'homebrew/services'
tap 'homebrew/versions'
brew 'caskroom/cask/brew-cask'
EOF
brew bundle --file=/tmp/Brewfile.strap
rm -f /tmp/Brewfile.strap
logk

# Install suplemental brew packages if needed
if [ -f ./strap_homebrew_packages.list ]; then
  log "Found a homebrew package list, installing ..."
  
  packages=`cat ./strap_homebrew_packages`
  
  for i in $packages; do
    brew install $i
  done
fi

# Use pf packet filter to forward ports 80 and 443.
logn "Forwarding local ports 80 to 8080 and 443 to 8443:"
cat <<EOF | sudo tee /etc/pf.anchors/dev.strap >/dev/null
rdr pass inet proto tcp from any to any port 80 -> 127.0.0.1 port 8080
rdr pass inet proto tcp from any to any port 443 -> 127.0.0.1 port 8443
EOF
grep $Q "dev.strap" /etc/pf.conf || {
  sudo perl -pi \
    -e 's/(rdr-anchor.*)/\1\nrdr-anchor "dev.strap"/g;' \
    -e 's|(load anchor.*)|\1\nload anchor "dev.strap" from "/etc/pf.anchors/dev.strap"|g' \
    /etc/pf.conf
}
sudo pfctl -f /etc/pf.conf 2>/dev/null
sudo pfctl -e 2>/dev/null || true
logk

# Set some basic security settings.
logn "Configuring security settings:"
defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled \
  -bool false
defaults write com.apple.Safari \
  com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles \
  -bool false

if [ -n "$STRAP_GIT_NAME" ] && [ -n "$STRAP_GIT_EMAIL" ]; then
  sudo defaults write /Library/Preferences/com.apple.loginwindow \
    LoginwindowText \
    "Found this computer? Please contact $STRAP_GIT_NAME at $STRAP_GIT_EMAIL."
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
  logn "Enabling full-disk encryption on next reboot:"
  sudo fdesetup enable -user "$USER" \
    | tee ~/Desktop/"FileVault Recovery Key.txt"
  logk
else
  echo
  abort 'Run `sudo fdesetup enable -user "$USER"` to enable full-disk encryption.'
fi

# Check and install any remaining software updates.
logn "Checking for software updates:"
if softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  logk
else
  echo
  log "Installing software updates:"
  if [ -z "$STRAP_CI" ]; then
    sudo softwareupdate --install --all
  else
    echo "Skipping software updates for CI"
  fi
  logk
fi

# Revoke sudo access again.
sudo -k

log 'Finished! Install additional software with `brew install` and `brew cask install`.'
