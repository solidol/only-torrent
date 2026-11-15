param([Parameter(Mandatory=$true)][string]$PackageFolder, [string]$WixRoot)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$package = (Resolve-Path -LiteralPath $PackageFolder).Path
if (-not $WixRoot) { $WixRoot = Join-Path $root 'build/wix314' }
$candle = Join-Path $WixRoot 'candle.exe'
$light = Join-Path $WixRoot 'light.exe'
if (-not (Test-Path -LiteralPath $candle)) { throw 'WiX 3.14.1 is required. Run tools/fetch-wix.ps1 explicitly.' }
$version = Get-Content -Raw -Encoding UTF8 (Join-Path $package 'version.json') | ConvertFrom-Json
$number = '{0}.{1}.{2}.{3}' -f $version.major,$version.minor,$version.release,$version.build
# MSI compares three fields only. The global build counter preserves ordering.
if ($version.major -gt 255 -or $version.minor -gt 255) { throw 'MSI major/minor fields exceed 255' }
$msiVersion = '{0}.{1}.{2}' -f $version.major,$version.minor,$version.build
$output = Join-Path $root "build/Only-Torrent-$number-Win64.msi"
if (Test-Path -LiteralPath $output) { throw "Installer already exists: $output" }
$work = Join-Path $root ('build/msi-' + $number)
New-Item -ItemType Directory -Force $work | Out-Null
function Xml([string]$text) { [Security.SecurityElement]::Escape($text) }
function Identifier([string]$text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { 'Ot' + ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-','')).Substring(0,32) }
  finally { $sha.Dispose() }
}
$refs = [Collections.Generic.List[string]]::new()
function Contents([string]$folder) {
  $xml = [Text.StringBuilder]::new()
  foreach ($file in Get-ChildItem -LiteralPath $folder -File | Sort-Object Name) {
    $relative = $file.FullName.Substring($package.Length + 1).Replace('\','/')
    $id = Identifier $relative
    $refs.Add("<ComponentRef Id=`"$id`"/>")
    $shortcut = ''
    if ($relative -eq 'otorrent.exe') { $shortcut = '<Shortcut Id="OnlyTorrentShortcut" Directory="OnlyTorrentMenu" Name="Only Torrent" WorkingDirectory="INSTALLFOLDER" Icon="OnlyTorrent.exe" Advertise="yes"/>' }
    [void]$xml.Append("<Component Id=`"$id`" Guid=`"*`" Win64=`"yes`"><File Id=`"F$id`" Source=`"$(Xml $file.FullName)`" Name=`"$(Xml $file.Name)`" KeyPath=`"yes`" Checksum=`"yes`">$shortcut</File></Component>")
  }
  foreach ($dir in Get-ChildItem -LiteralPath $folder -Directory | Sort-Object Name) {
    $id = Identifier ('dir/' + $dir.FullName.Substring($package.Length + 1).Replace('\','/'))
    [void]$xml.Append("<Directory Id=`"$id`" Name=`"$(Xml $dir.Name)`">$(Contents $dir.FullName)</Directory>")
  }
  $xml.ToString()
}
$contents = Contents $package
$wxs = @"
<?xml version="1.0" encoding="utf-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
 <Product Id="*" Name="Only Torrent" Language="1033" Version="$msiVersion" Manufacturer="Only Torrent" UpgradeCode="1E87DEEF-587B-4D4D-B937-EB9679A8350A">
  <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" Platform="x64" Description="Only Torrent $number"/>
  <MajorUpgrade DowngradeErrorMessage="A newer Only Torrent installer is already installed." Schedule="afterInstallInitialize"/>
  <MediaTemplate EmbedCab="yes"/>
  <Condition Message="Windows 7 SP1 x64 or later is required."><![CDATA[Installed OR (VersionNT64 >= 601 AND (VersionNT64 > 601 OR ServicePackLevel >= 1))]]></Condition>
  <Property Id="ARPCOMMENTS" Value="Only Torrent $number. User data is preserved when reinstalling or uninstalling."/>
  <Property Id="ARPPRODUCTICON" Value="OnlyTorrent.exe"/>
  <Property Id="INSTALLFOLDER" Secure="yes">
   <RegistrySearch Id="PreviousFolder" Root="HKLM" Key="Software\Only Torrent" Name="InstallFolder" Type="raw" Win64="yes"/>
  </Property>
  <Icon Id="OnlyTorrent.exe" SourceFile="$(Xml (Join-Path $package 'otorrent.exe'))"/>
  <Directory Id="TARGETDIR" Name="SourceDir">
   <Directory Id="ProgramFiles64Folder"><Directory Id="INSTALLFOLDER" Name="Only Torrent">
    $contents
    <Component Id="InstallRegistration" Guid="4E78BD91-67A6-46D8-9429-3493E7C73ED5" Win64="yes">
     <RegistryValue Root="HKLM" Key="Software\Only Torrent" Name="InstallFolder" Type="string" Value="[INSTALLFOLDER]" KeyPath="yes"/>
     <RemoveFolder Id="RemoveOnlyTorrentMenu" Directory="OnlyTorrentMenu" On="uninstall"/>
    </Component>
   </Directory></Directory>
   <Directory Id="ProgramMenuFolder"><Directory Id="OnlyTorrentMenu" Name="Only Torrent"/></Directory>
  </Directory>
  <Feature Id="MainFeature" Title="Only Torrent" Level="1">$($refs -join '')<ComponentRef Id="InstallRegistration"/></Feature>
  <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER"/>
  <WixVariable Id="WixUILicenseRtf" Value="$(Xml (Join-Path $root 'resources/installer-license.rtf'))"/>
  <UIRef Id="WixUI_InstallDir"/>
 </Product>
</Wix>
"@
$source = Join-Path $work 'OnlyTorrent.wxs'
[IO.File]::WriteAllText($source, $wxs, [Text.UTF8Encoding]::new($false))
& $candle -nologo -arch x64 -out "$work\" $source
if ($LASTEXITCODE -ne 0) { throw 'MSI compilation failed' }
& $light -nologo -ext (Join-Path $WixRoot 'WixUIExtension.dll') -cultures:en-us -out $output (Join-Path $work 'OnlyTorrent.wixobj')
if ($LASTEXITCODE -ne 0) { throw 'MSI linking/validation failed' }
((Get-FileHash -Algorithm SHA256 $output).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($output)) | Set-Content -Encoding ASCII ($output + '.sha256')
Write-Output "MSI installer: $output"
