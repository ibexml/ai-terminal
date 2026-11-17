#!/bin/bash
# install.sh — ⌘I "ask Claude / ChatGPT" for the macOS terminal (zsh or bash).
# Uses your Claude and ChatGPT subscriptions through the Claude Code and Codex CLIs;
# API keys are optional. Safe to rerun.
#   curl -fsSL https://raw.githubusercontent.com/ibexml/ai-terminal/master/install.sh | bash
#   bash install.sh              install / update (from a checkout)
#   bash install.sh --uninstall  remove (leaves Claude Code and Codex installed)
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ibexml/ai-terminal/master"
BIN_DIR="$HOME/.local/bin"
AI_BIN="$BIN_DIR/ai"
KEYS="$HOME/.ai-keys.sh"
RC_FILES=("${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.bash_profile")
[[ -f $HOME/.bashrc ]] && RC_FILES+=("$HOME/.bashrc")
BEGIN_MARK="# >>> ai.zsh >>>"
END_MARK="# <<< ai.zsh <<<"
KC_ANTHROPIC="ai-zsh-anthropic"
KC_OPENAI="ai-zsh-openai"
ITERM_KEY="0x69-0x100000"   # Cmd+I in iTerm2's key-map format

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  B=$'\033[1m' D=$'\033[2m' R=$'\033[0m' G=$'\033[32m' Y=$'\033[33m' RED=$'\033[31m' ACC=$'\033[38;5;173m'
else B='' D='' R='' G='' Y='' RED='' ACC=''; fi
ANIM=0; [[ -t 1 && ${AI_ANIMATE:-1} != 0 && ${TERM:-dumb} != dumb ]] && ANIM=1
STEP=0

