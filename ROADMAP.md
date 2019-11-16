A strawman proposal toward a Strap community
============================================
by Christopher Allen @ChristopherA

Background & Motivation
-----------------------
I have created and shared in the past a number of repos with my personal
opinionated best practices for bootstrapping your Macintosh for development, as
well as offering my own dotfiles best practices. Other than some take up by
early blockchain developers when I taught at Blockchain University, none of
these had huge popularity.

These include:

* https://github.com/ChristopherA/dotfiles-old — My oldest shared dotfiles,
  inspired by mathiasbynens/dotfiles. For my install osx updates and dev system
  script was fairly useful install/allosxupdates.sh as it be be installed using
  curl, as well as my settings install/installosx.sh. Unfortunately these
  scripts broke in more recent version of osx.

* https://github.com/ChristopherA/prepare-osx-for-webdev Forks of this script
  that installed a very simple development environment for early blockchain
  developer classroom for OSX 10.12 was probably run by hundreds of people.
  Most notably, to ease web developers into the shell I leveraged osascript
  applescript dialogues to make it easier. Like dotfiles-old, this script
  stopped working in later macOS.

* https://github.com/ChristopherA/dotfiles-stow were my first dotfiles to use
  gnu stow, which handles very nicely symlinking from dotfiles directories to
  the home directory.

* https://github.com/ChristopherA/bash-dotfiles-for-tails An attempt to make
  my dotfiles work for Tails OS persistent volume. Works, but due to limitations
  of Tails isn't that automatically scriptable to install new apps.

* https://github.com/ChristopherA/.dotfiles My relatively current dotfiles
  approach. Uses stow and .d directories that all the login shell scripts to be
  executed as separate files. It also is a little cross-platform, and works
  reasonably well for my Debian shell-only remote VMs. Another important
  difference is now all my secure private files are handled in another repo
  called .private, which not only is private in GitHub, it also is encrypted
  with GPG. Many of my install scripts have moved there, but had moved to using
  https://github.com/thisaaronm/macOS_softwareUpdate rather than my own old dev
  system installers.

With MacOS Catalina 10.14 I decided to get serious and puzzle not only better
tools for me, but also better tools to address a variety of secure development
issues that other developers I work with have run into, in particular with GPG
and SSH configurations, and better hardening of the OS and VMs.

I ran into MikeMcQuaid/strap a few months ago and have really liked it, but have
found the using it with dotfiles didn't work (still not sure why but it also may
have to do with Catalina using zsh or some other Catalina change), but forking
and starting with MikeMcQuaid/dotfiles worked reasonably well. However, these
dotfiles don't so some of the best practices I recommend, including how to
secure your .private repo for ssh, gpg and other personal information, and my
use of .d files. Also I wasn't quite able to get the Heroku trick to work — I'm
more of a C C++ engineer and I couldn't figure out why the github credentials
where not being downloaded in my version of the Heroku app.

Over the last few weeks I've created another GitHub account just for testing
some ideas here, with the idea of sharing it as a fork of best practices, plus
include a public version of the .private repo to show it it works.

However, after meeting @MikeMcQuaid at #GitHubUniverse he seemed to be
interested in my approaches, and I would really like to see if we can build a
community around a better strap, better base dotfiles, better security and
privacy hardening, and investigate cross-platform again (or at least common
shell script settings for ssh and tmux to VMs).

A Possible Roadmap
------------------

* [ ] Strap as it stands is very good. My primary suggestiton is that it
  download the users private repo (if it exists) as .private and run a setup
  script there. This just require a PR to the current repo and some testing.
  With this @ChristopherA can continue testing some example dotfiles as best
  practices.

* [ ] At some point when @MikeMcQuaid feels confident that building a community
  is a good move, move the Strap repo over to a GitHub community, and start
  referring existing strap users to use that version instead.

* [ ] Both @MikeMcQuaid and @ChristopherA invite some other folk to join in the
  community, and integrate their ideas there. In particular, @thisaaronm has
  some good stuff in his script, and there are some security experts that maybe
  can recommend some additional minimal hardening.

* [ ] Work collaboratively to implement best practices for Catalina .zsh
  on a dotfiles-base, private-base and homebrew-brewfile-base repos. In
  particular, the use of shell scripts in .d directory will make it easier
  for people to add their own functionality if they fork these repos.

* [ ] Invite people to contribute opinionated dotfiles-base, private-base and
  homebrew-brewfile-base for various other purposes, such as other shells,
  different development environments, etc. With a .d directory architecture, it
  will be easy to take the best of these and integrate back into -base if the
  community believes these are best practices for all.

Let me know if you are interested in this proposal and roadmap!

-- Christopher Allen
   Github & Twitter: @ChristopherA
   Email: Christopher@LifeWithAlacrity.com
