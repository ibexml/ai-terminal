# ai-terminal

Three shell files (`ai`, `ai-keys.sh`, `install.sh`) with no build step; `test.sh` is the only test. [README.md](README.md) covers what it does and everything the installer changes.

## Checking a change

- Syntax check: `for f in ai install.sh ai-keys.sh; do bash -n "$f"; done; zsh -n ai-keys.sh`
- `bash test.sh` runs that syntax check, then `ai` against a fake `claude` on PATH: raw markdown when piped, rendered under a pseudo-terminal (`script -q /dev/null`), and the sign-in failure message with exit 1. No sign-in or network needed; it prints `ok`.
- `bash ai "question"` runs the repo copy, and sends a real question on the signed-in plan or API key. Files are not executable in git; the installer sets that on its copy.
- `install.sh` copies files rather than linking them, so the installed `ai` stays old until it is rerun. It needs a terminal to answer its prompts, and it edits shell startup files, iTerm2 preferences and the Keychain, so don't run it to test unless asked.
- The README's one-line install is `curl … install.sh | bash`. Then `install.sh` downloads `ai` and `ai-keys.sh` from `master` on GitHub, so changes reach new users only once pushed. Its body stays inside `main()` so bash reads the whole script before running it, and anything it runs that could read stdin gets `</dev/null` or `</dev/tty`.
- The spinner in `ai` and the installer only draws on stderr/stdout when that is a terminal; `AI_ANIMATE=0` turns it off. Watch bash 3.2: a variable followed by a non-ASCII character (`$p…`) must be written `${p}…`.

## Constraints

- `ai` and `install.sh` must work on macOS's stock bash 3.2.
- `ai-keys.sh` is sourced by both zsh and bash and must parse in both. Keep shell-specific code inside its `ZSH_VERSION` / `BASH_VERSION` branch.
- `ai --help` prints lines 2-12 of `ai`, so the usage comment has to stay on those lines.
- Don't rename the Keychain services (`ai-zsh-anthropic`, `ai-zsh-openai`), the `# >>> ai.zsh >>>` markers or the iTerm2 key `0x69-0x100000`. Existing installs depend on them, and rerunning or uninstalling only finds these names.
- API keys never go on a command line. API mode passes the key through `-H @<(...)` and the prompt through the environment and stdin; the installer feeds Keychain writes to `security -i`. Codex is the exception for the prompt only: `codex exec` takes it as an argument.
- Keep the isolation: run from `$HOME` and, in CLI mode, remove the API key variable so the plan is used and run Claude Code with no tools and no MCP servers. The README's security section promises this.
- Recheck against the installed `claude` and `codex` when changing them: the flags in `claude_cli` and `codex_cli`, and the sign-in checks in `install.sh` (`auth status` showing `"authMethod": "claude.ai"`, and `~/.codex/auth.json`).
- The default API model `claude-sonnet-5-5` appears in both `ai` and the README.

## Notes

- "Pro/Max" and "Plus/Pro" in these files mean the user's Claude and ChatGPT plans. Ibex ML itself has no paid plans.
