#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Write-ActionOutput([string]$Name, [string]$Value) {
    # GitHub Actions multiline-safe output
    $Value = $Value -replace "`r", ''
    if ($Value -match "[\n]") {
        $delimiter = "ghadelim_$(New-Guid)"
        "$( $Name )<<$delimiter`n$Value`n$delimiter" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    } else {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
}

function Get-ApiHeaders {
    $headers = @{
        'Accept'     = 'application/vnd.github+json'
        'User-Agent' = 'rust-win7-action'
    }
    if ($env:INPUT_TOKEN) {
        $headers['Authorization'] = "Bearer $($env:INPUT_TOKEN)"
    }
    return $headers
}

function Invoke-GitHubApi([string]$Uri) {
    return Invoke-RestMethod -Uri $Uri -Headers (Get-ApiHeaders) -Method Get
}

$version = if ([string]::IsNullOrWhiteSpace($env:INPUT_VERSION)) { 'latest' } else { $env:INPUT_VERSION.Trim() }
$arch = if ([string]::IsNullOrWhiteSpace($env:INPUT_ARCH)) { 'x86_64' } else { $env:INPUT_ARCH.Trim().ToLowerInvariant() }
$repository = if ([string]::IsNullOrWhiteSpace($env:INPUT_REPOSITORY)) { 'Fenex/rust-win7' } else { $env:INPUT_REPOSITORY.Trim() }

if ($arch -notin @('x86_64', 'i686')) {
    throw "Unsupported arch '$arch'. Use x86_64 or i686."
}

$apiBase = "https://api.github.com/repos/$repository"
$headers = Get-ApiHeaders

Write-Host "Resolving toolchain version='$version' arch='$arch' repository='$repository'"

$release = $null

if ($version -eq 'latest') {
    $release = Invoke-GitHubApi "$apiBase/releases/latest"
}
elseif ($version -match '^\d+\.\d+\.\d+-win7(\.\d+)?$') {
    # Exact release tag, e.g. 1.99.0-win7.1
    try {
        $release = Invoke-GitHubApi "$apiBase/releases/tags/$version"
    } catch {
        throw "Release tag '$version' not found in $repository. $_"
    }
}
elseif ($version -match '^\d+\.\d+\.\d+$') {
    # Rust version only — pick newest matching *-win7* tag
    $page = 1
    $found = @()
    while ($page -le 5) {
        $releases = Invoke-GitHubApi "$apiBase/releases?per_page=30&page=$page"
        if (-not $releases -or $releases.Count -eq 0) { break }
        $found += @($releases | Where-Object { $_.tag_name -like "$version-win7*" })
        if ($found.Count -gt 0) { break }
        $page++
    }
    if ($found.Count -eq 0) {
        throw "No release found for Rust version '$version' in $repository (expected tags like $version-win7.1)."
    }
    $ranked = foreach ($item in $found) {
        $rank = 0
        if ($item.tag_name -match '-win7\.(\d+)$') {
            $rank = [int]$Matches[1]
        }
        [pscustomobject]@{ Release = $item; Rank = $rank }
    }
    $release = ($ranked | Sort-Object Rank -Descending | Select-Object -First 1).Release
}
else {
    throw "Unrecognized version '$version'. Use 'latest', a Rust version like '1.99.0', or a release tag like '1.99.0-win7.1'."
}

$tag = $release.tag_name
if ($tag -notmatch '^(\d+\.\d+\.\d+)-win7') {
    throw "Unexpected release tag format: '$tag'"
}
$rustVersion = $Matches[1]
$toolchain = "$rustVersion-$arch-win7-windows-msvc"
$assetName = "$toolchain.7z"
$asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1

if (-not $asset) {
    $available = ($release.assets | ForEach-Object { $_.name }) -join ', '
    throw "Asset '$assetName' not found in release '$tag'. Available assets: $available"
}

$toolchainPath = Join-Path $env:USERPROFILE ".rustup\toolchains\$toolchain"

Write-Host "Resolved release=$tag toolchain=$toolchain asset=$assetName"

Write-ActionOutput 'release' $tag
Write-ActionOutput 'rust-version' $rustVersion
Write-ActionOutput 'toolchain' $toolchain
Write-ActionOutput 'toolchain-path' $toolchainPath
Write-ActionOutput 'asset-name' $assetName
Write-ActionOutput 'asset-url' $asset.browser_download_url
