#!/usr/bin/env bash
# todo.sh - lightweight project todo/issue tracker for agentic coding.
#
# Items are markdown files in .todo/, named:
#   {n}_{type}_{priority}_{status}_{title}.md
#
#   n        zero-padded, immutable, unique ID (assigned on creation, never reused)
#   type     feature | issue | enhance
#   priority integer, default 0 (neutral); higher = higher priority; can be negative
#   status   todo | doing | done
#   title    lowercase, hyphen-separated
#
# All state lives in the filename. The file body is free-form notes.
# Depends only on bash 4+ and standard coreutils (mv, cut, sort, awk) -
# no language runtime required, so it works from any agent/harness that can run shell.

set -euo pipefail

TODO_DIR="${TODO_DIR:-.todo}"
ID_WIDTH=3
TYPES="feature issue enhance"
STATUSES="todo doing done"

die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: todo.sh <command> [args]

  init                            Create the $TODO_DIR directory
  new <type> <title> [priority]   Create a new item (priority defaults to 0)
  list [--status=S] [--type=T]    List items, highest priority first
  next                            Show the top-priority open (todo) item
  show <id>                       Print an item's file contents
  start <id>                      Shortcut for: status <id> doing
  done <id>                       Shortcut for: status <id> done
  status <id> <status>            Set status directly (todo|doing|done)
  priority <id> <n>               Set priority directly (integer)
  retitle <id> <new title>        Change the title (keeps id/type/priority/status)
  help                            Show this message

Types: $TYPES
Statuses: $STATUSES
Env: TODO_DIR (default: .todo)
EOF
}

_check_dir() {
  [ -d "$TODO_DIR" ] || die "$TODO_DIR not found. Run 'todo.sh init' first."
}

_valid_in() {
  local val="$1"; shift
  for v in "$@"; do [ "$val" = "$v" ] && return 0; done
  return 1
}

sanitize_title() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

_find_file() {
  local id="$1"
  _check_dir
  local matches=("$TODO_DIR"/"${id}"_*.md)
  [ -e "${matches[0]}" ] || die "no item with id $id"
  [ "${#matches[@]}" -gt 1 ] && die "multiple items match id $id: ${matches[*]}"
  echo "${matches[0]}"
}

