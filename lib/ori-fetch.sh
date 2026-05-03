#!/bin/bash
# Download the latest ori binary release into ~/.local/bin/ori.
# Source me; don't exec me. Provides:
#   fetch_ori [--dest <path>] [--ref latest|<tag>]
#
# Detects host OS/arch via uname, downloads the matching binary from
# https://github.com/$ORI_RELEASE_REPO/releases. No source build, no Go,
# no fallback. The binary is the canonical install path.

ORI_RELEASE_REPO="${ORI_RELEASE_REPO:-mattkorwel/ori}"

fetch_ori() {
  local dest="$HOME/.local/bin/ori"
  local ref="latest"
  while (( $# )); do
    case "$1" in
      --dest) dest="$2"; shift 2 ;;
      --ref)  ref="$2"; shift 2 ;;
      *) echo "fetch_ori: unknown arg: $1" >&2; return 1 ;;
    esac
  done

  local os arch
  case "$(uname -s)" in
    Linux)  os=linux ;;
    Darwin) os=darwin ;;
    *) echo "fetch_ori: unsupported OS: $(uname -s)" >&2; return 1 ;;
  esac
  case "$(uname -m)" in
    x86_64)         arch=amd64 ;;
    aarch64|arm64)  arch=arm64 ;;
    *) echo "fetch_ori: unsupported arch: $(uname -m)" >&2; return 1 ;;
  esac
  local asset="ori-${os}-${arch}"
  local url
  if [[ "$ref" == "latest" ]]; then
    url="https://github.com/${ORI_RELEASE_REPO}/releases/latest/download/${asset}"
  else
    url="https://github.com/${ORI_RELEASE_REPO}/releases/download/${ref}/${asset}"
  fi

  mkdir -p "$(dirname "$dest")"
  echo "📦 Fetching ori → $dest  (from $url)"
  if ! curl -fsSL --retry 3 -o "${dest}.new" "$url"; then
    echo "❌ release download failed. Check that a release exists at $url" >&2
    rm -f "${dest}.new"
    return 1
  fi
  chmod +x "${dest}.new"
  mv "${dest}.new" "$dest"
  if "$dest" --version >/dev/null 2>&1; then
    echo "✅ $("$dest" --version)"
  else
    echo "⚠️  installed ori is non-functional; check $dest" >&2
    return 1
  fi
}
