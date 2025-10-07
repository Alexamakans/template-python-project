#!/usr/bin/env bash
# rename.sh — safely rename a template across contents and file/directory names.
# Usage: ./rename.sh <old-hyphen-name> <new-hyphen-name> [--verbose]
# Example: ./rename.sh template-python-project my-cool-project
#
# It replaces:
#   old-hyphen      -> new-hyphen
#   old_underscore  -> new_underscore
# in file contents, and renames matching files/directories.
set -euo pipefail

usage() {
  cat << 'USAGE'
Usage: ./rename.sh <old-hyphen-name> <new-hyphen-name> [--verbose]

Example:
  ./rename.sh template-python-project my-cool-project

This also converts underscores accordingly:
  template_python_project -> my_cool_project
USAGE
  exit 1
}

VERBOSE=0
log() { if [[ "$VERBOSE" -eq 1 ]]; then echo "$@"; fi; }

# ---- prerequisite checks ----------------------------------------------------

require_cmd() {
  local cmd="$1"
  shift
  local help="${*:-}"
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "Error: required command '$cmd' is not installed." >&2
    if [[ -n "${help}" ]]; then
      echo "       ${help}" >&2
    fi
    MISSING=1
  fi
}

MISSING=0
require_cmd sed "On macOS: 'brew install gnu-sed' (optional). This script also supports BSD sed."
require_cmd find "Usually provided by your OS. On macOS: part of the base system."
require_cmd mv "Usually provided by coreutils / base system."
require_cmd file "Install package 'file'. On macOS: 'brew install file'."
require_cmd du "Usually provided by coreutils / base system."
require_cmd grep "Usually provided by base system. On macOS: 'brew install grep' for GNU grep (optional)."
require_cmd cut "Usually provided by coreutils / base system."
require_cmd dirname "Usually provided by coreutils / base system."
require_cmd basename "Usually provided by coreutils / base system."

if [[ "$MISSING" -ne 0 ]]; then
  echo
  echo "Please install the missing tools and rerun ./rename.sh." >&2
  exit 2
fi

# ---- args & validation ------------------------------------------------------

[[ $# -ge 2 ]] || usage

OLD_HY="$1"
shift
NEW_HY="$1"
shift
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
  shift
fi

OLD_US="${OLD_HY//-/_}"
NEW_US="${NEW_HY//-/_}"

slug_re='^[a-z0-9-]+$'
if [[ ! "$OLD_HY" =~ $slug_re || ! "$NEW_HY" =~ $slug_re ]]; then
  echo "Error: names must be lowercase slugs with [a-z0-9-]." >&2
  echo "Given: OLD='$OLD_HY'  NEW='$NEW_HY'" >&2
  exit 3
fi

if [[ "$OLD_HY" == "$NEW_HY" ]]; then
  echo "Nothing to do: old and new names are identical." >&2
  exit 0
fi

cat << INFO
Renaming:
  hyphenated:  $OLD_HY  ->  $NEW_HY
  underscored: $OLD_US  ->  $NEW_US

INFO

# ---- sed flavor detection ---------------------------------------------------

# Detect GNU vs BSD sed for in-place editing.
# GNU: sed -i -e '...'
# BSD (macOS): sed -i '' -e '...'
SED_INPLACE=(sed -i) # default assume GNU sed
if ! sed --version > /dev/null 2>&1; then
  # BSD sed (no --version)
  SED_INPLACE=(sed -i '')
fi

edited_count=0
pass_replace_contents() {
  local pass="$1"
  echo "Updating file contents (pass ${pass}; skipping large/binary files)..."
  while IFS= read -r -d '' f; do
    if is_excluded "$f"; then
      continue
    fi

    # Skip empty files
    if [[ ! -s "$f" ]]; then
      continue
    fi

    # Skip very large files (> 2 MiB)
    if [[ "$(du -k "$f" | cut -f1)" -gt 2048 ]]; then
      continue
    fi

    # Skip obvious binary files
    if file "$f" | grep -qiE 'binary|image|archive|audio|video|mach-o|executable'; then
      continue
    fi

    # Only run sed if something matches to keep logs clean
    if grep -q -E "$OLD_HY|$OLD_US" "$f"; then
      log "  editing: $f"
      "${SED_INPLACE[@]}" -e "s|$OLD_HY|$NEW_HY|g" -e "s|$OLD_US|$NEW_US|g" "$f" || true
      edited_count=$((edited_count + 1))
    fi
  done < <(find . -type f -print0)
}

# ---- exclusions -------------------------------------------------------------

is_excluded() {
  case "$1" in
  ./.* | ./.git/* | ./.git) return 0 ;;
  ./result* | ./.venv* | ./.uv* | ./dist* | ./build* | ./__pycache__* | ./.direnv* | ./node_modules*) return 0 ;;
  *) return 1 ;;
  esac
}

# ---- 1st pass: contents, before path renames --------------------------------
pass_replace_contents 1

# ---- path renames -----------------------------------------------------------
echo "Renaming files and directories..."
# Use -depth to rename children before parents
while IFS= read -r -d '' path; do
  if is_excluded "$path"; then
    continue
  fi
  base="$(basename "$path")"
  dir="$(dirname "$path")"
  newbase="${base//$OLD_HY/$NEW_HY}"
  newbase="${newbase//$OLD_US/$NEW_US}"
  if [[ "$newbase" != "$base" ]]; then
    newpath="$dir/$newbase"
    echo "mv -v \"$path\" \"$newpath\""
    mv -v "$path" "$newpath"
  fi
done < <(find . -depth -print0)

# ---- 2nd pass: contents, after path renames ---------------------------------
pass_replace_contents 2

echo
echo "Edited files (content changes): $edited_count"
cat << DONE

Done ✅
Next steps:
  1) Review the changes:    git status && git diff
  2) Update project metadata if needed (e.g., [project.name] in pyproject.toml).
  3) Run tests:             uv lock && uv sync && uvx pytest -q

DONE
