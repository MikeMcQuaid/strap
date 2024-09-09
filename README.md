# 👢 Strap

A script to bootstrap a minimal macOS development system with the minimal set of settings and software every macOS developer will want.

## Motivation

Replacing [Boxen](https://github.com/boxen/boxen) in [GitHub](https://github.com/) with a better tool (see [mikemcquaid.com/replacing-boxen](https://mikemcquaid.com/replacing-boxen/)).

## ☕️ Workbrew

In 2023 I started a company, ☕️ Workbrew, to provide the missing features and support for companies using Homebrew.
Workbrew is now available in public beta and has a **Workbrew Bootstrap** feature that's basically Strap v2.
Additionally, Workbrew provides MDM integration, fleet configuration, remote `brew` command execution and much more.
Please [try it out](https://console.workbrew.com) or [book a demo](https://workbrew.com/demo).

## Features

- Enables `sudo` using TouchID
- Enables the macOS screensaver password immediately (for better security)
- Enables the macOS application firewall (for better security)
- Enables full-disk encryption and saves the FileVault Recovery Key to the Desktop (for better security)
- Installs the Xcode Command Line Tools (for compilers and Unix tools)
- Agree to the Xcode license (for using compilers without prompts)
- Installs [Homebrew](https://brew.sh) unless you already have [Workbrew](https://workbrew.com) installed (for installing software)
- Installs the latest macOS software updates (for better security)
- Updates dotfiles in a `~/.dotfiles` Git repository. If they exist and are executable: runs `script/setup` to configure the dotfiles and `script/strap-after-setup` after setting up everything else.
- Installs software from a user's `Brewfile` in their `~/.homebrew-brewfile` Git repository or `.Brewfile` in their home directory.
- Idempotent

## Out of Scope Features

- Enabling any network services by default (instead enable them when needed)
- Installing Homebrew formulae by default for everyone in an organisation (install them with `Brewfile`s in project repositories instead of mandating formulae for the whole organisation)
- Opting-out of any macOS updates (Apple's security updates and macOS updates are there for a reason)
- Disabling security features (these are a minimal set of best practises)
- Most other things: Strap is now considered feature-complete

## Usage

Open [strap.mikemcquaid.com](https://strap.mikemcquaid.com) in your web browser.

Instead, to run Strap locally run:

```console
git clone https://github.com/MikeMcQuaid/strap
cd strap
bash strap.sh # or bash strap.sh --debug for more debugging output
```

Instead, to run the web application locally run:

```console
git clone https://github.com/MikeMcQuaid/strap
cd strap
./script/bootstrap
./script/server
```

## Status

Feature complete. No further development planned.

## License

Licensed under the [AGPLv3 License](https://en.wikipedia.org/wiki/Affero_General_Public_License).
The full license text is available in [LICENSE.txt](https://github.com/MikeMcQuaid/strap/blob/main/LICENSE.txt).
