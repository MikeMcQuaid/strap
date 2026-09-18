#!/bin/bash

log() { echo "$*"; }
logn() { echo "$*"; }
logk() { :; }
logskip() { echo "$*"; }
abort() {
  echo "$*" >&2
  exit 1
}
escape() { printf '%s' "$1"; }
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
  elif [ "$1" = config ] && [ "$2" != --global ]; then
    case "$2" in
    user.name) [ -n "${STRAP_TEST_GIT_NAME-}" ] && echo "$STRAP_TEST_GIT_NAME" ;;
    user.email) [ -n "${STRAP_TEST_GIT_EMAIL-}" ] && echo "$STRAP_TEST_GIT_EMAIL" ;;
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
