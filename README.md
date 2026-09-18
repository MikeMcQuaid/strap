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
- Optional local GitHub CLI login to configure Git and access private dotfiles and Brewfiles
- Git name, email and GitHub username can be supplied through flags or environment variables
- Idempotent

## Out of Scope Features

- Enabling any network services by default (instead enable them when needed)
- Installing Homebrew formulae by default for everyone in an organisation (install them with `Brewfile`s in project repositories instead of mandating formulae for the whole organisation)
- Opting-out of any macOS updates (Apple's security updates and macOS updates are there for a reason)
- Disabling security features (these are a minimal set of best practises)
- Add phone number to security screen message (want to avoid prompting users for information on installation)

## Usage

Open <https://strap.mikemcquaid.com/> for installation instructions and
[end-user configuration](https://strap.mikemcquaid.com/#configuration), including
installer flags and environment variables.

Instead, to run Strap locally run:

```bash
git clone https://github.com/MikeMcQuaid/strap
cd strap
bash bin/strap.sh # or bash bin/strap.sh --debug for more debugging output
```

## Local website preview

To preview the website locally with Jekyll:

```bash
git clone https://github.com/MikeMcQuaid/strap
cd strap
./script/bootstrap
./script/server
```

Open <http://localhost:3000>. `script/build` copies the static site to `_site/`,
including the installer from its single source in `bin/strap.sh`.
The local server uses Homebrew's Ruby and Bundler, with gems shared between
worktrees. Jekyll watches `public/` for changes; restart the server after editing
the installer. Pass Jekyll options through `script/server`, for example
`script/server --port 4000`.

## Server-side configuration

The website serves the same installer to everyone. GitHub login and personal
configuration happen on the user's Mac. Hosting requires no OAuth application,
GitHub client secret or session secret.

### Docker

Strap is also available as a Docker image on [Docker Hub (`mikemcquaid/strap`)](https://hub.docker.com/repository/docker/mikemcquaid/strap) and [GitHub Packages (`ghcr.io/mikemcquaid/strap`)](https://github.com/users/MikeMcQuaid/packages/container/package/strap).
The image runs BusyBox's static webserver as a non-root user on port 3000:

```bash
docker build -t strap .
docker run --rm -p 3000:3000 strap
```

The container serves downloads; run the downloaded installer on your Mac.
No Ruby runtime, OAuth credentials or session secrets are required.

### GitHub Pages

Pushes to `main` publish the static site through GitHub Actions to GitHub Pages
and continue publishing the Docker images to Docker Hub and GHCR.
The site uses the same download flow as the previous Pages version from commit
`b6e6b3b`, with all personalisation now performed locally.

For the initial migration, select **GitHub Actions** in the repository's
**Settings → Pages → Build and deployment**. Set the custom domain to
`strap.mikemcquaid.com`, change its DNS to point to `mikemcquaid.github.io` and
enable HTTPS once the domain is ready. `public/CNAME` records the domain, but an
Actions deployment does not configure it automatically. Keep DigitalOcean serving
until Pages and DNS have been verified, then retire the old app and its deployment
secret. Docker Hub still requires the `DOCKER_TOKEN` Actions secret.

### Customising a deployment

- Edit `public/index.html` for site-specific instructions and `public/style.css`
  for styling. This replaces the former `STRAP_BEFORE_INSTALL` setting.
- Set deployment-wide installer defaults in `bin/strap.sh`, preserving overrides
  supplied by users. Rebuild the site or Docker image to publish changes.
- For a fork, update `public/CNAME`, the Pages domain settings and DNS. Update the
  registry usernames and image tags in `.github/workflows/tests.yml` too.

Server and container environment variables do not customise static downloads.
Installer environment variables are set by end users when running Strap; they
are documented on the [configuration page](https://strap.mikemcquaid.com/#configuration).

## Development

Run `script/bootstrap` to install development tools and Jekyll, `script/tests`
for the isolated Bash CLI tests and `script/style` for shell and workflow checks.
The tests mock system commands and do not run the macOS bootstrap. CI also runs
the complete installer on a disposable macOS runner and tests the Docker download.

## Status

Stable and in active development.

## Contact

[Mike McQuaid](mailto:mike@mikemcquaid.com)

## License

Licensed under the [MIT License](https://en.wikipedia.org/wiki/MIT_License).
The full license text is available in [LICENSE.txt](https://github.com/MikeMcQuaid/strap/blob/main/LICENSE.txt).

[Fork me on GitHub Retina Ribbons](https://github.com/aral/fork-me-on-github-retina-ribbons)
are vendored in [`public`](public)
and also licensed under the [MIT License](https://github.com/aral/fork-me-on-github-retina-ribbons/blob/master/LICENSE)
