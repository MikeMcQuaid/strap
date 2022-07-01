#!/bin/bash
logn "${RED}Running custom-strap.sh"


# Homebrew bundle, cask, services, etc.
logn "Installing Homebrew taps and extensions from custom-strap.sh"
tap 'daptiv/homebrew-tap'


# Setup Daptiv dotfiles
DAPTIV_DOTFILES_BRANCH="${DAPTIV_DOTFILES_BRANCH:-master}"
USER_DOTFILES_BRANCH="${USER_DOTFILES_BRANCH:-master}"
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


echo -e "Next steps:"
echo -e "1. run 'strap-daptiv' to run daptiv-dotfiles scripts/setup"
echo -e "2. run 'strap-user' to run user dotfiles scripts/setup${RESET}"
