# Strap
Strap is a script to bootstrap a minimal OS X development system. This does not assume you're doing Ruby/Rails/web development but installs the minimal set of software every OS X developer will want.

## Features
- Installs the Xcode Command Line Tools (for compilers and Unix tools)
- Agree to the Xcode license (for using compilers without prompts)
- Installs [Homebrew](http://brew.sh) (for installing command-line software)
- Installs [Homebrew Versions](https://github.com/Homebrew/homebrew-versions) (for installing older versions of command-line software)
- Installs [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle) (for `bundler`-like `Brewfile` support)
- Installs [Homebrew Services](https://github.com/Homebrew/homebrew-services) (for managing Homebrew-installed services)
- Installs [Homebrew Cask](https://github.com/caskroom/homebrew-cask) (for installing graphical software)
- Forwards `localhost` port `80` to `8080` and `443` to `8443` (for running web servers as an unprivileged user)
- Disables Java in Safari (for better security)
- Enables the OS X screensaver password immediately (for better security)
- Enables the OS X application firewall (for better security)
- Adds a `Found this computer?` message to the login screen (for machine recovery)
- Enables full-disk encryption and saves the FileVault Recovery Key to the Desktop (for better security)
- Installs the latest OS X software updates (for better security)
- A simple web application to set Git's name, email and GitHub token.

## Usage
Open https://osx-strap.herokuapp.com in your web browser.

Alternatively, to run Strap locally run:
```bash
git clone https://github.com/mikemcquaid/strap
cd strap
./bin/strap.sh # or ./bin/strap.sh --debug for more debugging output
```

Alternatively, to run the web application locally run:
```bash
git clone https://github.com/mikemcquaid/strap
cd strap
bundle install
GITHUB_KEY="..." GITHUB_SECRET="..." foreman start
```

Alternatively, to deploy to [Heroku](https://www.heroku.com) click:

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

## Web Application Configuration Environment Variables
- `GITHUB_KEY`: the GitHub.com Application Client ID..
- `GITHUB_SECRET`: the GitHub.com Application Client Secret..
- `SESSION_SECRET`: the secret used for cookie session storage.
- `WEB_CONCURRENCY`: the number of Unicorn (web server) processes to run.

## Status
Stable and in active development.

[![Build Status](https://travis-ci.org/mikemcquaid/strap.svg)](https://travis-ci.org/mikemcquaid/strap)

## Contact
[Mike McQuaid](mailto:mike@mikemcquaid.com)

## License
Strap is licensed under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).
The full license text is available in [LICENSE.txt](https://github.com/mikemcquaid/strap/blob/master/LICENSE.txt).
