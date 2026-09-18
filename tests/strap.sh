#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

for variable in "${!STRAP_@}" "${!GH_@}" "${!GITHUB_@}"; do
  unset "$variable"
done

STRAP_TEST_DIR=$(mktemp -d)
trap 'rm -rf "$STRAP_TEST_DIR"' EXIT
STRAP_TEST_COUNT=0

# Run argument parsing and post-Homebrew setup with all system changes mocked.
awk '/^STRAP_SUCCESS=""$/ { exit } { print }' bin/strap.sh >"$STRAP_TEST_DIR/setup.sh"
cat tests/mocks.sh >>"$STRAP_TEST_DIR/setup.sh"
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
sed -n '/^log() {/,/^}/p; /^logn() {/,/^}/p' bin/strap.sh >"$STRAP_TEST_DIR/log.sh"
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

test_case "Login-screen sudo follows the update check and its own heading"
run_setup
assert_status 0
[[ $(<"$STRAP_TEST_DIR/stdout") == *"Checking for software updates:"*"Configuring login-screen message:"$'\nsudo <defaults>'* ]] ||
  fail "Expected the software-update check and login-screen heading before sudo"

test_case "Existing login populates identity and Git credentials"
run_setup
assert_status 0
assert_contains stderr 'gh auth setup-git --hostname github.com'
assert_contains stdout 'git <config> <--global> <user.name> <Mona Octocat>'
assert_contains stdout 'git <config> <--global> <user.email> <mona@example.com>'
assert_contains stdout 'git <config> <--global> <github.user> <octocat>'
assert_contains stdout 'Found this computer? Please contact Mona Octocat at mona@example.com.'
assert_absent stderr 'auth login'
assert_contains stdout 'Fetching octocat/dotfiles from GitHub'

test_case "Flags override environment without authentication"
STRAP_GIT_NAME=Ignored STRAP_GIT_EMAIL=ignored@example.com STRAP_GITHUB_USER=ignored \
  run_setup --no-github --git-name "O'Connor \$(false)" --git-email chosen@example.com --github-user chosen
assert_status 0
assert_absent stderr 'gh '
assert_contains stdout "<user.name> <O'Connor \$(false)>"
assert_contains stdout '<user.email> <chosen@example.com>'
assert_contains stdout '<github.user> <chosen>'

test_case "Environment can skip GitHub and supply identity"
STRAP_NO_GITHUB=1 STRAP_GIT_NAME=Manual STRAP_GIT_EMAIL=manual@example.com STRAP_GITHUB_USER=manual run_setup
assert_status 0
assert_absent stderr 'gh '
assert_absent stdout 'brew install gh'
assert_contains stdout '<github.user> <manual>'

test_case "Skip flags override supplied and existing profile values"
STRAP_GIT_NAME=Supplied STRAP_GIT_EMAIL=supplied@example.com STRAP_GITHUB_USER=supplied \
  STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com \
  run_setup --no-git-name --no-git-email --no-github-user
assert_status 0
assert_absent stderr 'gh api'
assert_absent stdout 'git <config> <--global>'
assert_absent stdout 'LoginwindowText'
assert_absent stdout 'Fetching '

test_case "Environment can skip supplied and existing profile values"
STRAP_NO_GIT_NAME=1 STRAP_NO_GIT_EMAIL=1 STRAP_NO_GITHUB_USER=1 \
  STRAP_GIT_NAME=Supplied STRAP_GIT_EMAIL=supplied@example.com STRAP_GITHUB_USER=supplied \
  STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com run_setup
assert_status 0
assert_absent stderr 'gh api'
assert_absent stdout 'git <config> <--global>'
assert_absent stdout 'LoginwindowText'
assert_absent stdout 'Fetching '

test_case "Each skip flag leaves other fields enabled"
for field in git-name git-email github-user; do
  run_setup "--no-$field"
  assert_status 0
  case "$field" in
  git-name)
    assert_absent stdout '<user.name>'
    assert_contains stdout '<user.email> <mona@example.com>'
    assert_contains stdout '<github.user> <octocat>'
    assert_absent stderr '--jq .name'
    assert_absent stdout 'LoginwindowText'
    ;;
  git-email)
    assert_contains stdout '<user.name> <Mona Octocat>'
    assert_absent stdout '<user.email>'
    assert_contains stdout '<github.user> <octocat>'
    assert_absent stderr 'gh api user/emails'
    assert_absent stdout 'LoginwindowText'
    ;;
  github-user)
    assert_contains stdout '<user.name> <Mona Octocat>'
    assert_contains stdout '<user.email> <mona@example.com>'
    assert_absent stdout '<github.user>'
    assert_absent stderr '--jq .login'
    assert_absent stdout 'Fetching '
    ;;
  *) fail "Unexpected field: $field" ;;
  esac
done

test_case "Value flags override environment skips"
STRAP_NO_GIT_NAME=1 STRAP_NO_GIT_EMAIL=1 STRAP_NO_GITHUB_USER=1 \
  run_setup --git-name Chosen --git-email chosen@example.com --github-user chosen
assert_status 0
assert_contains stdout '<user.name> <Chosen>'
assert_contains stdout '<user.email> <chosen@example.com>'
assert_contains stdout '<github.user> <chosen>'

