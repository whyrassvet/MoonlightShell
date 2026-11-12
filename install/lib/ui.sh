# shellcheck shell=bash
# shellcheck disable=SC2034
# Small terminal UI: colors, banner, steps, spinner, arrow-key menus. No dependencies.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C0=$'\e[0m'; CB=$'\e[1m'; CD=$'\e[2m'; CI=$'\e[3m'
  CR=$'\e[38;5;203m'; CG=$'\e[38;5;114m'; CY=$'\e[38;5;221m'; CBL=$'\e[38;5;111m'
  CW=$'\e[38;5;255m'; CG1=$'\e[38;5;250m'; CG2=$'\e[38;5;245m'; CG3=$'\e[38;5;240m'
else
  C0=; CB=; CD=; CI=; CR=; CG=; CY=; CBL=; CW=; CG1=; CG2=; CG3=
fi

IS_TTY=0; [ -t 0 ] && [ -t 1 ] && IS_TTY=1
hide_cursor() { [ "$IS_TTY" = 1 ] && printf '\e[?25l'; return 0; }
show_cursor() { [ "$IS_TTY" = 1 ] && printf '\e[?25h'; return 0; }
trap 'show_cursor' EXIT

W=60   # inner width of boxes

hr()   { printf '  %s%s%s\n' "$CG3" "$(printf '─%.0s' $(seq 1 $((W + 2))))" "$C0"; }
boxline() { printf '  %s│%s %-*s %s│%s\n' "$CG3" "$C0" "$W" "$1" "$CG3" "$C0"; }

banner() {
  local top bot
  top="$(printf '─%.0s' $(seq 1 $((W + 2))))"
  bot="$top"
  printf '\n  %s╭%s╮%s\n' "$CG3" "$top" "$C0"
  printf '  %s│%s %s%s%-*s%s %s│%s\n' "$CG3" "$C0" "$CB" "$CW" "$W" "D A R K S H A D O W ' S   S H E L L" "$C0" "$CG3" "$C0"
  printf '  %s│%s %s%-*s%s %s│%s\n' "$CG3" "$C0" "$CG2" "$W" "Hyprland / niri  +  Quickshell" "$C0" "$CG3" "$C0"
  printf '  %s│%s %s%-*s%s %s│%s\n' "$CG3" "$C0" "$CG3" "$W" "installer  V${RICE_VERSION:-}" "$C0" "$CG3" "$C0"
  printf '  %s╰%s╯%s\n\n' "$CG3" "$bot" "$C0"
}

info()  { printf '    %s•%s %s\n' "$CG2" "$C0" "$*"; }
ok()    { printf '    %s✔%s %s\n' "$CG" "$C0" "$*"; }
warn()  { printf '    %s!%s %s\n' "$CY" "$C0" "$*"; }
fail()  { printf '    %s✘%s %s\n' "$CR" "$C0" "$*" >&2; }
note()  { printf '      %s%s%s\n' "$CG3" "$*" "$C0"; }
title() { printf '\n  %s%s%s\n' "$CB" "$*" "$C0"; }
kv()    { printf '    %s%-10s%s %s\n' "$CG2" "$1" "$C0" "$2"; }

# step N "Title" "what happens"
STEP_TOTAL=0
step() {
  printf '\n  %s%s[%s/%s]%s %s%s%s\n' "$CB" "$CW" "$1" "$STEP_TOTAL" "$C0" "$CB" "$2" "$C0"
  [ -n "${3:-}" ] && printf '        %s%s%s\n' "$CG2" "$3" "$C0"
  return 0
}

# task "message" cmd args...  -> spinner, output to $LOG, never blocks on a terminal prompt
task() {
  local msg="$1"; shift
  if [ "${DRY_RUN:-0}" = 1 ]; then printf '    %s○%s %s %s(dry run)%s\n' "$CG3" "$C0" "$msg" "$CG3" "$C0"; return 0; fi
  if [ "$IS_TTY" != 1 ]; then
    # Settings > Update Center reads this output live: there the step shows as running until ✔ or ✘ comes
    [ "${RICE_GUI:-0}" = 1 ] && printf '    ▶ %s\n' "$msg"
    if "$@" >>"$LOG" 2>&1 </dev/null; then ok "$msg"; return 0; else fail "$msg  (details: $LOG)"; return 1; fi
  fi
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏') i=0 pid rc t0
  t0=$SECONDS
  { echo; echo "### $msg"; } >>"$LOG"
  "$@" >>"$LOG" 2>&1 </dev/null &
  pid=$!
  hide_cursor
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r    %s%s%s %s %s%ss%s\e[K' "$CBL" "${frames[i % 10]}" "$C0" "$msg" "$CG3" "$((SECONDS - t0))" "$C0"
    i=$((i + 1)); sleep 0.08
  done
  wait "$pid"; rc=$?
  show_cursor
  printf '\r\e[K'
  if [ "$rc" = 0 ]; then ok "$msg"; else fail "$msg  (details: $LOG)"; fi
  return "$rc"
}

read_key() {
  local k rest
  IFS= read -rsn1 k || { echo quit; return; }
  case "$k" in
    $'\e') IFS= read -rsn2 -t 0.05 rest || true
           case "$rest" in '[A') echo up ;; '[B') echo down ;; *) echo quit ;; esac ;;
    '') echo enter ;;
    ' ') echo space ;;
    k) echo up ;; j) echo down ;; q) echo quit ;;
    *) echo other ;;
  esac
}

