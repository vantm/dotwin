# DOTWIN

## Installation

Remove system apps if installed:

- `windows-terminal`
- `git`

Scoop apps:

```pwsh
scoop install `
    mingit less 7zip aria2 chezmoi `
    msys2 windows-terminal 0xProto-NF 
```

UCRT apps:

```bash
pacman -Sy \
  git \
  mingw-w64-ucrt-x86_64-fd \
  mingw-w64-ucrt-x86_64-fzf \
  mingw-w64-ucrt-x86_64-jq \
  mingw-w64-ucrt-x86_64-neovim \
  mingw-w64-ucrt-x86_64-ripgrep \
  mingw-w64-ucrt-x86_64-zoxide
```

Install `lazygit`

## Note

Microsoft Notepad is suck! Don't use it!
