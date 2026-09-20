# Strap

A script to bootstrap a minimal macOS development system. This does not assume you're doing Ruby/Rails/web development but installs the minimal set of software every macOS developer will want.

## Motivation

Replacing [Boxen](https://github.com/boxen/boxen) in [GitHub](https://github.com/) with a better tool. This post outlines the problems with Boxen and requirements for Strap and other tools used by GitHub: <https://mikemcquaid.com/2016/06/15/replacing-boxen/>

## Features

- Enables `sudo` using TouchID
- Enables the macOS screensaver password immediately (for better security)
- Enables the macOS application firewall (for better security)
- Adds a `Found this computer?` message to the login screen (for machine recovery)
- Enables full-disk encryption and saves the FileVault Recovery Key to the Desktop (for better security)
- Installs the Xcode Command Line Tools (for compilers and Unix tools)
- Agree to the Xcode license (for using compilers without prompts)
- Installs [Homebrew](https://brew.sh) (for installing command-line software)
- Installs the latest macOS software updates (for better security)
- Installs dotfiles from a user's `https://github.com/username/dotfiles` repository. If they exist and are executable: runs `script/setup` to configure the dotfiles and `script/strap-after-setup` after setting up everything else.
- Installs software from a user's `Brewfile` in their `https://github.com/username/homebrew-brewfile` repository or `.Brewfile` in their home directory.
- Configures Git's name, email and GitHub access using optional local GitHub CLI login or environment variables
- Idempotent

## Out of Scope Features

- Enabling any network services by default (instead enable them when needed)
- Installing Homebrew formulae by default for everyone in an organisation (install them with `Brewfile`s in project repositories instead of mandating formulae for the whole organisation)
- Opting-out of any macOS updates (Apple's security updates and macOS updates are there for a reason)
- Disabling security features (these are a minimal set of best practises)
- Add phone number to security screen message (want to avoid prompting users for information on installation)

## Usage

Open <https://strap.mikemcquaid.com/> in your web browser.

Instead, to run Strap locally run:

```bash
git clone https://github.com/MikeMcQuaid/strap
cd strap
bash bin/strap.sh # or bash bin/strap.sh --debug for more debugging output
```

Instead, to run the web application locally run:

```bash
git clone https://github.com/MikeMcQuaid/strap
cd strap
./script/bootstrap
./script/server
```

Strap is also available as a Docker image on [Docker Hub (`mikemcquaid/strap`)](https://hub.docker.com/repository/docker/mikemcquaid/strap) and [GitHub Packages (`ghcr.io/mikemcquaid/strap`)](https://github.com/users/MikeMcQuaid/packages/container/package/strap).

## Configuration Environment Variables and Flags

Use these when running `bin/strap.sh` locally or the downloaded script:

- `STRAP_GIT_NAME`: override Git's name and the name in the login-screen recovery message. If unset or empty, use the existing Git name, then the authenticated GitHub profile name.
- `STRAP_GIT_EMAIL`: override Git's email and the email in the login-screen recovery message. If unset or empty, use the existing Git email, then the authenticated GitHub account's primary verified email.
- `STRAP_GITHUB_USER`: override Git's GitHub username and the owner of dotfiles and Brewfile repositories. If unset or empty, use the authenticated GitHub username when available.
- `GH_TOKEN` or `GITHUB_TOKEN`: optional GitHub CLI credentials. `GH_TOKEN` takes precedence; an existing local login is otherwise reused.
- `STRAP_DEBUG=1` or `--debug`: enable debugging output.
- `STRAP_NONINTERACTIVE=1`, `CI=1` or `--non-interactive`: run without interactive prompts; automatic without a TTY. Never starts a GitHub login and requires sudo access without a password prompt.
- `--help`: print usage without changing your Mac.

## Status

Stable and in active development.

## Contact

[Mike McQuaid](mailto:mike@mikemcquaid.com)

## License

Licensed under the [MIT License](https://en.wikipedia.org/wiki/MIT_License).
The full license text is available in [LICENSE.txt](https://github.com/MikeMcQuaid/strap/blob/main/LICENSE.txt).

[Fork me on GitHub Retina Ribbons](https://github.com/aral/fork-me-on-github-retina-ribbons)
are vendored in [`images`](images)
and also licensed under the [MIT License](https://github.com/aral/fork-me-on-github-retina-ribbons/blob/master/LICENSE)
