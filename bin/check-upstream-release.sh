#!/bin/sh

set -eux

UPSTREAM_REPO="${UPSTREAM_REPO:-ghostty-org/ghostty}"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://release.files.ghostty.org}"

get_latest_stable_tag() {
	git ls-remote --tags --refs "https://github.com/${UPSTREAM_REPO}.git" |
		sed 's#.*refs/tags/##' |
		grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
		sed 's/^v//' |
		sort -V |
		tail -n1
}

release_artifact_exists() {
	curl -fsI "${RELEASE_BASE_URL}/${1}/ghostty-${1}.tar.gz" >/dev/null 2>&1
}

current="$(cat VERSION)"
latest="$(get_latest_stable_tag)"

if [ -z "${latest}" ]; then
	echo "No upstream stable release found" >&2
	exit 1
fi

if ! release_artifact_exists "${latest}"; then
	echo "Upstream ${latest} has no published release artifact yet" >&2
	exit 1
fi

if [ "${latest}" = "${current}" ]; then
	echo "Already on latest upstream release ${current}" >&2
	exit 1
fi

newest="$(printf '%s\n%s\n' "${current}" "${latest}" | sort -V | tail -n1)"
if [ "${newest}" != "${latest}" ]; then
	echo "Current version ${current} is newer than upstream ${latest}" >&2
	exit 1
fi

echo "${latest}"
