# Strap
A script to bootstrap a minimal macOS development system. This does not assume you're doing Ruby/Rails/web development but installs the minimal set of software every macOS developer will want.

## Motivation
Replacing [Boxen](https://github.com/boxen/boxen/) in [GitHub](https://github.com/) with a better tool. This post outlines the problems with Boxen and requirements for Strap and other tools used by GitHub: http://mikemcquaid.com/2016/06/15/replacing-boxen/

## Features
- Disables Java in Safari (for better security)
- Enables the macOS screensaver password immediately (for better security)
- Enables the macOS application firewall (for better security)
- Adds a `Found this computer?` message to the login screen (for machine recovery)
- Enables full-disk encryption and saves the FileVault Recovery Key to the Desktop (for better security)
- Installs the Xcode Command Line Tools (for compilers and Unix tools)
- Agree to the Xcode license (for using compilers without prompts)
- Installs [Homebrew](http://brew.sh) (for installing command-line software)
- Installs [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle) (for `bundler`-like `Brewfile` support)
- Installs [Homebrew Services](https://github.com/Homebrew/homebrew-services) (for managing Homebrew-installed services)
- Installs [Homebrew Cask](https://github.com/caskroom/homebrew-cask) (for installing graphical software)
- Installs the latest macOS software updates (for better security)
- Installs dotfiles from a user's `https://github.com/username/dotfiles` repository and runs `script/setup` to configure them.
- Installs software from a user's `Brewfile` in their `https://github.com/username/homebrew-brewfile` repository or `.Brewfile` in their home directory.
- A simple web application to set Git's name, email and GitHub token (needs authorized on any organisations you wish to access)
- Idempotent

## Out of Scope Features
- Enabling any network services by default (instead enable them when needed)
- Opting-out of any macOS updates (Apple's security updates and macOS updates are there for a reason)
- Disabling security features (these are a minimal set of best practises)
- Add phone number to security screen message (want to avoid prompting users for information on installation)

## Usage
Open https://daptiv-macos-strap.herokuapp.com/ in your web browser.

To run the web application locally run:
```bash
git clone https://github.com/daptiv/strap
cd strap
GITHUB_KEY="..." GITHUB_SECRET="..." STRAP_CONTACT_PHONE="..." ./script/server
```

## Heroku Information
The heroku app can be accessed by navigating to: https://dashboard.heroku.com/apps/daptiv-macos-strap/deploy/heroku-git
To deploy to Heroku, you will need to do the following:
- Get access to the Heroku application
- Install Heroku on your mac with `brew tap heroku/brew && brew install heroku`
- Pull this repository (`git clone git@github.com:daptiv/strap.git $HOME/src/strap`)
- Add the Heroku remote with `git remote add heroku https://git.heroku.com/daptiv-macos-strap.git`
- Then push your changes with `git push heroku master`


## Web Application Configuration Environment Variables
- `STRAP_CONTACT_PHONE`: Phone number to show on lock screen.
- `GITHUB_KEY`: the GitHub.com Application Client ID..
- `GITHUB_SECRET`: the GitHub.com Application Client Secret..
- `SESSION_SECRET`: the secret used for cookie session storage.
- `WEB_CONCURRENCY`: the number of Unicorn (web server) processes to run (defaults to 3).
- `STRAP_ISSUES_URL`: the URL where users should file issues (defaults to https://github.com/mikemcquaid/strap/issues/new).
- `STRAP_BEFORE_INSTALL`: instructions displayed in the web application for users to follow before installing Strap (wrapped in `<li>` tags).

## What is Strap?
Strap is just a collection of bash scripts, which is where it gets its power and simplicity.  Coupled with Homebrew, which is a well-maintained package manager for Mac OS, it forms a one-stop solution for replacing Boxen and providing a scriptable, repeatable setup process for new machines and developers.

### How it works
Strap starts with a single shell script file, located in this repository and named `bin/strap.sh`.  This script calls out to the follow "blocks", in this order:
- Clones (or updates) `https://github.com/daptiv/dotfiles` to `~/.daptiv-dotfiles`, then runs the follow scripts:
  - `~/.daptiv-dotfiles/scripts/setup`
    - This script links in the Daptiv `.bash_profile`, `.bashrc`, `.npmrc`, `.Daptiv.Brewfile`
      - `.bash_profile`: This is the system default.  It will source your personal bash profile located in `~/.dotfiles/.bash_profile`
      - `.bashrc': This is the system default.  It will source your personal bash rc file located in `~/.dotfiles/.bashrc`
      - `.npmrc`: Contains the keys you need to access our private NPM repository.
      - `.Daptiv.Brewfile`: Contains the default packages that all developers will need.
- Runs `~/.daptiv-dotfiles/scripts/bootstrap` (Not currently used)
- Runs `~/.daptiv-dotfiles/scripts/fix-cask-installs.py`
  - A custom python script that fixes up Homebrew so that anything that was manually installed outside of Strap/Homebrew, won't break the setup process.
- Installs everything in `~/.Daptiv.Brewfile`
- Runs `~/.daptiv-dotfiles/scripts/postbrew`
  - This critical script sets up your machine for running ppm.  It installs nginx configurations, hostfile entries, and more.
- Clones (or updates) your user dotfiles repository.  This takes the form of `git clone https://github.com/$STRAP_GITHUB_USER/dotfiles ~/.dotfiles`.
- Runs `~/.dotfiles/script/setup`
  - This is your personal setup script.  It should link in your `.gitconfig` file, and your `.Brewfile` at a minimum.
- Runs `~/.dotfiles/scripts/bootstrap` (if it exists)
- Runs `~/.daptiv-dotfiles/scripts/fix-cask-installs.py`
- Clones (or updates) `https://github.com/$STRAP_GITHUB_USER/homebrew-brewfile`, then symlinks `~/.homebrew-brewfile` to `~/.Brewfile`.
  - This is an optional repository.  Most developers will keep their personal `.Brewfile` in their dotfiles repository, but you can store it here instead.
- Installs everything in `~/.Brewfile`
- Runs the `~/.dotfiles/script/postbrew` script

That's the entire strap process!  Enjoy!


## Status
Stable and in active development.

[![Build Status](https://travis-ci.org/daptiv/strap.svg)](https://travis-ci.org/daptiv/strap)


## License
Licensed under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).
The full license text is available in [LICENSE.txt](https://github.com/daptiv/strap/blob/master/LICENSE.txt).
