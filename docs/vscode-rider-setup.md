# Making VS Code feel like JetBrains Rider

A reproducible setup that gives VS Code the **JetBrains Mono** font (with ligatures), the
**Darcula** color scheme, JetBrains-style file icons, and IntelliJ/Rider keybindings. Written
for someone coming from Rider/GoLand who wants VS Code to feel familiar.

The "Rider look" comes down to four independent pieces, set up in this order:

1. **Font** — JetBrains Mono + ligatures
2. **Theme + icons** — Darcula color scheme and JetBrains-style file icons
3. **Editor behavior** — sticky scroll, breadcrumbs, bracket guides, smooth caret
4. **Keybindings** — the IntelliJ/Rider shortcut map

Steps 1–2 give you ~80% of the feel; step 4 is the one that matters most for muscle memory.

---

## 1. Install the JetBrains Mono font

JetBrains Mono is **not** bundled with VS Code — you install it at the OS level, then point
VS Code at it. The official font's family name is exactly `JetBrains Mono`, which is what the
settings below reference.

> **Always restart VS Code completely** (not just "Reload Window") after installing a font, or
> it may not appear in the font picker.

### Windows

The plain font is not in winget (only a Nerd Font variant, `DEVCOM.JetBrainsMonoNerdFont`, is).
The cleanest path is to install the official release per-user (no admin rights needed).

PowerShell:

