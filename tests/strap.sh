#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

for variable in "${!STRAP_@}" "${!GH_@}" "${!GITHUB_@}"; do
  unset "$variable"
done
unset CI NONINTERACTIVE

STRAP_TEST_DIR=$(mktemp -d)
trap 'rm -rf "$STRAP_TEST_DIR"' EXIT
STRAP_TEST_COUNT=0

# Run argument parsing and post-Homebrew setup with all system changes mocked.
cat tests/mocks.sh >"$STRAP_TEST_DIR/setup.sh"
awk '/^STRAP_SUCCESS=""$/ { exit } { print }' bin/strap.sh >>"$STRAP_TEST_DIR/setup.sh"
sed -n '/^# Update Homebrew\./,$p' bin/strap.sh >>"$STRAP_TEST_DIR/setup.sh"

test_case() {
  STRAP_TEST_COUNT=$((STRAP_TEST_COUNT + 1))
  echo "Testing: $*"
}

fail() {
  echo "FAILED: $*" >&2
  cat "$STRAP_TEST_DIR/stdout" "$STRAP_TEST_DIR/stderr" >&2
  exit 1
}

assert_status() {
  [[ $STRAP_TEST_STATUS == "$1" ]] || fail "Expected status $1, got $STRAP_TEST_STATUS"
}

assert_contains() {
  [[ $(<"$STRAP_TEST_DIR/$1") == *"$2"* ]] || fail "Expected $1 to contain: $2"
}

assert_absent() {
  [[ $(<"$STRAP_TEST_DIR/$1") != *"$2"* ]] || fail "Expected $1 not to contain: $2"
}

run_setup() {
  local bash_options=(-e)
  if [ -n "${STRAP_DEBUG-}" ]; then
    bash_options+=(-x)
  fi
  STRAP_TEST_STATUS=0
  printf '%s' "${STRAP_TEST_INPUT-}" |
    /bin/bash "${bash_options[@]}" "$STRAP_TEST_DIR/setup.sh" "$@" \
      >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr" || STRAP_TEST_STATUS=$?
}

test_case "Dotfiles errors are visible and stop execution"
mkdir -p "$STRAP_TEST_DIR/dotfiles/script"
cat >"$STRAP_TEST_DIR/dotfiles/script/setup" <<'BASH'
#!/bin/bash
echo 'Missing homebrew/trust.json' >&2
exit 17
BASH
chmod 700 "$STRAP_TEST_DIR/dotfiles/script/setup"
sed -n '/^run_dotfile_scripts() {/,/^}/p' bin/strap.sh >"$STRAP_TEST_DIR/dotfiles.sh"
for debug in "" 1; do
  STRAP_TEST_STATUS=0
  STRAP_DEBUG="$debug" STRAP_TEST_DOTFILES="$STRAP_TEST_DIR/dotfiles" \
    /bin/bash -e -c '
      source "$1"
      log() { echo "$*"; }
      logk() { echo OK; }
      [() { [[ $1 == -d ]] || builtin [ "$@"; }
      cd() { builtin cd "$STRAP_TEST_DOTFILES"; }
      run_dotfile_scripts script/setup script/bootstrap
      echo continued
    ' strap-test "$STRAP_TEST_DIR/dotfiles.sh" \
    >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr" || STRAP_TEST_STATUS=$?
  assert_status 17
  assert_contains stderr 'Missing homebrew/trust.json'
  assert_contains stdout 'Running dotfiles script/setup:'
  assert_absent stdout 'OK'
  assert_absent stdout 'continued'
done

test_case "Step headings precede sudo prompts"
sed -n '/^log() {/,/^}/p; /^logn() {/,/^}/p; /^logk() {/,/^}/p' bin/strap.sh >"$STRAP_TEST_DIR/log.sh"
for logger in log logn; do
  /bin/bash -e -c '
    source "$1"
    sudo_refresh() { printf "Password: "; }
    "$2" "Checking for software updates:"
  ' strap-test "$STRAP_TEST_DIR/log.sh" "$logger" \
    >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr"
  if [ "$logger" = log ]; then
    assert_contains stdout $'--> Checking for software updates:\nPassword: '
  else
    assert_contains stdout '--> Checking for software updates: Password: '
  fi
done

test_case "Repository steps finish before hooks and report success once"
cat >"$STRAP_TEST_DIR/dotfiles/script/setup" <<'BASH'
#!/bin/bash
echo 'Dotfiles configured.'
BASH
sed -n '/^# Setup dotfiles$/,/^# Install from local Brewfile$/p' bin/strap.sh >"$STRAP_TEST_DIR/repositories.sh"
STRAP_TEST_DOTFILES="$STRAP_TEST_DIR/dotfiles" /bin/bash -e -c '
  source "$1/log.sh"
  source "$1/dotfiles.sh"
  sudo_refresh() { :; }
  git() {
    if [ "$1" = -C ]; then
      printf "Created autostash: b2925a7\nApplied autostash.\n"
    fi
  }
  ln() { :; }
  [() {
    case "$*" in
      "-d "*"/.dotfiles ]") return 0 ;;
      "! -d "*"/.dotfiles ]") return 1 ;;
      "! -f "*"/.Brewfile ]" | "! -d "*"/.homebrew-brewfile ]") return 0 ;;
      *) builtin [ "$@" ;;
    esac
  }
  cd() { builtin cd "$STRAP_TEST_DOTFILES"; }
  STRAP_GITHUB_USER=octocat
  source "$1/repositories.sh"
