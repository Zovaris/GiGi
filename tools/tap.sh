#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="Zovaris/GiGi"
TAP="sthbryan/homebrew-tap"
CASK="Casks/gigi.rb"

version="$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)"
if [ $# -gt 0 ] && [ -n "$1" ]; then
  version="${1#v}"
fi
tag="v$version"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "==> reading the published checksum of $tag"
gh release download "$tag" --repo "$PROJECT" --pattern "*.zip.sha256" --dir "$work" >/dev/null
sha="$(awk '{print $1}' "$work"/*.zip.sha256)"
[ -n "$sha" ] || { echo "no checksum in the release asset" >&2; exit 1; }
echo "    $sha"

echo "==> cloning $TAP"
gh repo clone "$TAP" "$work/tap" >/dev/null

file="$work/tap/$CASK"
[ -f "$file" ] || { echo "$CASK does not exist in $TAP" >&2; exit 1; }
current="$(sed -n 's/^  version "\(.*\)"$/\1/p' "$file")"
if [ "$current" = "$version" ]; then
  echo "==> the cask already points at $version, nothing to do"
  exit 0
fi

sed -e "s/^  version \".*\"$/  version \"$version\"/" -e "s/^  sha256 \".*\"$/  sha256 \"$sha\"/" "$file" > "$file.new"
mv "$file.new" "$file"

echo "==> committing $CASK $current -> $version"
git -C "$work/tap" commit -q -am "gigi $version"
git -C "$work/tap" push -q
echo "done: brew update && brew upgrade --cask gigi"
