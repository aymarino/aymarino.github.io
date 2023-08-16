---
layout: post
title: Workspace-custom keybindings for running scripts in VS Code
---

I like to use VS Code for note-taking, and have scripts to help facilitate my workflow. For example,
I have a script, shamelessly inspired by [Obsidian](http://obsidian.md), to create and open that
day's "daily note", which is handy to quickly dump some scratch work or TODOs that I haven't
organized yet, and create a loose journal of what I was working on that day. The script itself is
simple \[[^1]\]:

```sh
#!/usr/bin/env bash

WORKSPACE_ROOT=$(dirname "$(dirname "$(readlink -f "$0")")")
DAILY_NOTES_DIR=$WORKSPACE_ROOT/daily-notes
DATE=$(date "+%Y-%m-%d")

mkdir -p $DAILY_NOTES_DIR
code $DAILY_NOTES_DIR/$DATE.md
```

It's handy to assign a keyboard shortcut to run this on-demand. That's easy enough to do with a
[Task](https://code.visualstudio.com/docs/editor/tasks) in VS Code:

```jsonc
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "daily-note",
      "type": "shell",
      "command": "sh ${workspaceFolder}/.vscode/daily-note.sh",
      "problemMatcher": [],
      "presentation": {
        "echo": true,
        "reveal": "never",
        "focus": false,
        "panel": "shared",
        "showReuseMessage": true,
        "clear": true
      }
    }
  ]
}
```

and assigning that task to run on
[a keyboard shortcut](https://code.visualstudio.com/docs/editor/tasks#_binding-keyboard-shortcuts-to-tasks):

```jsonc
// ~/Library/Application Support/Code/User/keybindings.json
[
  {
    "key": "alt+d",
    "command": "workbench.action.tasks.runTask",
    "args": "daily-note"
  }
]
```

But of course it only applies to this particular notes repo, and I wouldn't want it to accidentally
run when working on a codebase, for example. VS Code does not natively support this:
[keyboard configuration](https://code.visualstudio.com/docs/getstarted/keybindings) is global, and
[does not support](https://github.com/Microsoft/vscode/issues/23757) a per-workspace configuration
like it does for `settings.json`.

There's a trick to get that same result though. In the per-project `settings.json`, define a custom
configuration setting like

```jsonc
// .vscode/settings.json
{
  "workspaceKeybindings.dailyNoteTask.enabled": true
}
```

and modify the global keybinding to only take effect when that configuration is active:

```jsonc
// ~/Library/Application Support/Code/User/keybindings.json
[
  {
    "key": "alt+g",
    "command": "workbench.action.tasks.runTask",
    "args": "sync",
    "when": "config.workspaceKeybindings.dailyNoteTask.enabled"
  }
]
```

Nice! So we have a keybinding to our custom script that's only enabled when we're working in the
workspace it's intended for. But, you still need to set up that global keybinding when cloning the
repo to a new machine or install, which is a pain.

I like to keep apply all my configuration changes programmatically to make it easy to setup a new
machine and avoid forgetting about any changes I've made to past ones. In this case, I use an
`install.sh` that I keep in the `.vscode` folder in the notes repo to copy over the keybinding
config to a new install:

```sh
SCRIPT_DIR=/tmp/git-keybindings-script
SCRIPT_NAME=update-keybindings.py
VSCODE_REPO_DIR=$(dirname "$0")
USER_KEYBINDINGS="$HOME/Library/Application Support/Code/User/keybindings.json"

git clone https://gist.github.com/8ba8b2ef7d065ebeffc71b71783013e4.git $SCRIPT_DIR

chmod +x $SCRIPT_DIR/$SCRIPT_NAME
$SCRIPT_DIR/$SCRIPT_NAME "$VSCODE_REPO_DIR/keybindings.json" "$USER_KEYBINDINGS"

rm -rf $SCRIPT_DIR
```

The [gist](https://gist.github.com/aymarino/8ba8b2ef7d065ebeffc71b71783013e4) this script points to
will merge local `keybindings.json` file with the settings in the global one, mercifully easy in
Python \[[^2]\]:

```python
#!/usr/bin/env python3

import argparse
import json5
import os

parser = argparse.ArgumentParser(description=
    """
    Update vscode keybindings JSON with a configuration from the given JSON file.
    Typical usage: ./update-keybindings.py source-keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json
    """
)
parser.add_argument("source", help="File to pull desired settings from")
parser.add_argument("dest", help="File to push desired settings to")
args = parser.parse_args()

with open(args.source, 'r') as source_file:
    source_settings = json5.load(source_file)

if not os.path.exists(args.dest):
    dest_settings = []
else:
    with open(args.dest, 'r') as dest_file:
        dest_settings = json5.load(dest_file)

for setting in source_settings:
    if setting in dest_settings:
        print(f"Already in dest: {setting}; skipping")
    else:
        dest_settings.append(setting)

with open(args.dest, 'w+') as dest_file:
    json5.dump(dest_settings, dest_file, indent=4, quote_keys=True)
```

I use a similar script to update my global VS Code configuration settings on new machines as well.

<hr/>

[^1]:
    Note that all shell scripts in this post are macOS-specific. Where VS Code will store the global
    configuration files will be different on Linux or Windows.

[^2]:
    With the exception that Python's standard [json](https://docs.python.org/3/library/json.html)
    module does not support the [JSON 5](https://json5.org) spec, in particular trailing commas or
    comments. So you have to `pip install json5` to run the script.