' strap-test "$STRAP_TEST_DIR" >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr"
assert_contains stdout $'--> Updating ~/.dotfiles:\nCreated autostash: b2925a7\nApplied autostash.\nOK\n--> Running dotfiles script/setup:\nDotfiles configured.\nOK'
assert_contains stdout $'--> Cloning to ~/.homebrew-brewfile:\nOK'
assert_absent stdout $'\nOK\nOK'

test_case "Matching security settings and a loaded firewall are left alone"
sed -n '/^defaults_write() {/,/^}/p' bin/strap.sh >"$STRAP_TEST_DIR/defaults.sh"
sed -n '/^# Set some basic security settings\./,/^# Check and enable full-disk encryption\./p' bin/strap.sh >"$STRAP_TEST_DIR/security.sh"
STRAP_TEST_SECURITY_MATCH=1 STRAP_TEST_FIREWALL_LOADED=1 /bin/bash -e -c '
  source tests/mocks.sh
  source "$1/defaults.sh"
  source "$1/security.sh"
' strap-test "$STRAP_TEST_DIR" >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr"
assert_absent stdout '<write>'
assert_absent stdout 'sudo'

test_case "Missing security settings are written in the correct preference domain"
/bin/bash -e -c '
  source tests/mocks.sh
  source "$1/defaults.sh"
  source "$1/security.sh"
' strap-test "$STRAP_TEST_DIR" >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr"
assert_contains stdout 'defaults <write> <com.apple.screensaver> <askForPassword> <-int> <1>'
assert_contains stdout 'defaults <write> <com.apple.screensaver> <askForPasswordDelay> <-int> <0>'
assert_absent stdout 'sudo <defaults> <write> <com.apple.screensaver>'
assert_contains stdout 'sudo <defaults> <write> </Library/Preferences/com.apple.alf> <globalstate> <-int> <1>'
assert_contains stdout 'sudo <launchctl> <load>'

test_case "Non-interactive sudo cannot launch a password prompt or askpass helper"
sed -n '/^sudo_askpass() {/,/^}/p' bin/strap.sh >"$STRAP_TEST_DIR/sudo.sh"
STRAP_INTERACTIVE='' SUDO_ASKPASS=/unused /bin/bash -e -c '
  source "$1"
  sudo() { printf "sudo"; printf " <%s>" "$@"; echo; }
  sudo_askpass defaults write example key value
' strap-test "$STRAP_TEST_DIR/sudo.sh" >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr"
assert_contains stdout 'sudo <--non-interactive> <defaults>'
assert_absent stdout '--askpass'

test_case "Cleanup only removes temporary files when they were created"
sed -n '/^cleanup() {/,/^}/p' bin/strap.sh >"$STRAP_TEST_DIR/cleanup.sh"
for placeholder in '' /tmp/strap-test-placeholder; do
  CLT_PLACEHOLDER="$placeholder" SUDO_ASKPASS='' SUDO_ASKPASS_DIR='' STRAP_SUCCESS=1 /bin/bash -e -c '
    source tests/mocks.sh
    source "$1"
    sudo() { :; }
    cleanup
  ' strap-test "$STRAP_TEST_DIR/cleanup.sh" >"$STRAP_TEST_DIR/stdout" 2>"$STRAP_TEST_DIR/stderr"
  if [ -n "$placeholder" ]; then
    assert_contains stdout "sudo <rm> <-rf> <$placeholder>"
  else
    assert_absent stdout 'sudo <rm>'
  fi
