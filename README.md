# ai-terminal

**Ask Claude or ChatGPT without leaving your terminal.**
Type a question at your prompt, press **⌘I**, get the answer. It runs on the Claude or ChatGPT plan you already pay for, so there's no new account or API bill.

```
$ how do I find files larger than 100MB here      ⌘I
⠹ Claude is thinking 2s

find . -type f -size +100M
Lists every file under the current folder that is larger than 100 MB.
```

## Install

Paste this into your terminal (macOS):

```bash
curl -fsSL https://raw.githubusercontent.com/ibexml/ai-terminal/master/install.sh | bash
```

That's it. The installer walks you through about a minute of yes/no questions, and asks before it installs or signs in to anything. Afterwards, restart your terminal app and open a new tab.

<details>
<summary>Prefer to read the code first?</summary>

```bash
git clone https://github.com/ibexml/ai-terminal.git
cd ai-terminal && bash install.sh
```

</details>

**You need:** a Mac, and a Claude Pro/Max or ChatGPT Plus/Pro plan (or an API key). The installer sets up the official [Claude Code](https://claude.ai/code) and [Codex](https://github.com/openai/codex) command-line tools for you if they're missing.

## Use

| Do this | To |
|---|---|
| Type a question, press **⌘I** | Ask your default AI about what you typed |
| Press **⌘I** on an empty line | Get an `Ask Claude:` prompt |
| `ai "what does lsof -i :8080 show"` | Ask from the command line |
| `ai -c "…"` / `ai -g "…"` | Ask Claude / ask ChatGPT |
| `git diff \| ai` | Send piped text as the question |
| `ai --help` | See every option |

Quotes, `?` and `*` in your question are fine; the whole line is sent as typed. Claude's answers stream in as they are written. Code is shown in color, with syntax highlighting if [`bat`](https://github.com/sharkdp/bat) is installed (`brew install bat`); URLs are clickable, and a dim line under the answer shows how long it took.

**⌘I works in** iTerm2, Ghostty and kitty. **Terminal.app** can't remap ⌘I: turn on Settings → Profiles → Keyboard → "Use Option as Meta key", then press **⌥I**.

## Settings

Set these in your shell startup file (for example `~/.zshrc`).

| Variable | Default | Meaning |
|---|---|---|
| `AI_PROVIDER` | `claude` | `claude` or `chatgpt` (`openai` also works). `-c` / `-g` override it. The installer sets this to the default you picked. |
| `AI_BACKEND` | `auto` | `auto`: use your plan through the CLI if it's installed, else an API key. `cli`: plan only. `api`: API key only. |
| `AI_CLAUDE_MODEL` | `sonnet` | Claude model. With the CLI this is an alias or a model id. With the API, `sonnet` means `claude-sonnet-5-5`; otherwise pass a full model id. |
| `AI_CLAUDE_EFFORT` | unset | Passed to Claude Code as `--effort` (e.g. `low`, `medium`). Unset uses the model's default. CLI only. |
| `AI_CODEX_EFFORT` | `low` | Codex `model_reasoning_effort`. The Codex model itself comes from your Codex config. |
| `AI_OPENAI_MODEL` | `gpt-5` | OpenAI model in API mode. |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | unset | In API mode these are used first, then the Keychain items `ai-zsh-anthropic` / `ai-zsh-openai`. In CLI mode they are removed from the CLI's environment, so your plan is used even if a key is set. |
| `AI_FOLLOWUP` | `0` | `1`: after each answer, `ai` asks for a follow-up question in the same conversation (Enter quits). Claude through the CLI only. Claude Code keeps the conversation only while `ai` runs; it is deleted when `ai` exits. |
| `AI_COPY` | `0` | `1`: when the answer has a code block, Enter copies the first one to the clipboard. |
| `AI_THEME` | from the terminal | `light` or `dark` picks the code color. Without it, `ai` reads `COLORFGBG` (iTerm2 sets it) and falls back to dark. |
| `AI_ANIMATE` | `1` | `0` turns off the spinner, the model/elapsed-time lines and the tab title. |
| `NO_COLOR` | unset | Any value turns off color and formatting. |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ibexml/ai-terminal/master/install.sh | bash -s -- --uninstall
```

This removes the shell config blocks, `~/.local/bin/ai`, `~/.ai-keys.sh`, `~/.ai.zsh`, both Keychain items (without asking first), and the iTerm2 ⌘I mapping. Then open a new tab and restart iTerm2.

It leaves these in place: Claude Code, Codex and `jq`; the Ghostty/kitty lines (delete the `# ai` lines yourself); `*.ai-backup` files; and `~/.ai.zsh.old`.

## Troubleshooting

- **⌘I does nothing or types a character**: restart the terminal app and open a new tab. To check the binding, run `bindkey '\ei'` (zsh) or `bind -s | grep ei` (bash). In other terminals, map ⌘I to send Esc+i (`\x1bi`).
- **iTerm2 mapping didn't stick**: quit iTerm2 completely and rerun the installer, or add it by hand under Settings → Keys → Key Bindings: ⌘I → Send Escape Sequence `i`.
- **`ai: command not found`**: open a new tab. `~/.local/bin` must be on `PATH` (`~/.ai-keys.sh` adds it).
- **"Claude Code isn't signed in" / "Codex couldn't answer (not signed in?)"**: `ai` offers to sign you in when run from a terminal; otherwise run `claude auth login` or `codex login`.
- **"Claude Code isn't installed" / "Codex isn't installed"**: rerun the installer, or add an API key and use `AI_BACKEND=auto` or `api`.
- **"API mode needs jq"**: `brew install jq`.
- **API key problems**: check that the Keychain item exists with `security find-generic-password -a "$USER" -s ai-zsh-anthropic` (or `ai-zsh-openai`). macOS may ask you to allow `security` to read it.
- **Messed-up shell config**: your previous version is in `<file>.ai-backup`.

When `ai` knows the cure, its error ends with a **Fix:** line telling you what to run.

## What the installer changes

Files:

| Path | Change |
|---|---|
| `~/.local/bin/ai` | The `ai` command (copied from `ai`) |
| `~/.ai-keys.sh` | The ⌘I key binding for zsh and bash (copied from `ai-keys.sh`). It also adds `~/.local/bin` to `PATH` in interactive shells. |
| `~/.ai.zsh` | If it exists (left by an earlier version), it is renamed to `~/.ai.zsh.old` |

When run through `curl … | bash`, it downloads `ai` and `ai-keys.sh` from this repository into a temporary folder first.

Shell startup files: `${ZDOTDIR:-~}/.zshrc`, `~/.bash_profile`, and `~/.bashrc` if it exists. `.zshrc` and `.bash_profile` are created if they are missing. Each file is first backed up to `<file>.ai-backup` (overwritten on every run). Then this block is added, replacing any earlier copy of it (`claude` is replaced by `chatgpt` if that's the default you picked):

```sh
# >>> ai.zsh >>>
export AI_PROVIDER=claude
[ -f ~/.ai-keys.sh ] && . ~/.ai-keys.sh
# <<< ai.zsh <<<
```

Terminal key mappings (each maps ⌘I to send Esc+i):

- **iTerm2**: adds a global key mapping (`GlobalKeyMap` entry `0x69-0x100000`, "Send Escape Sequence" `i`) to iTerm2's preferences using `defaults export` / `PlistBuddy` / `defaults import`. This replaces iTerm2's own ⌘I shortcut (Edit Session).
- **Ghostty**: appends `keybind = cmd+i=esc:i` to `~/.config/ghostty/config`.
- **kitty**: appends `map cmd+i send_text all \x1bi` to `~/.config/kitty/kitty.conf`.

Only if you say yes at the prompts:

- Installs Claude Code with `curl -fsSL https://claude.ai/install.sh | bash` and runs `claude auth login` (opens your browser).
- Installs Codex with `brew install --cask codex` (or `npm install -g @openai/codex` if Homebrew isn't installed) and runs `codex login` (opens your browser).
- API keys: installs `jq` with Homebrew if it's missing, then saves the keys you paste to your login Keychain as generic passwords. The account is your macOS user name and the services are `ai-zsh-anthropic` and `ai-zsh-openai`. Keys are passed to `security` on stdin, so they never show up in `ps`.
- Test run: sends "Reply with exactly: ai works" to each AI you set up.

## Security and privacy

- Everything you send with ⌘I or `ai`, meaning the whole prompt line or stdin, goes to the AI you chose: Anthropic (Claude Code or api.anthropic.com) or OpenAI (Codex or api.openai.com). Don't press ⌘I on a line that contains passwords or secrets, and be careful piping files into `ai`.
- `ai` runs from your home directory so no project config or hooks get loaded. Claude Code runs with all tools turned off and no MCP servers. Codex runs `codex exec` with its default sandbox and is told not to run commands or read files unless the question needs them. It can still do so, within Codex's sandbox.
- API keys are stored in your macOS login Keychain, not in files, and never passed on a command line.
- The installer can run third-party install scripts (`claude.ai/install.sh`, Homebrew, npm), but only after asking you.

## License

[MIT](LICENSE)
