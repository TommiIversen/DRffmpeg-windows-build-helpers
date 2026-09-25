#!/usr/bin/env bash
#
# Compares what two FFmpeg builds can do - by default the Windows shared and the Linux shared
# build from cross_compile_ffmpeg.sh - by diffing the CONFIG_ flags FFmpeg's configure wrote into
# each build tree (config_components.h and config.h). Nothing has to be run, so it works without
# Windows, without a GPU and without a DeckLink card.
#
# Differences that come with the platform (dshow vs v4l2, d3d11va vs vaapi, ...) are listed on
# their own and don't count. Anything else is a real capability gap and makes this exit 1.
#
# usage: ./compare_ffmpeg_builds.sh [build_tree_a] [build_tree_b]
#
set -euo pipefail

top_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
a="${1:-$top_dir/sandbox/win64/ffmpeg_git_with_fdk_aac_xp_compat_shared}"
b="${2:-$top_dir/sandbox/native/ffmpeg_git_with_fdk_aac_xp_compat_shared}"

# Things one platform has and the other cannot. Matched at the start of a name or after an
# underscore, so H264_VAAPI_ENCODER and D3D11VA both hit. Extend when a new one shows up.
# frc_amf/vqe_amf need windows.h and unix_protocol needs sys/un.h, per FFmpeg's own configure.
platform_only='dshow|gdigrab|vfwcap|ddagrab|d3d11|d3d12|dxva2|mediafoundation|mf_|schannel|frc_amf|vqe_amf|v4l2|libv4l2|xcb|libxcb|x11grab|xlib|xv_|vaapi|vdpau|alsa|pulse|libpulse|oss_|fbdev|kmsgrab|libdrm|sndio|jack|libjack|unix_'

enabled() { # every CONFIG_ that is 1 in a build tree, one name per line
  local dir="$1"
  for f in config_components.h config.h; do
    [[ -f "$dir/$f" ]] || { echo "no $f in $dir - not an FFmpeg build tree, or configure never ran" >&2; exit 2; }
  done
  cat "$dir/config_components.h" "$dir/config.h" \
    | sed -nE 's/^#define CONFIG_([A-Z0-9_]+) 1$/\1/p' | sort -u
}

commit() { git -C "$1" log --oneline -1 --format=%h 2>/dev/null || echo "?"; }

is_platform() { grep -qiE "(^|_)($platform_only)"; }

list() { # $1 = heading, stdin = names
  local names; names="$(cat)"
  [[ -z $names ]] && return
  echo "$1 ($(wc -l <<< "$names")):"
  sed 's/^/  /' <<< "$names" | tr '[:upper:]' '[:lower:]'
  echo
}

echo "A: $a  [$(commit "$a")]"
echo "B: $b  [$(commit "$b")]"
if [[ $(commit "$a") != "$(commit "$b")" ]]; then
  echo "WARNING: the two trees are on different FFmpeg commits - some differences may just be that"
fi
echo

enabled_a="$(enabled "$a")"
enabled_b="$(enabled "$b")"
only_a="$(comm -23 <(echo "$enabled_a") <(echo "$enabled_b"))"
only_b="$(comm -13 <(echo "$enabled_a") <(echo "$enabled_b"))"

real_a="$(while read -r n; do [[ -n $n ]] && ! is_platform <<< "$n" && echo "$n"; done <<< "$only_a" || true)"
real_b="$(while read -r n; do [[ -n $n ]] && ! is_platform <<< "$n" && echo "$n"; done <<< "$only_b" || true)"
plat_a="$(while read -r n; do [[ -n $n ]] && is_platform <<< "$n" && echo "$n"; done <<< "$only_a" || true)"
plat_b="$(while read -r n; do [[ -n $n ]] && is_platform <<< "$n" && echo "$n"; done <<< "$only_b" || true)"

list "Only in A" <<< "$real_a"
list "Only in B" <<< "$real_b"
list "Platform-specific, only in A (expected)" <<< "$plat_a"
list "Platform-specific, only in B (expected)" <<< "$plat_b"

gaps=$(( $(grep -c . <<< "$real_a" || true) + $(grep -c . <<< "$real_b" || true) ))
echo "$(wc -l <<< "$enabled_a") enabled in A, $(wc -l <<< "$enabled_b") enabled in B, $gaps real difference(s)"
[[ $gaps -eq 0 ]]
