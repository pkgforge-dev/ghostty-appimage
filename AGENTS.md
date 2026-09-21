# AGENTS.md

## What this repo is

Build/packaging repo for an unofficial **Ghostty AppImage**. There is no application source here, no package manager, and **no test suite** — it fetches upstream Ghostty source and produces AppImages for `x86_64` and `aarch64`. The deliverable is a GitHub release.

- All scripts are POSIX `sh` (`#!/bin/sh`) under `bin/` and must stay POSIX.
- Build artifacts are gitignored (`AppDir/`, `dist/`, `ghostty-*/`, `quick-sharun`, `appinfo`, `*.AppImage`, `*.tar.gz`). Never try to commit them.

## Commands

- Lint/format everything: `pre-commit run --all-files` (alias: `./bin/repo-management.sh lint`). Install hooks once with `pre-commit install`.
- Build — must run as **root inside an Arch container** (e.g. `ghcr.io/pkgforge-dev/archlinux`, which CI uses) because `setup-env.sh` calls `pacman`:
  1. `./bin/setup-env.sh`
  2. `./bin/build-ghostty.sh`
  3. `./bin/bundle-appimage.sh`
  4. `./bin/repo-management.sh validate-appimage`
- Focused verification after a build: `./bin/repo-management.sh validate-appimage` asserts the embedded `UPINFO` matches the expected channel and the zsync `SHA-1` matches the AppImage. `./dist/*.AppImage --appimage-updateinfo` prints the raw update info.
- `./bin/repo-management.sh` with no args prints usage.

## `bin/repo-management.sh` is the single CLI for release logic

All release/CI shell logic lives here as verbs; `ci.yaml` is orchestration only (triggers, permissions, matrix, artifact actions). **Do not inline release shell back into the workflow.**

Verbs: `tip-version`, `lint`, `validate-appimage`, `detect`, `validate-tag`, `resolve-tag`, `open-pr`, `publish`, `publish-tip`, `tag-tip`.

It reads env supplied by the workflow (`EVENT_NAME`, `RELEASE_TAG`, `INPUT_TAG`, `GITHUB_REPOSITORY`, `GITHUB_SHA`, `GH_TOKEN`) and honors `UPSTREAM_REPO` / `RELEASE_BASE_URL` overrides for local testing.

## VERSION, tags, UPINFO

- `VERSION` holds the upstream version. Stable = a clean `X.Y.Z`. Nightly: `tip-version` writes `tip`, then `build-ghostty.sh` overwrites `VERSION` with the tip snapshot (`X.Y.Z-main-+hash`).
- `+N` releases: `VERSION` stays the upstream `X.Y.Z`; only the git **tag** gets `+N` (e.g. `v1.2.0+1`). Never put `+N` in `VERSION` — the source URL `release.files.ghostty.org/<VERSION>/...` would break.
- Release tags must match `^v<major>.<minor>.<patch>(\+<n>)?$` (`validate_tag` enforces; invalid input fails). Non-version tags `tip`, `glfw`, `soar-nest` are utility and not releases.
- `bundle-appimage.sh` picks the UPINFO channel from `VERSION`: `latest` for clean `X.Y.Z` (stable), `tip` for snapshot versions (nightly). The asset glob `Ghostty-*<arch>.AppImage.zsync` absorbs the daily-changing nightly filename.

## CI / release flow (`ci.yaml`)

- **Daily schedule** builds tip (`tip-version`); a `tag` job force-updates the `tip` tag and clears its assets, then `release_nightly` publishes the prerelease.
- The same schedule runs `create_release_pr`: if upstream `ghostty-org/ghostty` has a newer stable tag **and** its CDN artifact exists, it creates `release/<v>`, bumps `VERSION`, pushes `v<v>`, and opens a PR.
- **Merging that PR** (push to `main` touching `VERSION`) builds once and `release_stable` publishes the GitHub release with assets — the only manual step.
- `release: published` handles manually published `+N` releases; `workflow_dispatch` inputs `tag`/`publish` are the manual override.
- PRs are intentionally skipped for VERSION-only changes (`paths-ignore`), so the release PR does not build. The `lint` job runs on PRs only.

## Conventions

- Commits: Conventional Commits (`feat(ci): ...`, `fix(bundle): ...`, `chore(deps): ...`).
- Branches: `feature/<x>`, `fix/<x>`, `release/<version>`. `no-commit-to-branch` blocks direct commits to `main`.
- Action updates are handled by Renovate (branches `renovate/*`, `chore(deps): update ...` PRs). Don't hand-edit action pins.

## Gotchas

- shellcheck runs at `--severity=warning --shell=sh`: bashisms (`[[ ]]`, arrays, `local`) fail. `export VAR="$(cmd)"` fails SC2155 — assign first, then `export`.
- `setup-env.sh` self-installs `get-debloated-pkgs` / `quick-sharun` when absent (CI provides them via `anylinux-setup-action`), so local builds work.
- `GITHUB_REPOSITORY` defaults to `pkgforge-dev/ghostty-appimage` in `build-ghostty.sh` / `bundle-appimage.sh`; without it local builds embed a broken `UPINFO`.
- `setup-env.sh` strips `.sframe`/`.rela.sframe` from `/usr/lib/*crt*.o` — required for GCC 15+ with Zig's self-hosted linker. Keep it.
- `build-ghostty.sh` derives the Zig version from `ghostty-<v>/build.zig.zon` and installs it under `/opt`, symlinking `/usr/local/bin/zig`.
- Workflows are checked by `actionlint` + `zizmor`; `.github/actionlint.yaml` whitelists the `ubuntu-24.04-arm` label. A checkout that persists credentials needs `# zizmor: ignore[artipacked]`, or set `persist-credentials: false`.