done

test_case "Login-screen sudo follows the update check and its own heading"
run_setup
assert_status 0
[[ $(<"$STRAP_TEST_DIR/stdout") == *"Checking for software updates:"*"Configuring login-screen message:"$'\nsudo <defaults>'* ]] ||
  fail "Expected the software-update check and login-screen heading before sudo"

test_case "An unchanged login-screen message is not written again"
STRAP_TEST_LOGIN_TEXT='Found this computer? Please contact Mona Octocat at mona@example.com.' run_setup
assert_status 0
assert_absent stdout 'LoginwindowText'
assert_absent stdout 'Configuring login-screen message:'

test_case "Names with parentheses and quotes remain literal and idempotent"
STRAP_GIT_NAME="O'Connor (Work) \$(false)" STRAP_GIT_EMAIL=chosen@example.com run_setup
assert_status 0
assert_contains stdout "<-string> <Found this computer? Please contact O'Connor (Work) \$(false) at chosen@example.com.>"
STRAP_GIT_NAME="O'Connor (Work) \$(false)" STRAP_GIT_EMAIL=chosen@example.com \
  STRAP_TEST_LOGIN_TEXT="Found this computer? Please contact O'Connor (Work) \$(false) at chosen@example.com." run_setup
assert_status 0
assert_absent stdout 'LoginwindowText'

test_case "Existing login populates identity and Git credentials"
run_setup
assert_status 0
assert_contains stderr 'gh auth setup-git --hostname github.com'
assert_contains stdout 'git <config> <--global> <user.name> <Mona Octocat>'
assert_contains stdout 'git <config> <--global> <user.email> <mona@example.com>'
assert_contains stdout 'git <config> <--global> <github.user> <octocat>'
assert_absent stderr 'auth login'
assert_contains stdout 'Fetching octocat/dotfiles from GitHub'

test_case "Working Git credential helpers are preserved without exposing credentials"
for helper in credential.helper credential.https://github.com.helper; do
  : >"$STRAP_TEST_DIR/gitconfig"
  git config --file "$STRAP_TEST_DIR/gitconfig" "$helper" '!f() { printf "username=octocat\npassword=secret-helper-token\n"; }; f'
  STRAP_TEST_GIT_CONFIG="$STRAP_TEST_DIR/gitconfig" STRAP_DEBUG=1 run_setup
  assert_status 0
  assert_absent stderr 'gh auth setup-git'
  assert_absent stdout 'secret-helper-token'
  assert_absent stderr 'secret-helper-token'
  assert_contains stdout 'Fetching octocat/dotfiles from GitHub'
done

test_case "A helper without credentials falls back to gh without invoking askpass"
: >"$STRAP_TEST_DIR/gitconfig"
git config --file "$STRAP_TEST_DIR/gitconfig" credential.helper '!false'
cat >"$STRAP_TEST_DIR/askpass" <<'BASH'
#!/bin/bash
touch "$(dirname "$0")/prompted"
exit 1
BASH
chmod 700 "$STRAP_TEST_DIR/askpass"
STRAP_TEST_GIT_CONFIG="$STRAP_TEST_DIR/gitconfig" GIT_ASKPASS="$STRAP_TEST_DIR/askpass" STRAP_DEBUG=1 run_setup
assert_status 0
assert_contains stderr 'gh auth setup-git --hostname github.com'
test ! -e "$STRAP_TEST_DIR/prompted"

test_case "Legacy environment values supply identity without authentication"
STRAP_TEST_AUTHENTICATED=0 STRAP_GIT_NAME=Manual STRAP_GIT_EMAIL=manual@example.com \
  STRAP_GITHUB_USER=manual run_setup --non-interactive
assert_status 0
assert_absent stderr 'gh api'
assert_absent stderr 'auth login'
assert_absent stdout 'brew install gh'
assert_contains stdout '<user.name> <Manual>'
assert_contains stdout '<user.email> <manual@example.com>'
assert_contains stdout '<github.user> <manual>'

test_case "Empty environment values fall back to existing Git and GitHub"
STRAP_GIT_NAME='' STRAP_GIT_EMAIL='' STRAP_GITHUB_USER='' \
  STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com run_setup
assert_status 0
assert_contains stdout 'Found this computer? Please contact Existing at existing@example.com.'
assert_contains stdout '<github.user> <octocat>'

