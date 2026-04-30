# dotfile-org

A minimal, idempotent dotfile symlink manager written in R7RS Scheme
(Chibi-Scheme).

## What it does

`dotfile-org.scm` reads a plaintext manifest listing your configuration files
and ensures that symbolic links exist from a central dotfiles directory to
their intended locations in your home directory (or anywhere else).  Running it
repeatedly is safe: it only creates or fixes links that are missing or
pointing to the wrong place.  It will never overwrite a real file or
directory.

## Requirements

- [Chibi-Scheme](https://github.com/ashinn/chibi-scheme)

## Manifest format

Create a file named `manifest` in your dotfiles repository.  Each line
contains two whitespace-separated fields:

```
# comments and blank lines are ignored
bash/bashrc               /home/alice/.bashrc
emacs/config.org          /home/alice/.emacs.d/config.org
nvim/init.lua             /home/alice/.config/nvim/init.lua
```

- **Field 1:** Path to the source file, relative to the dotfiles directory.
- **Field 2:** Absolute path to where the symlink should be created.

> **Note:** Neither path may contain embedded whitespace.

## Usage

```sh
# Run from inside your dotfiles repo
chibi-scheme dotfile-org.scm

# Or point it at a specific directory
chibi-scheme dotfile-org.scm /path/to/my-dotfiles
```

### Output

| Prefix | Meaning |
|--------|---------|
| `OK`   | Symlink already exists and points to the correct source. |
| `NEW`  | Symlink did not exist; it was created (and parent dirs made if needed). |
| `UPD`  | Symlink existed but pointed elsewhere; it was replaced. |
| `SKIP` | Destination exists and is a real file or directory (not a symlink). Nothing was changed. |
| `ERR`  | Malformed manifest line. |

## Safety

- **Idempotent:** You can run the script as many times as you like.  Correct
  links are left untouched.
- **Non-destructive:** If a destination path is occupied by a real file or
  directory, the script prints `SKIP` and moves on.  It will only remove and
  recreate an existing path if that path is already a symbolic link.
- **Auto-mkdir:** Missing parent directories for the destination are created
  automatically.

## Example repository layout

```
~/dotfiles/
├── dotfile-org.scm
├── manifest
├── bash/
│   └── bashrc
├── emacs/
│   └── config.org
└── nvim/
    └── init.lua
```

With `manifest`:

```
bash/bashrc      /home/alice/.bashrc
emacs/config.org /home/alice/.emacs.d/config.org
nvim/init.lua    /home/alice/.config/nvim/init.lua
```

## Tips

- Keep `dotfile-org.scm` inside your dotfiles repo so it travels with your
  configs.
- Use absolute paths in the manifest so the script works regardless of your
  current working directory.
- If you move your dotfiles repo, just update the manifest paths and rerun.