test_case "The last flag for a field wins"
run_setup --no-git-name --git-name Chosen --no-git-email --git-email chosen@example.com \
  --no-github-user --github-user chosen
assert_status 0
assert_contains stdout '<user.name> <Chosen>'
assert_contains stdout '<user.email> <chosen@example.com>'
assert_contains stdout '<github.user> <chosen>'
run_setup --git-name Chosen --no-git-name --git-email chosen@example.com --no-git-email \
  --github-user chosen --no-github-user
assert_status 0
assert_absent stderr 'gh api'
assert_absent stdout 'git <config> <--global>'

test_case "Empty environment values fall back to existing Git and GitHub"
STRAP_GIT_NAME='' STRAP_GIT_EMAIL='' STRAP_GITHUB_USER='' \
  STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com run_setup
assert_status 0
assert_contains stdout 'Found this computer? Please contact Existing at existing@example.com.'
assert_contains stdout '<github.user> <octocat>'

test_case "Zero-valued environment skips leave profile lookup enabled"
STRAP_NO_GIT_NAME=0 STRAP_NO_GIT_EMAIL=0 STRAP_NO_GITHUB_USER=0 run_setup
assert_status 0
assert_contains stdout '<user.name> <Mona Octocat>'
assert_contains stdout '<user.email> <mona@example.com>'
assert_contains stdout '<github.user> <octocat>'

test_case "Explicit values override existing Git identity"
STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com \
  run_setup --no-github --git-name Chosen --git-email chosen@example.com
assert_status 0
assert_contains stdout '<user.name> <Chosen>'
assert_contains stdout '<user.email> <chosen@example.com>'

test_case "Existing Git identity is preserved"
STRAP_TEST_GIT_NAME=Existing STRAP_TEST_GIT_EMAIL=existing@example.com run_setup
assert_status 0
assert_absent stdout '<user.name>'
assert_absent stdout '<user.email>'
assert_absent stderr 'gh api user/emails'

test_case "Interactive login installs gh and requests email scope"
STRAP_TEST_INPUT=$'y\n' STRAP_INTERACTIVE=1 STRAP_TEST_GH_INSTALLED=0 STRAP_TEST_AUTHENTICATED=0 run_setup
assert_status 0
assert_contains stdout 'brew install gh'
assert_contains stderr 'gh auth login --hostname github.com --git-protocol https --web --scopes user:email'
assert_contains stdout '<github.user> <octocat>'

test_case "Login does not request email access when email is skipped or supplied"
for skip in 0 1; do
  STRAP_TEST_INPUT=$'y\n' STRAP_INTERACTIVE=1 STRAP_TEST_AUTHENTICATED=0 \
    STRAP_NO_GIT_EMAIL="$skip" STRAP_GIT_EMAIL=chosen@example.com run_setup
  assert_status 0
  assert_contains stderr 'gh auth login --hostname github.com --git-protocol https --web'
  assert_absent stderr '--scopes user:email'
  assert_absent stderr 'gh api user/emails'
done

test_case "Declining login skips installation and profile"
STRAP_TEST_INPUT=$'n\n' STRAP_INTERACTIVE=1 STRAP_TEST_GH_INSTALLED=0 run_setup
assert_status 0
assert_absent stdout 'brew install gh'
assert_absent stderr 'gh api'

test_case "EOF at login prompt skips authentication"
STRAP_INTERACTIVE=1 STRAP_TEST_AUTHENTICATED=0 run_setup
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

test_case "Unattended and CI runs never launch login"
for ci in "" 1; do
  STRAP_CI="$ci" STRAP_INTERACTIVE="$ci" STRAP_TEST_AUTHENTICATED=0 run_setup
  assert_status 0
  assert_absent stderr 'auth login'
  assert_absent stderr 'gh api'
done

test_case "Failed login can continue without GitHub"
STRAP_TEST_INPUT=$'y\n' STRAP_INTERACTIVE=1 STRAP_TEST_AUTHENTICATED=0 STRAP_TEST_LOGIN_FAIL=1 run_setup
assert_status 0
assert_absent stderr 'gh api'

test_case "Profile errors do not abort installation"
STRAP_TEST_API_FAIL=1 STRAP_TEST_EMAIL_FAIL=1 run_setup
assert_status 0
assert_absent stdout 'git <config> <--global>'

test_case "Invalid arguments fail before installation"
for argument in --unknown --git-name --git-email; do
  if [ "$argument" = --git-email ]; then
    run_setup "$argument" --no-github
  else
    run_setup "$argument"
  fi
  assert_status 1
  assert_absent stdout 'brew '
done

test_case "Empty flag values require explicit skip flags"
for argument in --git-name --git-email --github-user; do
  run_setup "$argument" ""
  assert_status 1
  assert_contains stderr "--no-${argument#--}"
  assert_absent stdout 'brew '
done

test_case "Help does not install anything"
run_setup --help
assert_status 0
assert_contains stdout '--no-github'
assert_contains stdout '--no-git-name'
assert_contains stdout '--no-git-email'
assert_contains stdout '--no-github-user'
assert_contains stdout 'STRAP_NO_GIT_EMAIL=1'
assert_absent stdout 'brew update'

echo "$STRAP_TEST_COUNT tests passed."