test_case "Explicit environment values override existing Git identity"
STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com \
  STRAP_GIT_NAME=Chosen STRAP_GIT_EMAIL=chosen@example.com run_setup
assert_status 0
assert_contains stdout '<user.name> <Chosen>'
assert_contains stdout '<user.email> <chosen@example.com>'

test_case "Matching Git identity is preserved without redundant writes"
STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com STRAP_TEST_GITHUB_USER=octocat run_setup
assert_status 0
assert_absent stdout 'git <config> <--global>'
assert_absent stderr 'gh api user/emails'

test_case "Interactive login installs gh and requests email scope"
STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_GH_INSTALLED=0 STRAP_TEST_AUTHENTICATED=0 run_setup
assert_status 0
assert_contains stdout 'brew install gh'
assert_contains stderr 'gh auth login --hostname github.com --git-protocol https --web --scopes user:email'
assert_contains stdout '<github.user> <octocat>'

test_case "Login does not request email access when email is supplied"
STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 \
  STRAP_GIT_EMAIL=chosen@example.com run_setup
assert_status 0
assert_contains stderr 'gh auth login --hostname github.com --git-protocol https --web'
assert_absent stderr '--scopes user:email'
assert_absent stderr 'gh api user/emails'

test_case "Declining login skips installation and profile"
STRAP_TEST_INPUT=$'n\n' STRAP_TEST_TTY=1 STRAP_TEST_GH_INSTALLED=0 run_setup
assert_status 0
assert_absent stdout 'brew install gh'
assert_absent stderr 'gh api'

test_case "EOF at login prompt skips authentication"
STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 run_setup
assert_status 0
assert_absent stderr 'auth login'

test_case "Token authentication installs gh without prompting or exposing token"
STRAP_TEST_GH_INSTALLED=0 GH_TOKEN=secret-test-token STRAP_DEBUG=1 run_setup
assert_status 0
assert_contains stdout 'brew install gh'
assert_absent stderr 'auth login'
assert_contains stdout '<github.user> <octocat>'
assert_absent stdout 'secret-test-token'
assert_absent stderr 'secret-test-token'

test_case "Non-TTY input cannot enable interactive login"
STRAP_TEST_INPUT=$'y\n' STRAP_TEST_AUTHENTICATED=0 STRAP_INTERACTIVE=1 run_setup
assert_status 0
assert_absent stderr 'auth login'
assert_absent stderr 'gh api'

test_case "The non-interactive flag disables login even in a TTY"
STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 run_setup --non-interactive
assert_status 0
assert_absent stderr 'auth login'
assert_absent stderr 'gh api'

test_case "The non-interactive environment variable disables login even in a TTY"
STRAP_NONINTERACTIVE=1 STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 run_setup
assert_status 0
assert_absent stderr 'auth login'
assert_absent stderr 'gh api'

test_case "CI and legacy STRAP_CI disable interactive login in a TTY"
CI=1 STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 run_setup
assert_status 0
assert_absent stderr 'auth login'
assert_absent stderr 'gh api'
STRAP_CI=1 STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 run_setup
assert_status 0
assert_absent stderr 'gh '

test_case "CI=0 leaves a TTY interactive"
CI=0 STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 run_setup
assert_status 0
assert_contains stderr 'gh auth login'

test_case "Failed login can continue without GitHub"
STRAP_TEST_INPUT=$'y\n' STRAP_TEST_TTY=1 STRAP_TEST_AUTHENTICATED=0 STRAP_TEST_LOGIN_FAIL=1 run_setup
assert_status 0
assert_absent stderr 'gh api'

test_case "Profile errors do not abort installation"
STRAP_TEST_API_FAIL=1 STRAP_TEST_EMAIL_FAIL=1 run_setup
assert_status 0
assert_absent stdout 'git <config> <--global>'

test_case "Unknown arguments fail before installation"
run_setup --unknown
assert_status 1
assert_contains stderr 'Unknown option: --unknown'
assert_absent stdout 'brew '

test_case "Help lists options without starting installation"
run_setup --help
assert_status 0
assert_contains stdout '--non-interactive'
assert_contains stdout '--debug'
assert_contains stdout 'STRAP_GIT_NAME'
assert_contains stdout 'STRAP_GIT_EMAIL'
assert_contains stdout 'STRAP_GITHUB_USER'
assert_contains stdout 'STRAP_NONINTERACTIVE'
assert_absent stdout 'brew update'

echo "$STRAP_TEST_COUNT tests passed."
