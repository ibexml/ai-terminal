#!/bin/bash
# test.sh — syntax-check the three files, then run `ai` against a fake `claude` that replays a canned
# stream-json answer: raw markdown when piped, rendered under a pseudo-terminal, and a sign-in failure.
# Needs no sign-in or network. Prints "ok" and exits 0, or the first failure and exits 1.
cd "$(dirname "$0")" || exit 1
fail() { printf 'FAIL: %s\n' "$1" >&2; [[ -n ${2:-} ]] && cat -v "$2" >&2; exit 1; }

for f in ai install.sh ai-keys.sh; do bash -n "$f" || fail "bash -n $f"; done
zsh -n ai-keys.sh || fail "zsh -n ai-keys.sh"

T=$(mktemp -d -t aitest) || exit 1
trap 'rm -rf "$T"' EXIT
cat >"$T/claude" <<'EOF'
#!/bin/bash
if [[ ${FAKE:-} == auth ]]; then
  echo '{"type":"result","subtype":"success","is_error":true,"result":"Failed to authenticate: expired"}'; exit 1
fi
echo '{"type":"system","subtype":"init"}'
for t in '# Title\n' 'A **bold** word, `code` and [docs](https://example.com/d).\n' '\n- bullet\n' '```bash\necho hi\n```\n' 'Done'; do
  echo "{\"type\":\"stream_event\",\"event\":{\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"$t\"}}}"
done
echo '{"type":"result","subtype":"success","is_error":false,"result":"x"}'
EOF
chmod +x "$T/claude"
# clean environment: the user's AI_* settings and NO_COLOR stay out; HOME is the temp dir (ai cd's there)
ENV=(env -i PATH="$T:$PATH" HOME="$T" TERM=xterm-256color AI_ANIMATE=0)

# A: piped, stdout must be the raw markdown (the last delta has no newline; ai adds exactly one)
printf '%s\n' '# Title' 'A **bold** word, `code` and [docs](https://example.com/d).' '' '- bullet' '```bash' 'echo hi' '```' 'Done' >"$T/exp"
"${ENV[@]}" bash ai hi </dev/null 2>/dev/null | cat >"$T/a"
diff "$T/exp" "$T/a" >&2 || fail "piped output isn't the raw markdown"

# B: pseudo-terminal via script(1), then undo what a terminal would show: text erased by CR+ESC[J/K (the
# spinner line and raw lines the renderer redraws), ANSI and OSC escapes, CR and the ^D^H^H script echoes
E=$'\e' CR=$'\r' BEL=$'\a'
script -q /dev/null "${ENV[@]}" bash ai hi </dev/null |
  sed -E "s/[^$CR]*$CR$E\[[JK]//g; s/$E\[[0-9;?]*[A-Za-z]//g; s/$E\][^$BEL$E]*($BEL|$E\\\\)//g" | tr -d '\r\004\010' >"$T/b"
for s in Title '• bullet' '  echo hi' 'docs https://example.com/d'; do
  grep -qF -- "$s" "$T/b" || fail "terminal output lacks '$s'" "$T/b"
done
for s in '#' '**' '`'; do grep -qF -- "$s" "$T/b" && fail "terminal output still has '$s'" "$T/b"; done

# C: Claude Code not signed in, piped: clear message and exit 1
"${ENV[@]}" FAKE=auth bash ai hi </dev/null >"$T/c" 2>&1; rc=$?
(( rc == 1 )) || fail "sign-in failure exited $rc, not 1" "$T/c"
grep -qF "Claude Code isn't signed in" "$T/c" && grep -qF 'Fix:' "$T/c" || fail "sign-in failure message" "$T/c"
echo ok