# menu_select "Title" "label|hint" ...  -> MENU_CHOICE (0-based)
menu_select() {
  local ttl="$1"; shift
  local opts=("$@") n=$# cur=0 key i lab hint
  MENU_CHOICE=0
  title "$ttl"
  if [ "$IS_TTY" != 1 ] || [ "${ASSUME_YES:-0}" = 1 ]; then info "${opts[0]%%|*}"; return 0; fi
  hide_cursor
  while :; do
    for i in "${!opts[@]}"; do
      lab="${opts[i]%%|*}"; hint=""; [[ "${opts[i]}" == *"|"* ]] && hint="${opts[i]#*|}"
      if [ "$i" = "$cur" ]; then printf '    %s❯ %s%s  %s%s%s\e[K\n' "$CW$CB" "$lab" "$C0" "$CG2" "$hint" "$C0"
      else printf '      %s%s%s\e[K\n' "$CG2" "$lab" "$C0"; fi
    done
    printf '    %s↑ ↓ move   enter select   q quit%s\e[K' "$CG3" "$C0"
    key="$(read_key)"
    case "$key" in
      up) cur=$(( (cur - 1 + n) % n )) ;;
      down) cur=$(( (cur + 1) % n )) ;;
      enter) break ;;
      quit) show_cursor; printf '\n'; fail "Cancelled."; exit 130 ;;
    esac
    printf '\r\e[%dA' "$n"
  done
  printf '\r\e[K'
  show_cursor
  MENU_CHOICE=$cur
}

# menu_multi "Title" "label|hint|1" ... -> MENU_SEL (0/1 each)
menu_multi() {
  local ttl="$1"; shift
  local labels=() hints=() sel=() n=$# cur=0 key i item rest
  for item in "$@"; do
    labels+=("${item%%|*}"); rest="${item#*|}"
    hints+=("${rest%|*}"); sel+=("${item##*|}")
  done
  title "$ttl"
  if [ "$IS_TTY" = 1 ] && [ "${ASSUME_YES:-0}" != 1 ]; then
    hide_cursor
    while :; do
      for i in "${!labels[@]}"; do
        local box="${CG3}○${C0}"; [ "${sel[i]}" = 1 ] && box="${CG}●${C0}"
        if [ "$i" = "$cur" ]; then printf '    %s❯%s %s %s%s%s  %s%s%s\e[K\n' "$CW" "$C0" "$box" "$CB" "${labels[i]}" "$C0" "$CG2" "${hints[i]}" "$C0"
        else printf '      %s %s%s%s\e[K\n' "$box" "$CG1" "${labels[i]}" "$C0"; fi
      done
      printf '    %s↑ ↓ move   space on/off   enter continue%s\e[K' "$CG3" "$C0"
      key="$(read_key)"
      case "$key" in
        up) cur=$(( (cur - 1 + n) % n )) ;;
        down) cur=$(( (cur + 1) % n )) ;;
        space) if [ "${sel[cur]}" = 1 ]; then sel[cur]=0; else sel[cur]=1; fi ;;
        enter) break ;;
        quit) show_cursor; printf '\n'; fail "Cancelled."; exit 130 ;;
      esac
      printf '\r\e[%dA' "$n"
    done
    printf '\r\e[K'
    show_cursor
  else
    for i in "${!labels[@]}"; do [ "${sel[i]}" = 1 ] && info "${labels[i]}"; done
  fi
  MENU_SEL=("${sel[@]}")
}

# like confirm, but Enter means no (for things like a reboot)
confirm_no() {
  local a
  [ "$IS_TTY" = 1 ] || return 1
  printf '\n    %s%s%s %s[y/N]%s ' "$CB" "$1" "$C0" "$CG2" "$C0"
  IFS= read -r a || return 1
  case "$a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

confirm() {
  local a
  if [ "${ASSUME_YES:-0}" = 1 ] || [ "$IS_TTY" != 1 ]; then return 0; fi
  printf '\n    %s%s%s %s[Y/n]%s ' "$CB" "$1" "$C0" "$CG2" "$C0"
  IFS= read -r a || return 1
  case "${a:-y}" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
