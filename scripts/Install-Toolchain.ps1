#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$toolchain = $env:TOOLCHAIN
$toolchainPath = $env:TOOLCHAIN_PATH
$release = $env:RELEASE
$assetUrl = $env:ASSET_URL
$assetName = $env:ASSET_NAME

if (-not $toolchain -or -not $toolchainPath -or -not $assetUrl) {
    throw 'Missing required environment variables (TOOLCHAIN, TOOLCHAIN_PATH, ASSET_URL).'
}

Write-Host "Installing toolchain $toolchain from release $release"

$toolchainsRoot = Join-Path $env:USERPROFILE '.rustup\toolchains'
New-Item -ItemType Directory -Force -Path $toolchainsRoot | Out-Null

# Remove a partial/broken install if present
if (Test-Path -LiteralPath $toolchainPath) {
    Write-Host "Removing existing directory: $toolchainPath"
    Remove-Item -LiteralPath $toolchainPath -Recurse -Force
}

$tempDir = Join-Path $env:RUNNER_TEMP "rust-win7-$toolchain"
if (Test-Path -LiteralPath $tempDir) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

$archivePath = Join-Path $tempDir $assetName
$extractDir = Join-Path $tempDir 'extract'
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

# Prefer a portable 7-Zip CLI (avoids a full Chocolatey install on every miss)
$sevenZip = $null
$candidates = @(
    'C:\Program Files\7-Zip\7z.exe',
    'C:\Program Files (x86)\7-Zip\7z.exe'
)
foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
        $sevenZip = $candidate
        break
    }
}

if (-not $sevenZip) {
    $sevenZip = Join-Path $tempDir '7zr.exe'
    Write-Host 'Downloading portable 7zr.exe'
    Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile $sevenZip
}

Write-Host "Downloading $assetUrl"
# Use browser_download_url without an auth header — attaching a token can break
# public asset downloads on GitHub. API auth is only used during release resolution.
Invoke-WebRequest -Uri $assetUrl -OutFile $archivePath -Headers @{
    'User-Agent' = 'rust-win7-action'
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $archivePath).Length / 1MB, 1)
Write-Host "Downloaded $assetName ($sizeMb MB)"

Write-Host "Extracting with $sevenZip"
& $sevenZip x $archivePath "-o$extractDir" -y | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "7-Zip extraction failed with exit code $LASTEXITCODE"
}

# Accept either a top-level toolchain folder or flat contents
$nested = Join-Path $extractDir $toolchain
if (Test-Path -LiteralPath $nested) {
    Move-Item -LiteralPath $nested -Destination $toolchainPath
} else {
    $children = @(Get-ChildItem -LiteralPath $extractDir -Force)
    if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
        Move-Item -LiteralPath $children[0].FullName -Destination $toolchainPath
    } else {
        New-Item -ItemType Directory -Force -Path $toolchainPath | Out-Null
        foreach ($child in $children) {
            Move-Item -LiteralPath $child.FullName -Destination (Join-Path $toolchainPath $child.Name)
        }
    }
}

$rustc = Join-Path $toolchainPath 'bin\rustc.exe'
if (-not (Test-Path -LiteralPath $rustc)) {
    throw "Installation looks incomplete: missing $rustc"
}

Write-Host "Installed toolchain to $toolchainPath"

# Cleanup temp artifacts (keep unpacked toolchain)
Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
