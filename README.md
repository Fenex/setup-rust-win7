# setup-rust-win7

GitHub Action that installs a [Fenex/rust-win7](https://github.com/Fenex/rust-win7) custom toolchain so CI can build Rust programs compatible with **Windows 7+**.

> Requires a **Windows** runner (`runs-on: windows-latest`).

## Usage

```yaml
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Rust Win7 toolchain
        uses: Fenex/setup-rust-win7@v1
        with:
          version: latest   # or 1.99.0 / 1.99.0-win7.1
          arch: x86_64

      - run: cargo build --release
```

Pin a specific release when you need reproducible builds:

```yaml
- uses: Fenex/setup-rust-win7@v1
  with:
    version: '1.99.0-win7.1'
    arch: x86_64
    cache: true
```

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `version` | `latest` | Release tag (`1.99.0-win7.1`), Rust version (`1.99.0`), or `latest` |
| `arch` | `x86_64` | Host architecture: `x86_64` or `i686` |
| `repository` | `Fenex/rust-win7` | Releases repository (`owner/name`) |
| `cache` | `true` | Cache the unpacked toolchain between runs |
| `set-default` | `true` | Run `rustup default` for the installed toolchain |
| `token` | `${{ github.token }}` | Token for GitHub Releases API |

### Version resolution

| `version` value | Behavior |
| --- | --- |
| `latest` | Latest GitHub release |
| `1.99.0` | Newest tag matching `1.99.0-win7*` |
| `1.99.0-win7.1` | Exact release tag |

`arch` selects the **host** toolchain archive (`*-x86_64-win7-windows-msvc.7z` or `*-i686-win7-windows-msvc.7z`).  
`i686` host archives are only published for newer releases (from `1.99.0-win7.1`). On older releases, install the `x86_64` host and cross-compile with `--target i686-win7-windows-msvc` when that target is bundled.

## Outputs

| Output | Description |
| --- | --- |
| `toolchain` | rustup toolchain name, e.g. `1.99.0-x86_64-win7-windows-msvc` |
| `release` | Resolved release tag |
| `rust-version` | Rust version, e.g. `1.99.0` |
| `cache-hit` | `true` when the toolchain was restored from cache |

```yaml
- id: rust
  uses: Fenex/setup-rust-win7@v1
  with:
    version: '1.99.0'

- run: echo "Using ${{ steps.rust.outputs.toolchain }}"
```

## Caching

When `cache: true` (default), the action caches:

```text
%USERPROFILE%\.rustup\toolchains\<toolchain>
```

Cache key includes OS, toolchain name, and release tag. On a hit, the ~150–170 MB download/extract step is skipped.

## What the action does

1. Resolves the release/asset from GitHub Releases
2. Ensures `rustup` is available (`dtolnay/rust-toolchain`)
3. Restores the toolchain from cache when possible  
4. Otherwise downloads the `.7z` archive, extracts it into `~\.rustup\toolchains\`, and activates it
5. Sets `RUSTUP_TOOLCHAIN` (and optionally `rustup default`)

## Local equivalent

Same steps as documented in the [rust-win7 releases](https://github.com/Fenex/rust-win7/releases):

1. Install rustup
2. Unpack the archive into `~/.rustup/toolchains/`
3. `rustup default 1.99.0-x86_64-win7-windows-msvc`

## License

MIT
