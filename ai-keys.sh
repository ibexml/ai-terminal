# ai-keys.sh — Cmd+I (sent by the terminal as Esc+i) asks AI about the current line.
# Sourced from ~/.zshrc and ~/.bash_profile by install.sh. Works in zsh and bash.
case $- in *i*) ;; *) return 0 ;; esac

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac

if [ -n "${ZSH_VERSION:-}" ]; then
  # Typing `ai what is this?` directly: stop zsh from globbing the `?`.
  alias ai='noglob ai'
  # Whatever is typed becomes the question, safely quoted. Empty line -> "Ask:" prompt.
  _ai_widget() {
    local q=${BUFFER%"${BUFFER##*[^[:space:]]}"}   # drop trailing spaces
    if [[ -n ${q//[[:space:]]/} ]]; then BUFFER="ai ${(q)q}"; else BUFFER="ai"; fi
    zle accept-line
  }
  zle -N _ai_widget
  bindkey '\ei' _ai_widget
elif [ -n "${BASH_VERSION:-}" ]; then
  # Wraps the typed line in a quoted heredoc, so quotes/?/* in the question are safe.
  # Works on macOS's stock bash 3.2 as well as bash 5.
  bind "\"\\ei\": \"\\C-aai <<'__AI__'\\C-v\\C-j\\C-e\\C-v\\C-j__AI__\\C-m\""
fi
