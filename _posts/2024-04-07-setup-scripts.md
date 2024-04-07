---
layout: post
title: "My dotfiles: replicating system configuration and setup in scripts"
categories: []
---

One day I noticed a former coworker was using the real Escape key for `<Esc>` in vim (or perhaps it
was `Ctrl-j`, another default mapping for Esc). I pointed out that I found it useful to remap the
Caps Lock key to Escape, since it's easier and faster to reach it on the home row. His response was
that he actually deliberately tries to keep all the defaults for whatever system or environment he's
using --- default applications and configs, keyboard shortcuts, display settings, etc --- and just
learn to be productive with them. That way, he says, whenever he has to get a new computer, he
doesn't really have to configure much out of the box to be productive with it.

The philosophy stuck with me. I, too, find it annoying to need to set up things just the right way
whenever I get a new system. These days it tends to happen a lot! You get an equipment refresh at
work, you start a new job and are given a machine, you get new computer at home, you provision a new
virtual machine in the cloud, and so on. What ends up happening is some of the systems in your world
each have some distinct subset of the settings/applications/configurations compared to all the rest
of them. This makes it frustrating to switch between computers and systems, or to develop reliable
muscle memory that works across them.

But, of course living such a digitally monastic life is also suboptimal. It's obviously limiting to
restrict yourself to defaults that are not well suited to your workflow. What's actually ideal is
having some way of replicating those settings from one box to another. People have long done things
for particular applications by maintaining personal repos for "dotfiles", to host their `.bashrc` or
`.vimrc` files so that those particular application are configured the same between different
computers, and the changes to those configs can be synced via git.

## Git-hosted configuration scripts

Building on those ideas, I myself have a repo to centralize setup for the various computers in my
life: [`config-scripts`](https://github.com/aymarino/config-scripts/tree/main). Here, I present some
of the features and tricks I've developed for keeping settings reproducible via scripts.

### MacOS setup-as-a-script

Right now, there's only one setup script, which works to set up MacOS computers [^1]. It uses a set
of common utils that make updating the configuration simple. These utils use `brew` as the primitive
for ensuring software is installed:

```sh
function brew_installed() {
  echo "Checking if package '$1' is installed by brew..."
  brew list | grep --word-regexp --fixed-strings "$1" &> /dev/null
}

function brew_install() {
  if ! brew_installed $1 ; then
    echo "Installing '$1' with brew..."
    brew install $1
    return 0
  else
    return 1
  fi
}

function brew_install_login_app() {
  if ! brew_installed $1 ; then
    brew install --cask $1
    echo "Open $1 and enable 'Start at login' in preferences ..."
    read -p "Press enter to continue"
  fi
}
```

These make it easy to add new things that I introduce into my workflow. For example, this is the
[code](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/mac-setup.sh#L54-L64)
installing command line utils and applications:

```sh
brew_install_login_app mos # reverse scroll wheel direction
brew_install_login_app rectangle # gives Windows-style max/half screen shortcuts
brew_install_login_app maccy # Gives clipboard history
brew_install_login_app notunes
brew_install visual-studio-code
brew_install jq
brew_install fd
brew_install tree
brew_install tmux
brew_install alacritty
brew_install neovim
```

The script is designed to be idempotent, so adding a new app to install or configuration setting
just involves adding it to the script, and re-running.

### Shell configuration

There are some more "stateful" configurations that only need to be handled once, like setting the
default shell to `fish` and setting up `fzf`:

```sh
if brew_install fish ; then
  echo "--- Set fish to default shell:"
  echo "  add $(which fish) to /etc/shells"
  echo "  chsh -s $(which fish)"
  echo "and restart"
  exit 1
fi
if brew_install fzf ; then
  echo "Installing fzf key bindings and ** shell command completions"
  $(brew --prefix)/opt/fzf/install
fi
```

There are, of course, the classic dotfiles to configure `vim` [^2], `fish`, and `tmux`:

```sh
# Copy conf files
cp conf/.tmux.conf $HOME
cp conf/.alacritty.toml $HOME
cp conf/config.fish $HOME/.config/fish
cp conf/init.vim $HOME/.config/nvim
```

I keep a directory of any
[custom scripts](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/bin/frg)
that are useful in my workflows:

```sh
# Add scripts to $HOME bin directory
add_script_to_bin start-ec2-dev
add_script_to_bin frg
```

and
[add](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/conf/config.fish#L5)
it to the path [^3].

### VSCode settings

VSCode stores its settings in JSON format, which makes it possible to update/sync settings via a
[script](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/update-vscode-settings.py)
as well. I use a Python script which reads in the repo's settings JSON, and _updates_ the system's
VSCode settings JSON with those fields (rather than simply, and possibly destructively, copying and
overwriting the system JSON). It's useful for syncing the custom keyboard shortcuts I add to the
VSCode vim configuration. E.g.:

```json
"vim.normalModeKeyBindings": [
  // ...
  {
    "before": ["g", "R"],
    "commands": ["editor.action.rename"]
  }
  // ...
]
```

I still haven't found a good way of syncing the particular VSCode extensions I like to have
installed.

### MacOS `defaults`

One trick I recently added to the MacOS setup script is to set system preferences via
`defaults write` --- a utility that updates the system database of user preferences. It is, I
believe, similar to `regedit` for the Windows Registry. I only have a few settings I configure in
this way:

```sh
# TextEdit:
#  - create untitled document at lauch
#  - use plain text mode as default
defaults write com.apple.TextEdit NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false
defaults write com.apple.TextEdit RichText -int 0

# Dock:
#  - enable autohide
#  - set AppSwitcher to show up on all displays
if [[ $(defaults read com.apple.Dock appswitcher-all-displays) == "0" ]]; then
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.Dock appswitcher-all-displays -bool true
  killall Dock
fi

# Finder:
#  - show file extensions
defaults write -g AppleShowAllExtensions -bool true
```

Not everything in the Preferences app is available to configure via `defaults write`. For example,
it appears there is no easy way of configuring Caps Lock -> Esc, as I like. But, there is a
wonderful website that documents many of the settings: <https://macos-defaults.com>.

## Future work

These setup scripts have made it much easier for me to reliably replicate not only shell
configurations, but installed apps and system preferences, to new computers and between existing
ones. In the future I'd like to see even more of the system settings set via these scripts, and
possibly even installing a fundamental set of VSCode extensions that I know I use.

It would also be interesting to create separate scripts for different kinds of workstreams which
require different apps and utilities. E.g., a `rust-setup` script vs a `cpp-setup` script, where the
former installs Cargo and the latter installs CMake and Clang utils.

[^1]:
    In the past, I've also had scripts for Ubuntu and RHEL, since I had to create VMs of those OSes
    regularly. But since I haven't needed to do that in a while, the script was becoming out of date
    and likely broken, so I removed it and will just need to re-create it based on the MacOS one if
    needed in the future.

[^2]:
    For `vim`, I use `neovim` and
    [alias](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/conf/config.fish#L2)
    the former command to the latter. I also use
    [Plug](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/mac-setup.sh#L128-L133)
    to install vim plugins. `vim` itself is configued in
    [`conf/init.vim`](https://github.com/aymarino/config-scripts/blob/ad2ab63252b3f955284d697f1d11e339a760e37c/conf/init.vim).

[^3]:
    In theory, I could now consolidate this so that the path just points to the `bin` directory in
    the local copy of the repo. In the past though, I've had scripts which were only applicable on
    Linux, and wanted to avoid installing those on Mac systems, and vice versa. So the solution was
    to have the setup script decides which binaries get copied to a separate `$HOME` folder, which
    is then added to the path.
