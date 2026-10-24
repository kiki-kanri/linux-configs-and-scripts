cargo install --locked --all-features sccache
cargo install --locked \
    cargo-llvm-cov \
    cargo-edit \
    cargo-cache \
    cargo-shear \
    cargo-zigbuild \
    cargo-audit \
    cargo-deny \
    jscpd \
    cargo-dylint \
    dylint-link \
    release-plz \
    cargo-semver-checks

cargo cache -r all
