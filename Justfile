setup-env:
    ZIG_VERSION=0.13.0 ./bin/setup-env.sh

setup-tip-env:
    ZIG_VERSION=0.14.0 ./bin/setup-env.sh

build-ghostty:
    ./bin/build-ghostty.sh

bundle-appimage:
    ./bin/bundle-appimage.sh

run-stable:
    just setup-env
    just build-ghostty
    just bundle-appimage

run-tip:
    just setup-tip-env
    just build-ghostty
    just bundle-appimage

pc:
    pre-commit run --all
