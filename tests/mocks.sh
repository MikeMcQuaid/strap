#!/bin/bash

log() { echo "$*"; }
logn() { echo "$*"; }
logk() { :; }
logskip() { echo "$*"; }
abort() {
  echo "$*" >&2
  exit 1
}
test() {
  if [[ $1 == -t ]]; then
    [[ ${STRAP_TEST_TTY-0} == 1 ]]
  else
    builtin test "$@"
  fi
}
defaults() {
  if [ "$1" = read ]; then
    case "$2/$3" in
    com.apple.screensaver/askForPassword | /Library/Preferences/com.apple.alf/globalstate)
      [ "${STRAP_TEST_SECURITY_MATCH-0}" = 1 ] || return 1
      echo 1
      ;;
    com.apple.screensaver/askForPasswordDelay)
      [ "${STRAP_TEST_SECURITY_MATCH-0}" = 1 ] || return 1
      echo 0
      ;;
    /Library/Preferences/com.apple.loginwindow/LoginwindowText) printf '%s\n' "${STRAP_TEST_LOGIN_TEXT-}" ;;
    *) return 1 ;;
    esac
  else
    printf 'defaults'
    printf ' <%s>' "$@"
    echo
  fi
}
launchctl() { [ "$*" = 'print system/com.apple.alf' ] && [ "${STRAP_TEST_FIREWALL_LOADED-0}" = 1 ]; }
brew() { echo "brew $*"; }
softwareupdate() { echo 'No new software available.'; }
ln() { :; }
run_dotfile_scripts() { :; }
sudo_askpass() {
  printf 'sudo'
  printf ' <%s>' "$@"
  echo
}
command() {
  if [ "$*" = "-v gh" ]; then
    [ "${STRAP_TEST_GH_INSTALLED-1}" = 1 ]
  else
    builtin command "$@"
  fi
}
git() {
  if [ "$1" = ls-remote ]; then
    [ "${STRAP_TEST_CREDENTIALS_READY-0}" = 1 ]
  elif [[ $* == *"credential fill" ]]; then
    [ -n "${STRAP_TEST_GIT_CONFIG-}" ] || return 1
    env GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$STRAP_TEST_GIT_CONFIG" \
      git -C "${STRAP_TEST_GIT_CONFIG%/*}" "$@" || return 1
    STRAP_TEST_CREDENTIALS_READY=1
  elif [ "$1" = config ] && [ "$2" != --global ]; then
    case "$2" in
    user.name) [ -n "${STRAP_TEST_GIT_NAME-}" ] && echo "$STRAP_TEST_GIT_NAME" ;;
    user.email) [ -n "${STRAP_TEST_GIT_EMAIL-}" ] && echo "$STRAP_TEST_GIT_EMAIL" ;;
    github.user) [ -n "${STRAP_TEST_GITHUB_USER-}" ] && echo "$STRAP_TEST_GITHUB_USER" ;;
    *) return 1 ;;
    esac
  else
    printf 'git'
    printf ' <%s>' "$@"
    echo
  fi
}
gh() {
  echo "gh $*" >&2
  case "$1 $2" in
  'auth status') [ "${STRAP_TEST_AUTHENTICATED-1}" = 1 ] ;;
  'auth login')
    [ "${STRAP_TEST_LOGIN_FAIL-0}" = 0 ] || return 1
    STRAP_TEST_AUTHENTICATED=1
    ;;
  'auth setup-git') STRAP_TEST_CREDENTIALS_READY=1 ;;
  'api user')
    [ "${STRAP_TEST_API_FAIL-0}" = 0 ] || return 1
    case "$*" in
    *login*) echo octocat ;;
    *name*) echo 'Mona Octocat' ;;
    *) return 1 ;;
    esac
    ;;
  'api user/emails')
    [ "${STRAP_TEST_EMAIL_FAIL-0}" = 0 ] || return 1
    echo mona@example.com
    ;;
  *)
    echo "Unexpected gh invocation" >&2
    return 1
    ;;
  esac
}
