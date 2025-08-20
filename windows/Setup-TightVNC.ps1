<# 
  Setup-TightVNC.ps1
  - Reconfigure password if TightVNC is installed.
  - Install (via winget) if missing, then configure.
  - Optionally open firewall ports 5900/5800 to ANY.

  NOTE: Classic VNC auth uses only the first 8 characters.
        Default password 'ccp2003!' is exactly 8 chars.
#>

param(
  [string]$VncPassword = "ccp2003!",
  [switch]$OpenFirewall = $true,
  [switch]$SetViewOnly,                    # use if you also want a view-only password
  [string]$ViewOnlyPassword = "ccp2003!"   # ignored unless -SetViewOnly is passed
)

function Assert-Admin {
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent())
      .IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "Run this script in an elevated PowerShell (Run as Administrator)."
  }
}

function Find-TvnServer {
  $cands = @(
    "$env:ProgramFiles\TightVNC\tvnserver.exe",
    "$env:ProgramFiles(x86)\TightVNC\tvnserver.exe"
  )
  foreach ($p in $cands) { if (Test-Path $p) { return $p } }
  return $null
}

function Install-TightVNC {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store, or install TightVNC manually."
  }
  Write-Host "Installing TightVNC via winget (GlavSoft.TightVNC)..."
  $proc = Start-Process -FilePath "cmd.exe" -ArgumentList '/c winget install -e --id GlavSoft.TightVNC --silent --accept-package-agreements --accept-source-agreements' -Wait -PassThru
  if ($proc.ExitCode -ne 0) {
    Write-Warning "winget install exit code: $($proc.ExitCode). Trying upgrade (in case it's already present)..."
    $up = Start-Process -FilePath "cmd.exe" -ArgumentList '/c winget upgrade -e --id GlavSoft.TightVNC --silent --accept-package-agreements --accept-source-agreements' -Wait -PassThru
    if ($up.ExitCode -ne 0) {
      Write-Warning "winget upgrade exit code: $($up.ExitCode)."
    }
  }
  $path = Find-TvnServer
  if (-not $path) { throw "TightVNC not found after winget. Install failed or path unusual." }
  return $path
}

function Configure-TightVNC {
  param([string]$ServerExe, [string]$Pass, [switch]$SetVO, [string]$VOPass)

  if ($Pass.Length -gt 8) {
    Write-Warning "VNC legacy auth truncates to 8 chars; your password will be truncated."
  }
  if ($SetVO -and $VOPass.Length -gt 8) {
    Write-Warning "View-only password will be truncated to 8 chars."
  }

  # Ensure service is installed & stopped
  Start-Process -FilePath $ServerExe -ArgumentList "-install" -Wait
  Set-Service -Name "TightVNC Server" -StartupType Automatic -ErrorAction SilentlyContinue
  Stop-Service -Name "TightVNC Server" -ErrorAction SilentlyContinue

  if ($SetVO) {
    Write-Host "Setting control and view-only passwords..."
    Start-Process -FilePath $ServerExe -ArgumentList "-controlservice -setpasswords `"$Pass`" `"$VOPass`"" -Wait
  } else {
    Write-Host "Setting control password (no view-only password)..."
    Start-Process -FilePath $ServerExe -ArgumentList "-controlservice -setpasswords `"$Pass`" "" " -Wait
  }

  Start-Service -Name "TightVNC Server"
}

function Open-VNCFirewall {
  Write-Host "Opening firewall to ANY on TCP 5900 (VNC) and 5800 (Web client)..."
  Get-NetFirewallRule -DisplayName "TightVNC VNC 5900" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  Get-NetFirewallRule -DisplayName "TightVNC Web 5800" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  New-NetFirewallRule -DisplayName "TightVNC VNC 5900" -Direction Inbound -Protocol TCP -LocalPort 5900 -Action Allow | Out-Null
  New-NetFirewallRule -DisplayName "TightVNC Web 5800" -Direction Inbound -Protocol TCP -LocalPort 5800 -Action Allow | Out-Null
}

try {
  Assert-Admin

  $tvnServer = Find-TvnServer
  if ($tvnServer) {
    Write-Host "TightVNC detected at: $tvnServer"
    Configure-TightVNC -ServerExe $tvnServer -Pass $VncPassword -SetVO:$SetViewOnly -VOPass $ViewOnlyPassword
  } else {
    Write-Host "TightVNC not found. Installing…"
    $tvnServer = Install-TightVNC
    Write-Host "Installed at: $tvnServer"
    Configure-TightVNC -ServerExe $tvnServer -Pass $VncPassword -SetVO:$SetViewOnly -VOPass $ViewOnlyPassword
  }

  if ($OpenFirewall) { Open-VNCFirewall }

  Write-Host "`nDone. TightVNC is ready."
  Write-Host "Password set to: $VncPassword (no username required)."
  if ($OpenFirewall) { Write-Host "Firewall open on 5900/5800 to ALL." }
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
