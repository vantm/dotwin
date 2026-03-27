# DOTWIN

## Installation

Remove system apps if installed:

- `windows-terminal`
- `git`

Scoop apps:

```pwsh
scoop install 0xProto-NF `
  7zip aria2 chezmoi mingit msys2 windows-terminal
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
