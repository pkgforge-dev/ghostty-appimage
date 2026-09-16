#!/bin/sh

set -eux

UPSTREAM_REPO="${UPSTREAM_REPO:-ghostty-org/ghostty}"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://release.files.ghostty.org}"

BOT_NAME="github-actions[bot]"
BOT_EMAIL="41898282+github-actions[bot]@users.noreply.github.com"

log() {
	echo "$*" >&2
}

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

validate_tag() {
	tag="${1:-}"
	case "${tag}" in
	v*) ;;
	*) tag="v${tag}" ;;
	esac
	if ! printf '%s\n' "${tag}" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$'; then
		log "Invalid release tag '${tag}': expected <major>.<minor>.<patch> or <major>.<minor>.<patch>+<n> (optional 'v' prefix)"
		exit 1
	fi
	printf '%s\n' "${tag}"
}

tag_exists() {
	git ls-remote --exit-code --tags origin "refs/tags/${1}" >/dev/null 2>&1
}

branch_exists() {
	git ls-remote --exit-code --heads origin "refs/heads/${1}" >/dev/null 2>&1
}

require_assets() {
	set -- ./*.AppImage*
	if [ ! -e "${1}" ]; then
		log "No AppImage assets found in $(pwd)"
		exit 1
	fi
}

detect_release() {
	current="$(cat VERSION)"
	latest="$(get_latest_stable_tag)"
	if [ -z "${latest}" ]; then
		log "No upstream stable release found"
		return 1
	fi
	if ! release_artifact_exists "${latest}"; then
		log "Upstream ${latest} has no published release artifact yet"
		return 1
	fi
	if [ "${latest}" = "${current}" ]; then
		log "Already on latest upstream release ${current}"
		return 1
	fi
	newest="$(printf '%s\n%s\n' "${current}" "${latest}" | sort -V | tail -n1)"
	if [ "${newest}" != "${latest}" ]; then
		log "Current version ${current} is newer than upstream ${latest}"
		return 1
	fi
	printf '%s\n' "${latest}"
}

cmd_tip_version() {
	echo "tip" >VERSION
}

cmd_lint() {
	pre-commit run --all-files --show-diff-on-failure
}

cmd_resolve_tag() {
	if [ "${EVENT_NAME:-}" = "release" ]; then
		tag="${RELEASE_TAG:-}"
	elif [ -n "${INPUT_TAG:-}" ]; then
		tag="${INPUT_TAG}"
	else
		tag="v$(cat VERSION)"
		if [ "${EVENT_NAME:-}" = "push" ] && ! tag_exists "${tag}"; then
			log "No tag ${tag} for VERSION $(cat VERSION), nothing to release"
			return 0
		fi
	fi
	validate_tag "${tag}"
}

cmd_open_pr() {
	version="${1:-}"
	if [ -z "${version}" ]; then
		if ! version="$(detect_release)"; then
			log "Nothing to release"
			return 0
		fi
	fi
	tag="$(validate_tag "v${version}")"
	branch="release/${version}"

	git config user.name "${BOT_NAME}"
	git config user.email "${BOT_EMAIL}"

	if branch_exists "${branch}"; then
		git checkout -B "${branch}" "origin/${branch}"
	else
		git checkout -b "${branch}"
		printf '%s\n' "${version}" >VERSION
		git add VERSION
		git commit -m "chore(release): set VERSION to ${version}"
		git push origin "${branch}"
	fi

	if ! tag_exists "${tag}"; then
		git tag -a "${tag}" -m "Ghostty ${version}"
		git push origin "${tag}"
	fi

	if [ -n "$(gh pr list --head "${branch}" --state open --json number --jq '.[0].number')" ]; then
		log "Open pull request for ${branch} already exists"
		return 0
	fi

	gh pr create \
		--base main \
		--head "${branch}" \
		--title "👻 Release Ghostty ${version}" \
		--body "Automated release PR for upstream Ghostty \`${version}\`.

- Updates \`VERSION\` to \`${version}\`
- Adds tag \`v${version}\`

Upstream tag: https://github.com/${UPSTREAM_REPO}/releases/tag/v${version}"
}

cmd_publish() {
	tag="$(validate_tag "${1:-}")"
	version="${tag#v}"

	require_assets

	if gh release view "${tag}" >/dev/null 2>&1; then
		log "Release ${tag} exists, uploading assets"
	else
		log "Creating release ${tag}"
		gh release create "${tag}" --title "Ghostty ${version}" --generate-notes
	fi
	gh release upload "${tag}" ./*.AppImage* --clobber
}

cmd_publish_tip() {
	require_assets

	if gh release view tip >/dev/null 2>&1; then
		log "Tip release exists, uploading assets"
	else
		log "Creating tip release"
		gh release create tip --prerelease --title '👻 Ghostty Tip ("Nightly")' --notes "Latest nightly build of Ghostty"
	fi
	gh release upload tip ./*.AppImage* --clobber
}

cmd_tag_tip() {
	gh release view tip --json assets --jq '.assets[].name' | while read -r asset; do
		if [ -n "${asset}" ]; then
			gh release delete-asset tip "${asset}" -y
		fi
	done

	git config user.name "${BOT_NAME}"
	git config user.email "${BOT_EMAIL}"
	git tag -fa tip -m "Latest Continuous Release" "${GITHUB_SHA}"
	git push --force origin tip
}

command="${1:-}"
if [ "$#" -gt 0 ]; then
	shift
fi

case "${command}" in
tip-version) cmd_tip_version "$@" ;;
lint) cmd_lint "$@" ;;
detect) detect_release "$@" ;;
validate-tag) validate_tag "$@" ;;
resolve-tag) cmd_resolve_tag "$@" ;;
open-pr) cmd_open_pr "$@" ;;
publish) cmd_publish "$@" ;;
publish-tip) cmd_publish_tip "$@" ;;
tag-tip) cmd_tag_tip "$@" ;;
*)
	log "Usage: $0 <tip-version|lint|detect|validate-tag|resolve-tag|open-pr|publish|publish-tip|tag-tip> [args]"
	exit 1
	;;
esac
