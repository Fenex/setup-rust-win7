#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

# rust-win7 release archives are an unpacked toolchain directory. Official
# rustup installs also drop lib/rustlib/multirust-channel-manifest.toml.
# Names like 1.99.0-x86_64-win7-windows-msvc parse as channel toolchains
# (win7-windows is a known OS tuple), so rustup show / target list read that
# file and fail with "missing manifest" when it is absent.

$toolchain = $env:TOOLCHAIN
if ([string]::IsNullOrWhiteSpace($toolchain)) {
    throw 'TOOLCHAIN is not set.'
}

$toolchainPath = $env:TOOLCHAIN_PATH
if ([string]::IsNullOrWhiteSpace($toolchainPath)) {
    $toolchainPath = Join-Path $env:USERPROFILE ".rustup\toolchains\$toolchain"
}

if (-not (Test-Path -LiteralPath $toolchainPath)) {
    throw "Toolchain directory not found: $toolchainPath"
}

# ChannelToolchainName is "{version}-{target}". query_components panics unless
# pkg.rust.target contains exactly that target tuple.
if ($toolchain -notmatch '^(\d+\.\d+\.\d+)-(.+)$') {
    throw "Cannot derive Rust version and host triple from toolchain name '$toolchain'."
}

$rustVersion = $Matches[1]
$hostTriple = $Matches[2]

$manifestDir = Join-Path $toolchainPath 'lib\rustlib'
$manifestPath = Join-Path $manifestDir 'multirust-channel-manifest.toml'

if (Test-Path -LiteralPath $manifestPath) {
    Write-Host "Channel manifest already present: $manifestPath"
    return
}

New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null

# Minimal v2 manifest. Empty components are valid: Manifest::parse checks
# that every listed component has a package, and rustup show only iterates
# components. The host target key must exist or query_components panics.
# available = false keeps rustup from treating the package as downloadable.
$content = @"
# Synthetic manifest written by setup-rust-win7. rust-win7 archives do not
# ship the channel manifest that rustup writes for official toolchains.
manifest-version = "2"
date = "1970-01-01"

[pkg.rust]
version = "$rustVersion"

[pkg.rust.target.$hostTriple]
available = false
"@

# Windows PowerShell 5.1's utf8 encoding writes a BOM, which the TOML parser rejects.
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($manifestPath, $content, $utf8)
Write-Host "Wrote rustup channel manifest: $manifestPath"