_next_id() {
  local max=0 n
  shopt -s nullglob
  for f in "$TODO_DIR"/*.md; do
    n=$(basename "$f" .md | cut -d'_' -f1)
    n=$((10#$n))
    [ "$n" -gt "$max" ] && max=$n
  done
  shopt -u nullglob
  printf "%0${ID_WIDTH}d" $((max + 1))
}

cmd_init() {
  mkdir -p "$TODO_DIR"
  echo "initialized $TODO_DIR"
}

cmd_new() {
  local type="${1:?usage: new <type> <title> [priority]}"
  local title="${2:?usage: new <type> <title> [priority]}"
  local priority="${3:-0}"
  _valid_in "$type" $TYPES || die "type must be one of: $TYPES"
  [[ "$priority" =~ ^-?[0-9]+$ ]] || die "priority must be an integer"
  _check_dir
  local id slug file
  id=$(_next_id)
  slug=$(sanitize_title "$title")
  [ -n "$slug" ] || die "title produced an empty slug"
  file="$TODO_DIR/${id}_${type}_${priority}_todo_${slug}.md"
  cat > "$file" <<EOF
# $title

## Description


## Notes

EOF
  echo "created $file"
}

cmd_list() {
  _check_dir
  local filter_status="" filter_type=""
  for arg in "$@"; do
    case "$arg" in
      --status=*) filter_status="${arg#--status=}" ;;
      --type=*) filter_type="${arg#--type=}" ;;
      *) die "unknown option: $arg" ;;
    esac
  done
  shopt -s nullglob
  local rows=() f base id type priority status title
  for f in "$TODO_DIR"/*.md; do
    base=$(basename "$f" .md)
    id=$(echo "$base" | cut -d'_' -f1)
    type=$(echo "$base" | cut -d'_' -f2)
    priority=$(echo "$base" | cut -d'_' -f3)
    status=$(echo "$base" | cut -d'_' -f4)
    title=$(echo "$base" | cut -d'_' -f5-)
    [ -n "$filter_status" ] && [ "$status" != "$filter_status" ] && continue
    [ -n "$filter_type" ] && [ "$type" != "$filter_type" ] && continue
    rows+=("$priority	$id	$type	$status	$title")
  done
  shopt -u nullglob
  if [ "${#rows[@]}" -eq 0 ]; then
    echo "no matching items"
    return 0
  fi
  printf '%s\n' "${rows[@]}" | sort -t"$(printf '\t')" -k1,1nr -k2,2n | \
    awk -F'\t' '{printf "%-4s %-8s p%-4s %-6s %s\n", $2, $3, $1, $4, $5}'
}

cmd_next() {
  local out
  out=$(cmd_list --status=todo)
  if [ "$out" = "no matching items" ]; then
    echo "no open todo items"
    return 0
  fi
  echo "$out" | head -n1
}

cmd_show() {
  local id="${1:?usage: show <id>}"
  cat "$(_find_file "$id")"
}

cmd_status() {
  local id="${1:?usage: status <id> <status>}"
  local newstatus="${2:?usage: status <id> <status>}"
  _valid_in "$newstatus" $STATUSES || die "status must be one of: $STATUSES"
  local file base id_p type priority title newfile
  file=$(_find_file "$id")
  base=$(basename "$file" .md)
  id_p=$(echo "$base" | cut -d'_' -f1)
  type=$(echo "$base" | cut -d'_' -f2)
  priority=$(echo "$base" | cut -d'_' -f3)
  title=$(echo "$base" | cut -d'_' -f5-)
  newfile="$TODO_DIR/${id_p}_${type}_${priority}_${newstatus}_${title}.md"
  mv "$file" "$newfile"
  echo "moved $id to $newstatus: $newfile"
}

cmd_priority() {
  local id="${1:?usage: priority <id> <n>}"
  local newpriority="${2:?usage: priority <id> <n>}"
  [[ "$newpriority" =~ ^-?[0-9]+$ ]] || die "priority must be an integer"
  local file base id_p type status title newfile
  file=$(_find_file "$id")
  base=$(basename "$file" .md)
  id_p=$(echo "$base" | cut -d'_' -f1)
  type=$(echo "$base" | cut -d'_' -f2)
  status=$(echo "$base" | cut -d'_' -f4)
  title=$(echo "$base" | cut -d'_' -f5-)
  newfile="$TODO_DIR/${id_p}_${type}_${newpriority}_${status}_${title}.md"
  mv "$file" "$newfile"
  echo "set $id priority to $newpriority: $newfile"
}

cmd_retitle() {
  local id="${1:?usage: retitle <id> <new title>}"; shift
  local newtitle="$*"
  [ -n "$newtitle" ] || die "usage: retitle <id> <new title>"
  local file base id_p type priority status newslug newfile
  file=$(_find_file "$id")
  base=$(basename "$file" .md)
  id_p=$(echo "$base" | cut -d'_' -f1)
  type=$(echo "$base" | cut -d'_' -f2)
  priority=$(echo "$base" | cut -d'_' -f3)
  status=$(echo "$base" | cut -d'_' -f4)
  newslug=$(sanitize_title "$newtitle")
  newfile="$TODO_DIR/${id_p}_${type}_${priority}_${status}_${newslug}.md"
  mv "$file" "$newfile"
  echo "retitled $id: $newfile"
}

cmd_start() { cmd_status "$1" doing; }
cmd_finish() { cmd_status "$1" done; }

case "${1:-help}" in
  init) shift; cmd_init "$@" ;;
  new) shift; cmd_new "$@" ;;
  list) shift; cmd_list "$@" ;;
  next) shift; cmd_next "$@" ;;
  show) shift; cmd_show "$@" ;;
  start) shift; cmd_start "$@" ;;
  done) shift; cmd_finish "$@" ;;
  status) shift; cmd_status "$@" ;;
  priority) shift; cmd_priority "$@" ;;
  retitle) shift; cmd_retitle "$@" ;;
  help|--help|-h) usage ;;
  *) die "unknown command: $1 (see 'todo.sh help')" ;;
esac
