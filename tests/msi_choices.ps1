param([Parameter(Mandatory=$true)][string]$Installer, [switch]$SkipUninstallUI)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$original = (Resolve-Path -LiteralPath $Installer).Path
$suffix = [Guid]::NewGuid().ToString('N')
$run = Join-Path $root ('build/msi-choices-' + $suffix)
$target = Join-Path $run 'Application files'
$copy = Join-Path $run 'test-only.msi'
$testKey = 'Software\Only Torrent Installer Tests\' + $suffix
$testName = 'Only Torrent Test ' + $suffix
$shortName = 'T' + $suffix.Substring(0,7)
$originalInstall = (Get-ItemProperty 'HKLM:\Software\Only Torrent' -ErrorAction SilentlyContinue).InstallFolder
$originalHash = $null
if ($originalInstall -and (Test-Path -LiteralPath (Join-Path $originalInstall 'otorrent.exe'))) {
  $originalHash = (Get-FileHash -LiteralPath (Join-Path $originalInstall 'otorrent.exe')).Hash
}
New-Item -ItemType Directory -Force $run | Out-Null
Copy-Item -LiteralPath $original -Destination $copy
$service = New-Object -ComObject WindowsInstaller.Installer
$db = $service.OpenDatabase($copy,1)
function Rows($sql) {
  $view=$db.OpenView($sql); [void]$view.Execute()
  try { while ($record=$view.Fetch()) { [pscustomobject]@{Key=$record.StringData(1); Value=$record.StringData(2)} } }
  finally { [void]$view.Close() }
}
function Sql($sql) { $view=$db.OpenView($sql); try { [void]$view.Execute() } finally { [void]$view.Close() } }
function Quote($text) { "'" + $text.Replace("'", "''") + "'" }
$product = '{' + [Guid]::NewGuid().ToString().ToUpperInvariant() + '}'
$upgrade = '{' + [Guid]::NewGuid().ToString().ToUpperInvariant() + '}'
Sql "UPDATE ``Property`` SET ``Value``='$product' WHERE ``Property``='ProductCode'"
Sql "UPDATE ``Property`` SET ``Value``='$upgrade' WHERE ``Property``='UpgradeCode'"
Sql 'DELETE FROM `Upgrade`'
# Every globally registered component gets a unique test GUID. No installed component is shared.
foreach ($row in (Rows 'SELECT `Component`,`ComponentId` FROM `Component`')) {
  $guid='{' + [Guid]::NewGuid().ToString().ToUpperInvariant() + '}'
  Sql "UPDATE ``Component`` SET ``ComponentId``='$guid' WHERE ``Component``=$(Quote $row.Key)"
}
foreach ($row in (Rows 'SELECT `Registry`,`Key` FROM `Registry`')) {
  $key=$row.Value.Replace('Software\Only Torrent',$testKey).Replace('Uninstall\OnlyTorrent','Uninstall\OnlyTorrentTest'+$suffix)
  Sql "UPDATE ``Registry`` SET ``Key``=$(Quote $key) WHERE ``Registry``=$(Quote $row.Key)"
}
foreach ($row in (Rows 'SELECT `Signature_`,`Key` FROM `RegLocator`')) {
  $key=$row.Value.Replace('Software\Only Torrent',$testKey)
  Sql "UPDATE ``RegLocator`` SET ``Key``=$(Quote $key) WHERE ``Signature_``=$(Quote $row.Key)"
}
Sql "UPDATE ``Directory`` SET ``DefaultDir``='$shortName|$testName' WHERE ``Directory``='OnlyTorrentMenu'"
Sql "UPDATE ``Directory`` SET ``DefaultDir``='$shortName|$testName' WHERE ``Directory``='INSTALLFOLDER'"
Sql "UPDATE ``Shortcut`` SET ``Name``='$shortName|$testName'"
Sql "UPDATE ``Registry`` SET ``Value``=$(Quote $testName) WHERE ``Name``='DisplayName'"
$summary=$db.SummaryInformation(1)
$summary.GetType().InvokeMember('Property',[Reflection.BindingFlags]::SetProperty,$null,$summary,@(9,('{' + [Guid]::NewGuid().ToString().ToUpperInvariant() + '}'))) | Out-Null
[void]$summary.Persist(); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($summary)
[void]$db.Commit()
[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($db); $db=$null
[GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect()
function Msi($arguments,$log) {
  $proc=Start-Process msiexec.exe -ArgumentList ($arguments+' /qn /norestart /l*v "'+(Join-Path $run $log)+'"') -WindowStyle Hidden -PassThru
  if (-not $proc.WaitForExit(120000)) { throw 'Test MSI operation timed out' }
  if ($proc.ExitCode -notin @(0,3010)) { throw "MSI failed ($($proc.ExitCode)); see $log" }
}
$desktop=[Environment]::GetFolderPath('CommonDesktopDirectory')
$programs=[Environment]::GetFolderPath('CommonPrograms')
$desktopLink=Join-Path $desktop ($testName+'.lnk')
$menuLink=Join-Path (Join-Path $programs $testName) ($testName+'.lnk')
$installed=$false
try {
  Msi ('/i "'+$copy+'" INSTALLFOLDER="'+$target+'" ADDLOCAL=MainFeature REMOVE=StartMenuFeature,DesktopFeature') 'install-none.log'
  $installed=$true
  if ((Test-Path -LiteralPath $desktopLink) -or (Test-Path -LiteralPath $menuLink)) { throw 'Disabled shortcuts were created' }
  if (-not (Test-Path -LiteralPath (Join-Path $target 'otorrent.exe'))) { throw 'Application feature missing' }
  if (-not [IO.Path]::GetFullPath($service.ProductInfo($product,'InstallLocation')).TrimEnd('\').Equals($target.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'MSI install location not registered correctly' }
  Msi ('/i "'+$copy+'" ADDLOCAL=MainFeature,StartMenuFeature,DesktopFeature') 'enable-shortcuts.log'
  if (-not (Test-Path -LiteralPath $desktopLink) -or -not (Test-Path -LiteralPath $menuLink)) { throw 'Selected shortcuts missing' }
  $shell=New-Object -ComObject WScript.Shell
  foreach ($link in @($desktopLink,$menuLink)) {
    if (-not $shell.CreateShortcut($link).TargetPath.Equals((Join-Path $target 'otorrent.exe'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Shortcut target incorrect' }
  }
  Msi ('/i "'+$copy+'" REMOVE=DesktopFeature') 'disable-desktop.log'
  if (Test-Path -LiteralPath $desktopLink) { throw 'Desktop shortcut was not removed' }
  if (-not (Test-Path -LiteralPath $menuLink)) { throw 'Start menu shortcut unexpectedly removed' }
  if (-not $SkipUninstallUI) {
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class OtUninstallWindows {
 delegate bool CB(IntPtr w, IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumWindows(CB cb, IntPtr p);
 [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr w, CB cb, IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr w, out uint p);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr w, StringBuilder s, int n);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr w, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr w);
 [DllImport("user32.dll")] static extern bool PostMessage(IntPtr w, uint m, IntPtr a, IntPtr b);
 public static IntPtr Form(int pid) { IntPtr found=IntPtr.Zero; EnumWindows((w,p)=> { uint id; GetWindowThreadProcessId(w,out id); var s=new StringBuilder(256); GetClassName(w,s,256); if (id==pid && s.ToString()=="TFormUninstall") found=w; return true; },IntPtr.Zero); return found; }
 public static IntPtr Button(IntPtr form,string text) { IntPtr found=IntPtr.Zero; EnumChildWindows(form,(w,p)=> { var s=new StringBuilder(512); GetWindowText(w,s,512); if(s.ToString()==text) found=w; return true; },IntPtr.Zero); return found; }
 public static void Click(IntPtr w) { if(w==IntPtr.Zero) throw new Exception("Button not found"); PostMessage(w,0xF5,IntPtr.Zero,IntPtr.Zero); }
}
'@
    $runner=Join-Path $run 'runner'; New-Item -ItemType Directory -Force $runner | Out-Null
    Copy-Item -LiteralPath (Join-Path $target 'otupdater.exe') -Destination (Join-Path $runner 'otupdater.exe')
    # The explicit opt-out is enforced in code as well as the disabled radio group.
    # Even a user/UI interaction cannot select deletion of real user profiles.
    $args='--uninstall '+$product+' --target "'+$target+'" --user-sid S-1-5-21-1000-2000-3000-9000 --elevated --keep-profiles'
    $gui=Start-Process (Join-Path $runner 'otupdater.exe') -ArgumentList $args -WindowStyle Hidden -PassThru
    try {
      $deadline=[DateTime]::UtcNow.AddSeconds(20); $form=[IntPtr]::Zero
      do { Start-Sleep -Milliseconds 100; $form=[OtUninstallWindows]::Form($gui.Id) } until ($form -ne [IntPtr]::Zero -or $gui.HasExited -or [DateTime]::UtcNow -gt $deadline)
      if ($form -eq [IntPtr]::Zero) { throw 'Uninstaller form not created' }
      $remove=[OtUninstallWindows]::Button($form,'Видалити')
      [OtUninstallWindows]::Click($remove)
      $deadline=[DateTime]::UtcNow.AddSeconds(10)
      while ([OtUninstallWindows]::IsWindowEnabled($remove) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
      if ([OtUninstallWindows]::IsWindowEnabled($remove)) { throw 'Uninstall action did not start' }
      $deadline=[DateTime]::UtcNow.AddSeconds(90)
      do { Start-Sleep -Milliseconds 200; $close=[OtUninstallWindows]::Button($form,'Закрити') } until (([OtUninstallWindows]::IsWindowEnabled($close)) -or [DateTime]::UtcNow -gt $deadline)
      if ((Test-Path -LiteralPath (Join-Path $target 'otorrent.exe')) -or [OtUninstallWindows]::IsWindowEnabled([OtUninstallWindows]::Button($form,'Видалити'))) { throw 'GUI uninstall did not complete successfully' }
      $installed=$false
      [OtUninstallWindows]::Click($close)
      if (-not $gui.WaitForExit(20000)) { throw 'Uninstaller did not close' }
    } finally { if (-not $gui.HasExited) { $gui.Kill() } }
  } else { Msi ('/x '+$product) 'remove.log'; $installed=$false }
  if ((Test-Path -LiteralPath $desktopLink) -or (Test-Path -LiteralPath $menuLink)) { throw 'Test shortcuts remain after uninstall' }
  if ($originalHash -and (Get-FileHash -LiteralPath (Join-Path $originalInstall 'otorrent.exe')).Hash -ne $originalHash) { throw 'Installed user application was modified' }
  Write-Output 'PASS: isolated MSI identity, no shortcuts, both shortcuts, selective shortcut removal, correct targets, uninstall and original installation preserved'
} finally {
  if ($installed) { Msi ('/x '+$product) 'cleanup.log' }
}