tilde() { printf '%s' "${1/#$HOME/~}"; }
say()  { STEP=$((STEP + 1)); printf '\n  %s%s%s  %s%s%s\n' "$ACC" "$STEP" "$R" "$B" "$*" "$R"; }
ok()   { printf '     %s✓%s %s\n' "$G" "$R" "$*"; }
warn() { printf '     %s!%s %s\n' "$Y" "$R" "$*"; }
die()  { printf '\n  %s✗%s %s\n\n' "$RED" "$R" "$*" >&2; exit 1; }
ask_yn() {  # ask_yn "question" default(y|n)
  local reply hint="[y/N]"; [[ $2 == y ]] && hint="[Y/n]"
  read -r -p "     $1 $D$hint$R " reply </dev/tty || reply=""
  reply=$(printf '%s' "${reply:-$2}" | tr '[:upper:]' '[:lower:]')
  [[ $reply == y* ]]
}
type_out() {  # print text with a quick typewriter effect
  local s=$1 i
  if (( ! ANIM )); then printf '%s' "$s"; return; fi
  for (( i = 0; i < ${#s}; i++ )); do printf '%s' "${s:i:1}"; sleep 0.012; done
}
spin() {  # spin "label" cmd... — run cmd quietly behind a spinner; its output goes to $SPIN_OUT
  local label=$1 pid rc i=0 F=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏); shift
  "$@" >"$SPIN_OUT" 2>&1 </dev/null & pid=$!
  if (( ANIM )); then
    printf '\033[?25l'
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r     %s%s%s %s\033[K' "$ACC" "${F[i++ % 10]}" "$R" "$label"; sleep 0.08
    done
    printf '\r\033[K\033[?25h'
  fi
  rc=0; wait "$pid" || rc=$?
  return "$rc"
}
find_bin() {
  local c
  for c in "$(command -v "$1" 2>/dev/null)" "$HOME/.local/bin/$1" "/opt/homebrew/bin/$1" "/usr/local/bin/$1"; do
    [[ -n $c && -x $c ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

remove_rc_block() {  # remove our block (and blank lines just before it) from $1
  local f=$1 tmp
  [[ -f $f ]] && grep -qF "$BEGIN_MARK" "$f" || return 0
  tmp=$(mktemp)
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b {skip=1; blanks=""; next}
    $0==e {skip=0; next}
    skip  {next}
    /^[[:space:]]*$/ {blanks=blanks $0 "\n"; next}
    {printf "%s", blanks; blanks=""; print}
    END {printf "%s", blanks}' "$f" > "$tmp"
  cat "$tmp" > "$f"; rm -f "$tmp"
}

kc_has() { security find-generic-password -a "$USER" -s "$1" >/dev/null 2>&1; }
kc_set() {  # fed via stdin so the key never shows up in `ps`
  printf 'add-generic-password -U -a %s -s %s -l %s -w %s\n' "$USER" "$1" "$1" "$2" | security -i >/dev/null
}

# Everything runs from main, so `curl … | bash` has read the whole script before it starts.
main() {
  WORK=$(mktemp -d); SPIN_OUT="$WORK/out"
  trap 'rm -rf "$WORK"; [[ -t 1 ]] && printf "\033[?25h"' EXIT

  printf '\n  '; type_out "${B}ai${R}  ${D}Ask Claude or ChatGPT from your terminal.${R}"; printf '\n'

# ---------- uninstall ----------
if [[ ${1:-} == --uninstall ]]; then
  say "Uninstalling"
  for f in "${RC_FILES[@]}"; do remove_rc_block "$f"; done; ok "Removed shell config blocks"
  rm -f "$AI_BIN" "$KEYS" "$HOME/.ai.zsh"; ok "Removed $(tilde "$AI_BIN") and $(tilde "$KEYS")"
  for s in "$KC_ANTHROPIC" "$KC_OPENAI"; do
    security delete-generic-password -a "$USER" -s "$s" >/dev/null 2>&1 && ok "Deleted Keychain item $s" || true
  done
  if [[ -d /Applications/iTerm.app ]]; then
    TMP="$WORK/iterm.plist"
    if defaults export com.googlecode.iterm2 "$TMP" 2>/dev/null \
       && /usr/libexec/PlistBuddy -c "Delete :GlobalKeyMap:$ITERM_KEY" "$TMP" >/dev/null 2>&1; then
      defaults import com.googlecode.iterm2 "$TMP"; ok "Removed iTerm2 ⌘I mapping (restart iTerm2)"
    fi
  fi
  printf '\n  %s✓%s %sDone.%s Claude Code and Codex were left installed. Open a new terminal tab.\n\n' "$G" "$R" "$B" "$R"
  exit 0
fi

# ---------- preflight ----------
[[ $(uname) == Darwin ]] || die "This installer is for macOS."
{ : </dev/tty; } 2>/dev/null || die "Run this from a terminal window: it asks a few questions."
command -v curl >/dev/null || die "curl not found."
SRC_DIR=""
if [[ -f ${BASH_SOURCE[0]:-} ]]; then SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); fi
if [[ -z $SRC_DIR || ! -f $SRC_DIR/ai || ! -f $SRC_DIR/ai-keys.sh ]]; then   # run via curl | bash
  SRC_DIR="$WORK/src"; mkdir -p "$SRC_DIR"
  for f in ai ai-keys.sh; do
    curl -fsSL --connect-timeout 10 "$REPO_RAW/$f" -o "$SRC_DIR/$f" || die "Couldn't download $f from GitHub. Check your connection and try again."
  done
fi

# ---------- the ai command + key binding ----------
say "The ai command"
mkdir -p "$BIN_DIR"
cp "$SRC_DIR/ai" "$AI_BIN"; chmod +x "$AI_BIN"
cp "$SRC_DIR/ai-keys.sh" "$KEYS"
if [[ -f $HOME/.ai.zsh ]]; then mv "$HOME/.ai.zsh" "$HOME/.ai.zsh.old"; warn "Replaced earlier ~/.ai.zsh (kept as ~/.ai.zsh.old)"; fi
ok "Installed to $(tilde "$AI_BIN")"
export PATH="$BIN_DIR:$PATH"

# ---------- Claude: Claude Code CLI with your Claude subscription ----------
say "Claude  ${D}uses your Claude plan through Claude Code${R}"
HAVE_CLAUDE=0
if ! CLAUDE=$(find_bin claude); then
  if ask_yn "Claude Code isn't installed. Install it now?" y; then
    curl -fsSL https://claude.ai/install.sh | bash
    CLAUDE=$(find_bin claude) || warn "Install finished but 'claude' wasn't found — open a new tab and rerun."
  fi
fi
if [[ -n ${CLAUDE:-} ]]; then
  ok "Claude Code found"; HAVE_CLAUDE=1
  if env -u ANTHROPIC_API_KEY "$CLAUDE" auth status 2>/dev/null | grep -q '"authMethod": *"claude.ai"'; then
    ok "Signed in with your Claude plan"
  elif ask_yn "Sign in to Claude Code with your Claude plan now? (opens your browser)" y; then
    script -q /dev/null env -u ANTHROPIC_API_KEY "$CLAUDE" auth login </dev/tty || true   # a real tty: Claude Code (Bun) crashes on a freshly opened /dev/tty
    if env -u ANTHROPIC_API_KEY "$CLAUDE" auth status 2>/dev/null | grep -q '"authMethod": *"claude.ai"'; then
      ok "Signed in"
    else warn "Not signed in yet — run: claude auth login"; fi
  else warn "Skipped sign-in — run: claude auth login"; fi
else
  warn "Claude skipped"
fi

# ---------- ChatGPT: Codex CLI with your ChatGPT subscription ----------
say "ChatGPT  ${D}uses your ChatGPT plan through Codex${R}"
HAVE_CODEX=0
if ! CODEX=$(find_bin codex); then
  if ask_yn "Codex isn't installed. Install it now?" y; then
    if command -v brew >/dev/null; then brew install --cask codex
    elif command -v npm >/dev/null; then npm install -g @openai/codex
    else warn "Need Homebrew (https://brew.sh) or npm to install Codex."; fi
    CODEX=$(find_bin codex) || warn "Install finished but 'codex' wasn't found — open a new tab and rerun."
  fi
fi
if [[ -n ${CODEX:-} ]]; then
  ok "Codex found"; HAVE_CODEX=1
  if [[ -f $HOME/.codex/auth.json ]]; then
    ok "Signed in"
  elif ask_yn "Sign in to Codex with your ChatGPT account now? (opens your browser)" y; then
    env -u OPENAI_API_KEY "$CODEX" login </dev/tty || true
    if [[ -f $HOME/.codex/auth.json ]]; then ok "Signed in"
    else warn "Not signed in yet — run: codex login"; fi
  else warn "Skipped sign-in — run: codex login"; fi
else
  warn "ChatGPT skipped"
fi

# ---------- optional API keys ----------
say "API keys  ${D}optional, not needed with a plan${R}"
if ask_yn "Set up API keys?" n; then
  command -v jq >/dev/null || { command -v brew >/dev/null && brew install jq; } || warn "API mode needs jq: brew install jq"
  store_key() {  # label envvar service
    local label=$1 env=$2 svc=$3 key=""
    if kc_has "$svc" && ! ask_yn "$label key already saved. Replace it?" n; then ok "$label: keeping saved key"; return 0; fi
    read -r -s -p "     Paste $label API key (Enter to skip): " key </dev/tty || key=""; echo
    key=$(printf '%s' "$key" | tr -d '[:space:]')
    if [[ -z $key ]]; then warn "$label: skipped"; return 0; fi
    kc_set "$svc" "$key" && ok "$label: saved to Keychain"
  }
  store_key "Anthropic" ANTHROPIC_API_KEY "$KC_ANTHROPIC"
  store_key "OpenAI"    OPENAI_API_KEY    "$KC_OPENAI"
else ok "Skipped"; fi
kc_has "$KC_ANTHROPIC" && [[ -z ${CLAUDE:-} ]] && HAVE_CLAUDE=1
kc_has "$KC_OPENAI"    && [[ -z ${CODEX:-} ]]  && HAVE_CODEX=1

# ---------- default provider + shell config (zsh + bash) ----------
say "Shell setup"
DEFAULT=claude
if (( HAVE_CLAUDE && HAVE_CODEX )); then
  read -r -p "     Default for ⌘I — claude or chatgpt? $D[claude]$R " p </dev/tty || p=""
  [[ ${p:-} == c[hg]* || ${p:-} == g* ]] && DEFAULT=chatgpt
elif (( HAVE_CODEX )); then DEFAULT=chatgpt
fi
ok "Default: $DEFAULT   ${D}(ai -c = Claude, ai -g = ChatGPT)${R}"
for f in "${RC_FILES[@]}"; do
  touch "$f"; cp "$f" "$f.ai-backup"
  remove_rc_block "$f"
  {
    printf '\n%s\n' "$BEGIN_MARK"
    printf 'export AI_PROVIDER=%s\n' "$DEFAULT"
    printf '[ -f ~/.ai-keys.sh ] && . ~/.ai-keys.sh\n'
    printf '%s\n' "$END_MARK"
  } >> "$f"
  ok "$(tilde "$f")  ${D}backup: $(basename "$f").ai-backup${R}"
done

# ---------- Cmd+I → Esc+i in the terminal app ----------
say "Keyboard shortcut ⌘I"
MAPPED=0
if [[ -d /Applications/iTerm.app ]]; then
  TMP="$WORK/iterm.plist"
  defaults export com.googlecode.iterm2 "$TMP" 2>/dev/null || /usr/libexec/PlistBuddy -c "Save" "$TMP" >/dev/null
  /usr/libexec/PlistBuddy -c "Print :GlobalKeyMap" "$TMP" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add :GlobalKeyMap dict" "$TMP"
  /usr/libexec/PlistBuddy -c "Delete :GlobalKeyMap:$ITERM_KEY" "$TMP" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy \
    -c "Add :GlobalKeyMap:$ITERM_KEY dict" \
    -c "Add :GlobalKeyMap:$ITERM_KEY:Action integer 10" \
    -c "Add :GlobalKeyMap:$ITERM_KEY:Text string i" "$TMP"
  defaults import com.googlecode.iterm2 "$TMP"
  ok "iTerm2  ${D}restart iTerm2 to apply${R}"; MAPPED=1
fi
if [[ -d /Applications/Ghostty.app ]]; then
  GC="$HOME/.config/ghostty/config"; mkdir -p "$(dirname "$GC")"; touch "$GC"
  grep -qF "cmd+i=esc:i" "$GC" || printf '\n# ai\nkeybind = cmd+i=esc:i\n' >> "$GC"
  ok "Ghostty  ${D}restart Ghostty to apply${R}"; MAPPED=1
fi
if [[ -d /Applications/kitty.app ]]; then
  KCONF="$HOME/.config/kitty/kitty.conf"; mkdir -p "$(dirname "$KCONF")"; touch "$KCONF"
  grep -qF 'map cmd+i send_text all \x1bi' "$KCONF" || printf '\n# ai\nmap cmd+i send_text all \\x1bi\n' >> "$KCONF"
  ok "kitty  ${D}restart kitty to apply${R}"; MAPPED=1
fi
if [[ ${TERM_PROGRAM:-} == Apple_Terminal ]] || (( ! MAPPED )); then
  warn "Terminal.app can't remap ⌘I. Use ⌥I instead: Settings → Profiles → Keyboard → 'Use Option as Meta key'."
fi
(( MAPPED )) || warn "In other terminals, map ⌘I to send Esc+i in the key settings."

# ---------- smoke test ----------
WORKS=0
if (( HAVE_CLAUDE || HAVE_CODEX )) && { say "Test"; ask_yn "Send a test question to check it works?" y; }; then
  for p in claude chatgpt; do
    [[ $p == claude ]] && (( ! HAVE_CLAUDE )) && continue
    [[ $p == chatgpt ]] && (( ! HAVE_CODEX )) && continue
    if spin "Asking ${p}…" env AI_PROVIDER=$p "$AI_BIN" "Reply with exactly: ai works" && grep -qi 'ai works' "$SPIN_OUT"; then
      ok "$p answered"; WORKS=1
    else
      warn "$p didn't answer:"; sed 's/^/       /' "$SPIN_OUT"
    fi
  done
fi

# ---------- done ----------
echo
if (( ! HAVE_CLAUDE && ! HAVE_CODEX )); then
  printf '  %s!%s %sAlmost there.%s Nothing is connected yet: rerun the installer to sign in.\n\n' "$Y" "$R" "$B" "$R"
  exit 1
fi
if (( WORKS )); then printf '  %s✓%s %sYou'\''re all set.%s\n' "$G" "$R" "$B" "$R"
else printf '  %s✓%s %sInstalled.%s\n' "$G" "$R" "$B" "$R"; fi
printf '\n    Open a %snew%s terminal tab, type a question, and press %s⌘I%s.\n' "$B" "$R" "$B" "$R"
printf '    Or run:  %sai "what is using port 8080?"%s\n\n' "$ACC" "$R"
}

main "$@"
