#!/usr/bin/env bash
# Fails when a tracked file runs sudo with -E (alone or in a short-flag cluster) or with a
# bare --preserve-env. sudo-rs, the sudo of Ubuntu 26.04 and of the HAF image, ignores both
# and hands the command a reset environment; name the variables with --preserve-env=A,B.
#
#   scripts/ci-helpers/check_sudo_preserve_env.sh [FILE]...
#
# Without arguments it checks every tracked file except Markdown. Only sudo's own options
# are inspected, so the -E in `sudo sed -E ...` (an option of sed) is not reported.
set -euo pipefail

# sudo options that consume a value: as the rest of a short-flag cluster or the next word.
readonly SHORT_WITH_VALUE="CDghpRrTtUu"
readonly LONG_WITH_VALUE=" --chdir --chroot --close-from --command-timeout --group --host --other-user --prompt --role --type --user "

# Prints the first environment-preserving option among sudo's options in the words, if any.
offending_option() {
  local -a words=("$@")
  local i=0 word flags j
  while [ "$i" -lt "${#words[@]}" ]; do
    word="${words[$i]}"
    word="${word#[\"\']}"
    word="${word%[\"\']}"
    case "$word" in
      --) return ;;
      --preserve-env) printf '%s\n' "$word"; return ;;
      --*=*) ;;
      --*) [[ "$LONG_WITH_VALUE" == *" $word "* ]] && i=$((i + 1)) ;;
      -[A-Za-z]*)
        flags="${word#-}"
        for ((j = 0; j < ${#flags}; j++)); do
          if [ "${flags:j:1}" = E ]; then
            printf '%s\n' "$word"
            return
          fi
          if [[ "$SHORT_WITH_VALUE" == *"${flags:j:1}"* ]]; then
            [ "$j" -eq $((${#flags} - 1)) ] && i=$((i + 1))
            break
          fi
        done
        ;;
      *) return ;;
    esac
    i=$((i + 1))
  done
}

check_file() {
  local file="$1" lineno line rest option found=0
  local -a words
  while IFS=: read -r lineno line; do
    rest="$line"
    while [[ "$rest" =~ (^|[^[:alnum:]_.-])sudo([[:space:]]+(.*))?$ ]]; do
      rest="${BASH_REMATCH[3]}"
      read -ra words <<< "$rest"
      option="$(offending_option "${words[@]}")"
      if [ -n "$option" ]; then
        echo "${file}:${lineno}: sudo ${option} does not preserve the environment under sudo-rs; use --preserve-env=VAR,..."
        found=1
        break
      fi
    done
  done < <(grep -InwE 'sudo' "$file" || true)
  return "$found"
}

main() {
  local -a files=("$@")
  local file status=0
  if [ "${#files[@]}" -eq 0 ]; then
    cd "$(git rev-parse --show-toplevel)"
    mapfile -t files < <(git ls-files | grep -v '\.md$')
  fi
  for file in "${files[@]}"; do
    [ -f "$file" ] || continue
    check_file "$file" || status=1
  done
  return "$status"
}

main "$@"
