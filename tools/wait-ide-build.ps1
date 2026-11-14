# Used only by explicitly requested builds. Inspect only the process we started.
function Wait-OtIdeBuild {
  param(
    [Parameter(Mandatory=$true)][System.Diagnostics.Process]$Process,
    [Parameter(Mandatory=$true)][string]$ErrorLog,
    [Parameter(Mandatory=$true)][datetime]$BuildStart,
    [ValidateRange(10,1800)][int]$TimeoutSeconds = 180
  )
  if (-not ('OtBuildDialogs' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class OtBuildDialogs {
    public sealed class Window {
        public IntPtr Handle, OkButton;
        public string Title, ClassName, Text;
    }
    private delegate bool Callback(IntPtr h, IntPtr state);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback cb, IntPtr state);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr h, Callback cb, IntPtr state);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr h, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr h, StringBuilder text, int length);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr h, StringBuilder text, int length);
    [DllImport("user32.dll")] private static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] private static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    private static string Text(IntPtr h) {
        var value = new StringBuilder(4096); GetWindowText(h, value, value.Capacity); return value.ToString();
    }
    private static string Class(IntPtr h) {
        var value = new StringBuilder(256); GetClassName(h, value, value.Capacity); return value.ToString();
    }
    public static Window[] Find(int process) {
        var result = new List<Window>();
        EnumWindows(delegate(IntPtr h, IntPtr state) {
            uint owner; GetWindowThreadProcessId(h, out owner);
            if (owner != (uint)process) return true;
            var window = new Window { Handle=h, Title=Text(h), ClassName=Class(h), OkButton=IntPtr.Zero };
            var text = new StringBuilder();
            EnumChildWindows(h, delegate(IntPtr child, IntPtr unused) {
                uint childOwner; GetWindowThreadProcessId(child, out childOwner);
                if (childOwner != (uint)process) return true;
                var caption = Text(child);
                if (caption.Length > 0) text.AppendLine(caption);
                var label = caption.Replace("&", "").Trim();
                bool button = Class(child).IndexOf("Button", StringComparison.OrdinalIgnoreCase) >= 0;
                if (button && IsWindowEnabled(child) &&
                    (label.Equals("OK", StringComparison.OrdinalIgnoreCase) || GetDlgCtrlID(child)==1))
                    window.OkButton = child;
                return true;
            }, IntPtr.Zero);
            window.Text = text.ToString(); result.Add(window); return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }
    public static void Confirm(Window window) {
        if (window.OkButton != IntPtr.Zero)
            PostMessage(window.OkButton, 0x00F5, IntPtr.Zero, IntPtr.Zero); // BM_CLICK
    }
}
'@
  }
  $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
  $failureAt = $null
  $failureReason = $null
  $handled = [Collections.Generic.HashSet[long]]::new()
  $dialogLog = [IO.Path]::ChangeExtension($ErrorLog, '.dialogs.log')
  while (-not $Process.WaitForExit(500)) {
    $logFailed = $false
    if (Test-Path -LiteralPath $ErrorLog) {
      if ((Get-Item -LiteralPath $ErrorLog).LastWriteTime -ge $BuildStart.AddSeconds(-2)) {
        try {
          $text = [IO.File]::ReadAllText($ErrorLog)
          $logFailed = $text -match '(?m)^Failed\s*$|^\[Exec Error\]'
        } catch [IO.IOException] {
          # The compiler may temporarily hold the log. Retry on the next tick.
        }
      }
    }
    if ($logFailed -and $null -eq $failureAt) {
      $failureAt = [datetime]::UtcNow
      $failureReason = "IDE reported a build failure. See $ErrorLog"
    }
    foreach ($window in [OtBuildDialogs]::Find($Process.Id)) {
      $isError = $window.Title -match '(?i)\b(error|exception)\b|\u043f\u043e\u043c\u0438\u043b\u043a\u0430|\u043e\u0448\u0438\u0431\u043a\u0430'
      $isBuild = ($window.Title -match '(?i)^build(?:\s.*)?$') -or
        ($window.ClassName -match '(?i)build(?:progress|status|result|dialog|dlg|form)')
      $failedText = $window.Text -match '(?i)\bfailed\b|there are errors|cannot create file|unable to'
      if (-not $isError -and -not ($isBuild -and ($logFailed -or $failedText))) { continue }
      if ($null -eq $failureAt) {
        $failureAt = [datetime]::UtcNow
        $failureReason = "IDE error dialog: $($window.Title). See $dialogLog"
      }
      if ($handled.Add($window.Handle.ToInt64())) {
        $details = "`r`n[$([datetime]::Now.ToString('s'))] PID $($Process.Id), $($window.ClassName): $($window.Title)`r`n$($window.Text)"
        [IO.File]::AppendAllText($dialogLog, $details, [Text.Encoding]::UTF8)
        Write-Warning "IDE failure dialog: $($window.Title). Confirming OK; details: $dialogLog"
        [OtBuildDialogs]::Confirm($window)
      }
    }
    if ($null -ne $failureAt -and [datetime]::UtcNow -ge $failureAt.AddSeconds(5)) {
      [void]$Process.CloseMainWindow()
      if (-not $Process.WaitForExit(3000)) {
        $Process.Kill()
        if (-not $Process.WaitForExit(5000)) { throw "Cannot stop failed IDE process $($Process.Id)" }
      }
      break
    }
    if ([datetime]::UtcNow -ge $deadline) {
      [void]$Process.CloseMainWindow()
      if (-not $Process.WaitForExit(3000)) {
        $Process.Kill()
        if (-not $Process.WaitForExit(5000)) { throw "Cannot stop timed-out IDE process $($Process.Id)" }
      }
      throw "IDE build timed out after $TimeoutSeconds seconds. See $ErrorLog"
    }
  }
  if ($null -ne $failureReason) { throw $failureReason }
}
