#!/usr/bin/env bash
#
# Fills linux/ and windows/ next to this script with the DeckLink headers of one Blackmagic
# Desktop Video SDK, so cross_compile_ffmpeg.sh builds both platforms against the same version:
#
#   ./update.sh "/path/to/Blackmagic DeckLink SDK 15.3"
#
# linux/ is Linux/include copied as is. windows/ is generated from the SDK's Win/include IDL with
# widl, the way the decklink-headers mirror does it. widl and the mingw-w64 IDL files it imports
# are fetched into a temporary directory - nothing gets installed.
#
set -euo pipefail

sdk="${1:?usage: $0 /path/to/unpacked/Blackmagic DeckLink SDK}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mingw_headers_tag=v11.0.1 # same mingw-w64 major version as the toolchain cross_compile_ffmpeg.sh builds

for d in Linux/include Win/include; do
  [[ -d "$sdk/$d" ]] || { echo "no $d in $sdk - point this at the unpacked SDK folder"; exit 1; }
done
version() { sed -nE 's/^#define BLACKMAGIC_DECKLINK_API_VERSION_STRING\s+"([^"]+)".*/\1/p' "$1/DeckLinkAPIVersion.h"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "fetching widl and the mingw-w64 $mingw_headers_tag IDL files..."
# mingw-w64-x86-64-dev (and -common, which its _mingw.h links into) for the headers the IDL files
# include but which only exist once mingw-w64-headers is configured - git only has the .in files
(cd "$tmp" && apt-get download -q mingw-w64-tools mingw-w64-x86-64-dev mingw-w64-common >/dev/null && for d in *.deb; do dpkg -x "$d" root; done)
git clone -q --depth 1 --branch "$mingw_headers_tag" --filter=blob:none --sparse \
  https://github.com/mingw-w64/mingw-w64.git "$tmp/mingw" 2>/dev/null
git -C "$tmp/mingw" sparse-checkout set mingw-w64-headers/include

echo "generating the Windows headers..."
mkdir "$tmp/gen"
cp "$sdk/Win/include/"* "$tmp/gen/"
# widl wants a newline at the end of every file, which the SDK doesn't always have
(cd "$tmp/gen" && sed -i -e '$a\' *.idl && \
  "$tmp/root/usr/bin/x86_64-w64-mingw32-widl" -I"$tmp/mingw/mingw-w64-headers/include" \
    -I"$tmp/root/usr/x86_64-w64-mingw32/include" -h -u DeckLinkAPI.idl)

rm -rf "$here/linux" "$here/windows"
mkdir "$here/linux" "$here/windows"
cp "$sdk/Linux/include/"* "$here/linux/"
cp "$tmp/gen/DeckLinkAPI.h" "$tmp/gen/DeckLinkAPI_i.c" "$sdk/Win/include/DeckLinkAPIVersion.h" "$here/windows/"
# The generated files lose the license comment the IDL starts with, and the license requires it
# to go with every copy and derivative - so keep it next to them.
sed -n '/-LICENSE-START-/,/-LICENSE-END-/p' "$sdk/Win/include/DeckLinkAPI.idl" | tr -d '\r' > "$here/windows/LICENSE"

echo "DeckLink SDK $(version "$here/linux") (Linux) / $(version "$here/windows") (Windows) -> $here"
