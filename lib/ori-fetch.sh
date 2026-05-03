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

  # If the repo is private (which is the default for ori), the public
  # /releases/<...>/download/<asset> URL 404s. Resolve via the API
  # using $GITHUB_PAT (or ~/.ori/github-pat as a fallback).
  local pat="${GITHUB_PAT:-}"
  if [[ -z "$pat" ]] && [[ -r "$HOME/.ori/github-pat" ]]; then
    pat=$(< "$HOME/.ori/github-pat")
  fi

  echo "📦 Fetching ori → $dest"
  if [[ -n "$pat" ]]; then
    # API path: list assets for the release, find the one matching $asset,
    # then download via /assets/<id> with Accept: octet-stream.
    local asset_id
    asset_id=$(curl -fsSL \
        -H "Authorization: Bearer $pat" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${ORI_RELEASE_REPO}/releases/${ref}" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); [print(a['id']) for a in d.get('assets',[]) if a['name']=='${asset}']" 2>/dev/null \
      | head -1)
    if [[ -z "$asset_id" ]]; then
      echo "❌ no asset $asset in release $ref of $ORI_RELEASE_REPO" >&2
      return 1
    fi
    if ! curl -fsSL --retry 3 \
        -H "Authorization: Bearer $pat" \
        -H "Accept: application/octet-stream" \
        -o "${dest}.new" \
        "https://api.github.com/repos/${ORI_RELEASE_REPO}/releases/assets/${asset_id}"; then
      echo "❌ download via API failed" >&2
      rm -f "${dest}.new"
      return 1
    fi
  else
    # Public-repo path: direct browser download URL.
    if ! curl -fsSL --retry 3 -o "${dest}.new" "$url"; then
      echo "❌ release download failed (and no \$GITHUB_PAT / ~/.ori/github-pat for private-repo fallback). URL: $url" >&2
      rm -f "${dest}.new"
      return 1
    fi
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
