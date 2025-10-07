#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <old-hyphen-name> <new-hyphen-name>"
  echo "Example: $0 template-python-project my-cool-project"
  exit 1
}

[[ $# -eq 2 ]] || usage

OLD_HY="$1"
NEW_HY="$2"
OLD_US="${OLD_HY//-/_}"
NEW_US="${NEW_HY//-/_}"

# Ensure simple slugs to keep sed safe (lowercase, digits, hyphens only)
slug_re='^[a-z0-9-]+$'
if [[ ! "$OLD_HY" =~ $slug_re || ! "$NEW_HY" =~ $slug_re ]]; then
  echo "Error: names must be lowercase slugs with [a-z0-9-]."
  exit 2
fi

echo "Renaming:"
echo "  hyphenated:  $OLD_HY  ->  $NEW_HY"
echo "  underscored: $OLD_US  ->  $NEW_US"
echo

# Detect GNU vs BSD sed for in-place editing
# GNU: sed -i -e '...'
# BSD (macOS): sed -i '' -e '...'
SED_INPLACE=(sed -i)
if sed --version > /dev/null 2>&1; then
  SED_INPLACE=(sed -i) # GNU sed
else
  SED_INPLACE=(sed -i '') # BSD sed
fi

# Exclude paths
is_excluded() {
  case "$1" in
  ./.* | ./.git/* | ./.git) return 0 ;;
  ./result* | ./.venv* | ./.uv* | ./dist* | ./build* | ./__pycache__*) return 0 ;;
  *) return 1 ;;
  esac
}

# 1) Replace contents in files (text-ish)
echo "Updating file contents..."
# Find regular files, skipping excluded dirs
while IFS= read -r -d '' f; do
  if is_excluded "$f"; then
    continue
  fi
  # Only touch reasonably small text files to avoid binary garbage
  # (adjust max size if you like)
  if [ ! -s "$f" ] || [ "$(du -k "$f" | cut -f1)" -gt 2048 ]; then
    continue
  fi
  # Skip binaries by simple heuristic
  if file "$f" | grep -qiE 'binary|image|archive|audio|video'; then
    continue
  fi
  "${SED_INPLACE[@]}" -e "s|$OLD_HY|$NEW_HY|g" -e "s|$OLD_US|$NEW_US|g" "$f" || true
done < <(find . -type f -print0)

# 2) Rename files & directories (process deepest paths first)
echo "Renaming files and directories..."
# Use -depth to rename children before parents, skip excluded
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

echo "Done."
echo "Tip: update 'project.name' in pyproject.toml to '$NEW_HY' if you haven't already."
