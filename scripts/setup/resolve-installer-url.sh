#!/usr/bin/env bash
#===============================================================================
# resolve-installer-url.sh -- resolve the latest Wispr Flow Windows installer
# download URL, version, and checksum from the upstream release manifest.
#
# Wispr Flow publishes the x64 artifact metadata used by its Windows installer:
#   https://dl.wisprflow.com/wispr-flow/win32/latest.json
#
# The Linux arm64 package uses the same x64 installer because the app bundle is
# arch-neutral JS/asar, so this resolver is arch-independent.
#
# Output contract (stdout, one KEY=VALUE per line; ALL diagnostics to stderr):
#   URL=<installer download URL>
#   VERSION=<x.y.z extracted from the installer filename>
#   SHA256=<installer checksum from the manifest>
#
# Usage:   resolve-installer-url.sh [--latest-url <url>]
#   --latest-url   override the upstream latest-manifest URL
#
# Exit 0 on success; non-zero if the manifest cannot be fetched or validated.
# This is a standalone CI helper -- it sources nothing.
#===============================================================================
set -uo pipefail

readonly DEFAULT_LATEST_URL='https://dl.wisprflow.com/wispr-flow/win32/latest.json'

log() { printf '%s\n' "$*" >&2; }
die() { printf 'resolve-installer-url: %s\n' "$*" >&2; exit 1; }

latest_url="$DEFAULT_LATEST_URL"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--latest-url)
			[[ -n ${2:-} ]] || die '--latest-url needs a value'
			latest_url="$2"; shift 2 ;;
		-h|--help)
			grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
		*)
			die "unknown argument: $1" ;;
	esac
done

command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v python3 >/dev/null 2>&1 || die 'python3 is required'

log "Resolving Wispr Flow installer from ${latest_url} ..."

# Fetch the small JSON manifest, then validate its trust-boundary fields with
# Python's standard library (already required by the build's patch suite).
manifest="$(curl -fsSL --max-time 60 "$latest_url")"
rc=$?
if [[ $rc -ne 0 || -z $manifest ]]; then
	die "failed to fetch ${latest_url} (curl rc=${rc})"
fi

parsed="$(python3 - "$manifest" <<'PY'
import json
import re
import sys
from urllib.parse import unquote, urlparse

try:
    manifest = json.loads(sys.argv[1])
    if not isinstance(manifest, dict):
        raise ValueError("manifest root must be an object")
    if manifest.get("schemaVersion") != 1:
        raise ValueError("unsupported schemaVersion")
    artifact = manifest["windows"]["x64"]
    if not isinstance(artifact, dict):
        raise ValueError("windows.x64 must be an object")
    url = artifact["url"]
    sha256 = artifact["sha256"]
    size = artifact["size"]
    if not isinstance(url, str):
        raise ValueError("installer URL must be a string")
    parsed_url = urlparse(url)
    if parsed_url.scheme != "https" or not parsed_url.netloc:
        raise ValueError("installer URL must use HTTPS")
    match = re.search(
        r"[Ss]etup-v([0-9]+\.[0-9]+\.[0-9]+)\.exe$",
        unquote(parsed_url.path),
    )
    if not match:
        raise ValueError("installer URL has no versioned Setup filename")
    if not isinstance(sha256, str) or not re.fullmatch(
        r"[0-9a-fA-F]{64}", sha256
    ):
        raise ValueError("invalid installer SHA-256")
    if isinstance(size, bool) or not isinstance(size, int) or size <= 0:
        raise ValueError("invalid installer size")
except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
    print(f"manifest validation failed: {error}", file=sys.stderr)
    sys.exit(1)

print(f"URL={url}")
print(f"VERSION={match.group(1)}")
print(f"SHA256={sha256.lower()}")
PY
)" || die "invalid manifest from ${latest_url}"

log "$(printf '%s\n' "$parsed" | grep '^URL=')"
log "$(printf '%s\n' "$parsed" | grep '^VERSION=')"
printf '%s\n' "$parsed"