```powershell
$ErrorActionPreference = 'Stop'
$tmp = Join-Path $env:TEMP 'jbmono'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# Download the latest official release
$rel   = Invoke-RestMethod 'https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest' -Headers @{ 'User-Agent' = 'setup' }
$asset = $rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
$zip   = Join-Path $tmp $asset.name
Invoke-WebRequest $asset.browser_download_url -OutFile $zip -Headers @{ 'User-Agent' = 'setup' }
Expand-Archive -Path $zip -DestinationPath $tmp -Force

# Install per-user: copy TTFs + register in HKCU (skip the NL no-ligature and variable [wght] files)
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regKey  = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null

Get-ChildItem $tmp -Recurse -Filter '*.ttf' |
    Where-Object { $_.Name -notlike '*NL-*' -and $_.Name -notlike '*`[wght`]*' } |
    ForEach-Object {
        $dest = Join-Path $fontDir $_.Name
        Copy-Item $_.FullName $dest -Force
        $base    = [IO.Path]::GetFileNameWithoutExtension($_.Name) -replace '^JetBrainsMono-?',''
        if (-not $base) { $base = 'Regular' }
        $spaced  = [Regex]::Replace($base, '(?<=[a-z])(?=[A-Z])', ' ')
        New-ItemProperty $regKey -Name "JetBrains Mono $spaced (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
    }
```

Verify the family is registered:

```powershell
Add-Type -AssemblyName System.Drawing
[System.Drawing.FontFamily]::Families.Name | Select-String 'JetBrains Mono'
```

> The `NL` files are the "no ligatures" variant; the `[wght]` files are variable fonts. We skip
> both so the font picker stays clean and ligatures work by default.

Alternative (terminal-icon glyphs included, but family name becomes `JetBrainsMono Nerd Font`):

```powershell
winget install DEVCOM.JetBrainsMonoNerdFont
```

If you use the Nerd Font, adjust `editor.fontFamily` accordingly (see §3).

### macOS

With Homebrew (recommended):

```bash
brew install --cask font-jetbrains-mono
```

Manual alternative:

```bash
cd "$(mktemp -d)"
curl -fsSL -o jbmono.zip \
  "$(curl -fsSL https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest \
     | grep -o 'https://[^"]*\.zip')"
unzip -q jbmono.zip
# Install only the standard ligature TTFs into the user font dir
mkdir -p "$HOME/Library/Fonts"
find . -name 'JetBrainsMono-*.ttf' ! -name '*NL*' -exec cp {} "$HOME/Library/Fonts/" \;
```

### Linux

```bash
cd "$(mktemp -d)"
curl -fsSL -o jbmono.zip \
  "$(curl -fsSL https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest \
     | grep -o 'https://[^"]*\.zip')"
unzip -q jbmono.zip
mkdir -p "$HOME/.local/share/fonts/JetBrainsMono"
find . -name 'JetBrainsMono-*.ttf' ! -name '*NL*' \
  -exec cp {} "$HOME/.local/share/fonts/JetBrainsMono/" \;
fc-cache -f "$HOME/.local/share/fonts"
fc-list | grep -i 'JetBrains Mono'   # verify
```

---

## 2. Install the extensions

These are the same on every OS. The `code` CLI ships with VS Code (on macOS you may need to run
*Shell Command: Install 'code' command in PATH* from the command palette first).

```bash
code --install-extension rokoroku.vscode-theme-darcula     # Darcula color scheme
code --install-extension vscode-icons-team.vscode-icons    # JetBrains-style file icons
code --install-extension k--kato.intellij-idea-keybindings # IntelliJ/Rider keymap
```

What each one does:

| Extension | Purpose |
|---|---|
| `rokoroku.vscode-theme-darcula` | A direct port of IntelliJ/Rider's Darcula color scheme. |
| `vscode-icons-team.vscode-icons` | File/folder icons matching the JetBrains look. |
| `k--kato.intellij-idea-keybindings` | Remaps shortcuts to the IntelliJ/Rider keymap (`Shift Shift`, `Ctrl+B`, `Shift+F6`, `Alt+Enter`, …). |

You can also install them from the Extensions view (`Ctrl+Shift+X`) by searching the IDs above.

---

## 3. Apply the settings

Open the user settings file (`Ctrl+Shift+P` → **Preferences: Open User Settings (JSON)**) and merge
in the block below. The settings file lives at:

- **Windows:** `%APPDATA%\Code\User\settings.json`
- **macOS:** `~/Library/Application Support/Code/User/settings.json`
- **Linux:** `~/.config/Code/User/settings.json`

```jsonc
{
  // Rider-like look & feel
  "workbench.colorTheme": "Darcula",
  "workbench.iconTheme": "vscode-icons",
  "editor.fontFamily": "'JetBrains Mono', Consolas, 'Courier New', monospace",
  "editor.fontSize": 14,
  "editor.lineHeight": 1.5,
  "editor.fontLigatures": true,
  "terminal.integrated.fontFamily": "'JetBrains Mono'",
  "editor.cursorBlinking": "solid",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.renderWhitespace": "selection",
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",
  "editor.smoothScrolling": true,
  "workbench.list.smoothScrolling": true,
  "workbench.editor.showTabs": "multiple",
  "breadcrumbs.enabled": true,
  "editor.stickyScroll.enabled": true,
  "editor.minimap.enabled": true,
  "workbench.tree.indent": 16
}
```

What the less obvious keys do:

- `editor.fontLigatures` — the main reason to use JetBrains Mono: turns `=>`, `!=`, `>=`, `===`
  into single glyphs, like Rider does.
- `editor.stickyScroll.enabled` — pins the current function/type header to the top of the editor.
- `breadcrumbs.enabled` — the navigation trail under the tab bar (Rider's structure path).
- `editor.guides.bracketPairs` / `bracketPairColorization` — colored, guided bracket pairs.
- `workbench.tree.indent` — wider explorer indentation, closer to Rider's tree spacing.

> If you installed the **Nerd Font** instead of the plain font, set
> `"editor.fontFamily": "'JetBrainsMono Nerd Font', Consolas, monospace"` and likewise for
> `terminal.integrated.fontFamily`.

The file is **JSONC** — `//` comments are allowed. If you already have a `settings.json`, just add
these keys; don't replace the whole file. Watch for duplicate keys (e.g. an existing
`workbench.colorTheme`) — the last one wins, so remove the old value.

---

## 4. Verify

1. **Restart VS Code completely** (quit, not reload).
2. Font: the editor and integrated terminal should render in JetBrains Mono; type `=>` or `!=` and
   confirm the ligatures render.
3. Theme: the UI should be Darcula; if not, `Ctrl+K Ctrl+T` → **Darcula**.
4. Icons: file icons should match JetBrains; if not, *Preferences: File Icon Theme* → **VSCode Icons**.
5. Keymap: `Ctrl+Shift+A` should open **Find Action**, and `Shift Shift` (double-tap) should open
   **Search Everywhere**.

---

## 5. Optional extras

- **More Rider-accurate themes:** try `zhuangtongfa.material-theme` (One Dark Pro) if you prefer a
  slightly warmer palette than Darcula.
- **Terminal glyphs:** if your prompt (Starship, Oh My Posh, Powerlevel10k) uses icons, install the
  JetBrains Mono **Nerd Font** for the terminal and set `terminal.integrated.fontFamily` to it
  while keeping the plain font for the editor.
- **Keymap reference:** the IntelliJ keybindings extension page lists every remapped shortcut;
  worth a skim to find the Rider actions you use most.
