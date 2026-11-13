$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force deps | Out-Null
$packages = @(
  @{ Url = 'https://codeload.github.com/arvidn/libtorrent/tar.gz/refs/tags/v1.2.19'; File = 'deps/libtorrent.tar.gz'; Directory = 'deps/libtorrent'; Extracted = 'deps/libtorrent-1.2.19' },
  @{ Url = 'https://archives.boost.io/release/1.78.0/source/boost_1_78_0.tar.gz'; File = 'deps/boost.tar.gz'; Directory = 'deps/boost_1_78_0'; Extracted = 'deps/boost_1_78_0' }
)
foreach ($package in $packages) {
  if (-not (Test-Path -LiteralPath $package.Directory)) {
    if (-not (Test-Path -LiteralPath $package.File)) {
      Invoke-WebRequest -UseBasicParsing $package.Url -OutFile $package.File
    }
    & tar.exe -xzf $package.File -C deps
    if ($LASTEXITCODE -ne 0) { throw "Archive extraction failed: $($package.File)" }
    if ($package.Extracted -ne $package.Directory) {
      $depsRoot = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'deps')) + [IO.Path]::DirectorySeparatorChar
      $sourcePath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $package.Extracted))
      $targetPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $package.Directory))
      if (-not $sourcePath.StartsWith($depsRoot, [StringComparison]::OrdinalIgnoreCase) -or
          -not $targetPath.StartsWith($depsRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Dependency paths must stay inside the workspace deps folder'
      }
      Move-Item -LiteralPath $sourcePath -Destination $targetPath
    }
  }
}
Write-Host 'Sources downloaded. See README.md for build and license details.'
