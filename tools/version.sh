#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Resources/Info.plist"
CHANGELOG="$ROOT/CHANGELOG.md"
BUMP=patch
TARGET=""
DRY=0
PUSH=1

usage() {
  cat <<MSG
usage: tools/version.sh [--bump patch|minor|major] [--version X.Y.Z] [--dry-run] [--no-push]

  --bump      which number to raise when --version is not given (default patch)
  --version   the exact version to release
  --dry-run   print the plan and change nothing
  --no-push   commit and tag locally, do not push
MSG
}

normalize() {
  IFS=. read -r a b c <<< "$1"
  echo "${a:-0}.${b:-0}.${c:-0}"
}

upper_first() {
  printf '%s%s' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')" "${1:1}"
}

bullets() {
  local line
  for line in "$@"; do printf -- '- %s\n' "$line"; done
}

insert_section() {
  local file="$1" body="$2" tmp chunk
  tmp="$(mktemp)"
  chunk="$tmp.section"
  printf '%s\n' "$body" > "$chunk"
  awk -v src="$chunk" '
    !inserted && /^## / { while ((getline line < src) > 0) print line; print ""; inserted = 1 }
    { print }
    END { if (!inserted) { print ""; while ((getline line < src) > 0) print line } }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  rm -f "$chunk"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --bump) BUMP="${2:?}"; shift 2 ;;
    --version) TARGET="${2:?}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --no-push) PUSH=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1"; usage; exit 2 ;;
  esac
done

current="$(normalize "$(plutil -extract CFBundleShortVersionString raw "$PLIST")")"

if [ -n "$TARGET" ]; then
  [[ "$TARGET" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || { echo "not a version: $TARGET (expected X.Y.Z)"; exit 2; }
  next="$(normalize "$TARGET")"
else
  IFS=. read -r major minor patch <<< "$current"
  case "$BUMP" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    major) major=$((major + 1)); minor=0; patch=0 ;;
    *) echo "--bump takes patch, minor or major (got $BUMP)"; exit 2 ;;
  esac
  next="$major.$minor.$patch"
fi

[ "$next" != "$current" ] || { echo "the version is already $current"; exit 2; }

tag="v$next"
message="chore: release $tag"
branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
today="$(date +%F)"
previous="$(git -C "$ROOT" describe --tags --abbrev=0 HEAD 2>/dev/null || true)"

added=()
fixed=()
changed=()
while IFS= read -r subject; do
  case "$subject" in
    *": "*) ;;
    *) continue ;;
  esac
  text="$(upper_first "${subject#*: }")"
  type="${subject%%:*}"
  type="${type%%(*}"
  case "$type" in
    feat) added+=("$text") ;;
    fix) fixed+=("$text") ;;
    perf|refactor|revert) changed+=("$text") ;;
  esac
done < <(git -C "$ROOT" log --no-merges --pretty=%s ${previous:+"$previous.."}HEAD)

entries=$(( ${#added[@]} + ${#fixed[@]} + ${#changed[@]} ))
section="## $next - $today"
if [ "${#added[@]}" -gt 0 ]; then section+=$'\n\n**Added**\n\n'"$(bullets "${added[@]}")"; fi
if [ "${#fixed[@]}" -gt 0 ]; then section+=$'\n\n**Fixed**\n\n'"$(bullets "${fixed[@]}")"; fi
if [ "${#changed[@]}" -gt 0 ]; then section+=$'\n\n**Changed**\n\n'"$(bullets "${changed[@]}")"; fi
if [ "$entries" -eq 0 ]; then section+=$'\n\n'"$(bullets "Maintenance release")"; fi

if [ "$DRY" = "1" ]; then
  echo "version:   $current -> $next"
  echo "plist:     Resources/Info.plist  CFBundleShortVersionString and CFBundleVersion"
  echo "changelog: CHANGELOG.md  $entries entries since ${previous:-the first commit}"
  echo "commit:    $message"
  echo "tag:       $tag (annotated)"
  echo "push:      $([ "$PUSH" = "1" ] && echo "origin $branch and $tag" || echo "no")"
  echo
  printf '%s\n' "$section"
  exit 0
fi

if ! git -C "$ROOT" diff --quiet HEAD; then
  echo "the working tree has uncommitted changes; commit or stash them first"
  git -C "$ROOT" status --short
  exit 1
fi

if git -C "$ROOT" rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
  echo "tag $tag already exists"
  exit 1
fi

plutil -replace CFBundleShortVersionString -string "$next" "$PLIST"
plutil -replace CFBundleVersion -string "$next" "$PLIST"

[ -f "$CHANGELOG" ] || printf '# Changelog\n' > "$CHANGELOG"
insert_section "$CHANGELOG" "$section"
echo "changelog: added $entries entries for $next"

git -C "$ROOT" add Resources/Info.plist CHANGELOG.md
git -C "$ROOT" commit -q -m "$message"
git -C "$ROOT" tag -a "$tag" -m "GiGi $tag"
echo "committed $(git -C "$ROOT" rev-parse --short HEAD) and tagged $tag"

if [ "$PUSH" = "1" ]; then
  git -C "$ROOT" push origin "$branch"
  git -C "$ROOT" push origin "$tag"
  echo "pushed $branch and $tag; the release workflow builds and publishes from there"
else
  echo "not pushed: run 'git push origin $branch && git push origin $tag' when you are ready"
fi

"$ROOT/build.sh" "$next" > /dev/null
echo "rebuilt bin/gigi and app/GiGi.app with version $next"
