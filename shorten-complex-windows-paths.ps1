<#
.SYNOPSIS
    Shorten complex Windows paths with NTFS junctions, directory symbolic links, SUBST, and New-PSDrive.

.DESCRIPTION
    This script accompanies the Darien's Tips video:
    "Shorten Complex Windows Paths with Junctions, Symlinks & SUBST"

    It demonstrates several methods for simplifying long or complex Windows paths,
    especially paths used with offline update workflows, DISM, and Add-WindowsPackage.

    By default, this script does not apply a Windows update package. The servicing
    command only runs when -ApplyPackage is explicitly specified.

.NOTES
    Author: Darien's Tips
    YouTube: https://www.youtube.com/@darienstips9409
    GitHub:  https://github.com/DariensTips

    Run from an elevated PowerShell session when applying Windows packages.
    Creating directory symbolic links may also require elevation unless Developer Mode
    allows non-elevated symbolic link creation.

.EXAMPLE
    .\shorten-complex-windows-paths.ps1 -CreateJunction

    Creates a local NTFS junction at C:\Updates that points to the complex local path.

.EXAMPLE
    .\shorten-complex-windows-paths.ps1 -CreateSymbolicLink

    Creates a directory symbolic link at C:\Updates that points to the UNC network path.

.EXAMPLE
    .\shorten-complex-windows-paths.ps1 -CreateSubst

    Maps the complex local path to the U: drive letter by using SUBST.

.EXAMPLE
    .\shorten-complex-windows-paths.ps1 -CreateJunction -ApplyPackage

    Creates the junction and runs Add-WindowsPackage by using the shortened path.

.EXAMPLE
    .\shorten-complex-windows-paths.ps1 -CleanUp

    Removes the C:\Updates link if it is a junction or symbolic link, removes the
    temporary PowerShell drive, and deletes the SUBST drive mapping if present.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ComplexPath = "C:\Shares\Windows Update Catalog\Windows 11\2{4,5}H2\April 30, 2026—KB5083631 (OS Builds 26200.8328 and 26100.8328) Preview",

    [string]$NetworkComplexPath = "\\share\Upgrade\Updates\Windows Update Catalog\Windows 11\2{4,5}H2\April 30 2026 KB5083631 (OS Builds 26200-8328 and 26100-8328) Preview",

    [string]$UpdateFileName = "windows11.0-kb5083631-x64_a9979e387050abf3bc9feca1a024033209cbc804.msu",

    [string]$LocalLinkPath = "C:\Updates",

    [ValidatePattern("^[A-Za-z]:$")]
    [string]$SubstDrive = "U:",

    [ValidatePattern("^[A-Za-z][A-Za-z0-9_]*$")]
    [string]$PSDriveName = "M",

    [switch]$CreateJunction,

    [switch]$CreateSymbolicLink,

    [switch]$CreateSubst,

    [switch]$CreatePSDrive,

    [switch]$ApplyPackage,

    [switch]$CleanUp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# 1. Helper functions
# ------------------------------------------------------------

function Test-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-CurrentConfiguration {
    Write-Host ""
    Write-Host "Current Configuration" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host "Complex local path : $ComplexPath"
    Write-Host "Complex UNC path   : $NetworkComplexPath"
    Write-Host "Update file        : $UpdateFileName"
    Write-Host "Local link path    : $LocalLinkPath"
    Write-Host "SUBST drive        : $SubstDrive"
    Write-Host "PSDrive name       : $PSDriveName"
    Write-Host ""
}

function Assert-TargetPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description does not exist: $Path"
    }
}

function Assert-LinkPathAvailable {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        throw "The link path already exists: $Path. Existing item type: $($item.LinkType). Remove it first or choose a different -LocalLinkPath."
    }
}

function New-LocalDirectoryJunction {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Target
    )

    Assert-TargetPath -Path $Target -Description "Junction target"
    Assert-LinkPathAvailable -Path $Path

    if ($PSCmdlet.ShouldProcess($Path, "Create NTFS junction to '$Target'")) {
        New-Item -ItemType Junction -Path $Path -Target $Target | Select-Object FullName, LinkType, Target
    }
}

function New-DirectorySymbolicLink {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Target
    )

    Assert-LinkPathAvailable -Path $Path

    if ($PSCmdlet.ShouldProcess($Path, "Create directory symbolic link to '$Target'")) {
        New-Item -ItemType SymbolicLink -Path $Path -Target $Target | Select-Object FullName, LinkType, Target
    }
}

function New-SubstDriveMapping {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Drive,

        [Parameter(Mandatory)]
        [string]$Target
    )

    Assert-TargetPath -Path $Target -Description "SUBST target"

    if ($PSCmdlet.ShouldProcess($Drive, "Map folder path with SUBST to '$Target'")) {
        & subst.exe $Drive "$Target"

        if ($LASTEXITCODE -ne 0) {
            throw "SUBST failed with exit code $LASTEXITCODE."
        }

        & subst.exe
    }
}

function New-TemporaryFileSystemPSDrive {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Root
    )

    Assert-TargetPath -Path $Root -Description "New-PSDrive root"

    if (Get-PSDrive -Name $Name -ErrorAction SilentlyContinue) {
        throw "The PowerShell drive '$Name' already exists in this session."
    }

    if ($PSCmdlet.ShouldProcess("${Name}:", "Create temporary PowerShell FileSystem drive to '$Root'")) {
        New-PSDrive -PSProvider FileSystem -Name $Name -Root $Root | Select-Object Name, Provider, Root
    }
}

function Invoke-OfflinePackageInstall {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$PackagePath
    )

    if (-not (Test-Administrator)) {
        throw "Applying Windows packages requires an elevated PowerShell session."
    }

    if (-not (Test-Path -LiteralPath $PackagePath)) {
        throw "Package file was not found: $PackagePath"
    }

    if ($PSCmdlet.ShouldProcess($PackagePath, "Install Windows package with Add-WindowsPackage")) {
        Add-WindowsPackage -Online -PackagePath $PackagePath -NoRestart
    }
}

function Remove-LinkIfSafe {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Link path not found: $Path"
        return
    }

    $item = Get-Item -LiteralPath $Path -Force
    $item | Select-Object FullName, LinkType, Target

    if ($item.LinkType -in @("Junction", "SymbolicLink")) {
        if ($PSCmdlet.ShouldProcess($Path, "Remove link only")) {
            Remove-Item -LiteralPath $Path
            Write-Host "Removed link: $Path"
        }
    }
    else {
        Write-Warning "Refusing to remove '$Path' because it does not appear to be a junction or symbolic link."
    }
}

function Remove-SubstDriveMapping {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$Drive
    )

    $substOutput = & subst.exe
    $isMapped = $substOutput -match ("^{0}:" -f [regex]::Escape($Drive.TrimEnd(":")))

    if ($isMapped) {
        if ($PSCmdlet.ShouldProcess($Drive, "Remove SUBST drive mapping")) {
            & subst.exe $Drive /D
            Write-Host "Removed SUBST mapping: $Drive"
        }
    }
    else {
        Write-Host "SUBST mapping not found: $Drive"
    }
}

# ------------------------------------------------------------
# 2. Show configuration
# ------------------------------------------------------------

Show-CurrentConfiguration

# ------------------------------------------------------------
# 3. Create an NTFS directory junction for a local folder target
# ------------------------------------------------------------

if ($CreateJunction) {
    New-LocalDirectoryJunction -Path $LocalLinkPath -Target $ComplexPath
}

# ------------------------------------------------------------
# 4. Create a directory symbolic link for a UNC/network target
# ------------------------------------------------------------

if ($CreateSymbolicLink) {
    New-DirectorySymbolicLink -Path $LocalLinkPath -Target $NetworkComplexPath
}

# ------------------------------------------------------------
# 5. Create a temporary drive-letter substitution with SUBST
# ------------------------------------------------------------

if ($CreateSubst) {
    New-SubstDriveMapping -Drive $SubstDrive -Target $ComplexPath
}

# ------------------------------------------------------------
# 6. Create a temporary PowerShell FileSystem drive
# ------------------------------------------------------------

if ($CreatePSDrive) {
    New-TemporaryFileSystemPSDrive -Name $PSDriveName -Root $ComplexPath
}

# ------------------------------------------------------------
# 7. Apply the update package only when explicitly requested
# ------------------------------------------------------------

if ($ApplyPackage) {
    if ($CreateSubst) {
        $packagePath = Join-Path -Path "$SubstDrive\" -ChildPath $UpdateFileName
    }
    else {
        $packagePath = Join-Path -Path $LocalLinkPath -ChildPath $UpdateFileName
    }

    Invoke-OfflinePackageInstall -PackagePath $packagePath
}

# ------------------------------------------------------------
# 8. Cleanup
# ------------------------------------------------------------

if ($CleanUp) {
    Remove-LinkIfSafe -Path $LocalLinkPath

    if (Get-PSDrive -Name $PSDriveName -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess("${PSDriveName}:", "Remove temporary PowerShell drive")) {
            Remove-PSDrive -Name $PSDriveName
            Write-Host "Removed PowerShell drive: ${PSDriveName}:"
        }
    }

    Remove-SubstDriveMapping -Drive $SubstDrive
}

# ------------------------------------------------------------
# 9. If no action was selected, show examples
# ------------------------------------------------------------

if (-not ($CreateJunction -or $CreateSymbolicLink -or $CreateSubst -or $CreatePSDrive -or $ApplyPackage -or $CleanUp)) {
    Write-Host "No action selected." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\shorten-complex-windows-paths.ps1 -CreateJunction"
    Write-Host "  .\shorten-complex-windows-paths.ps1 -CreateSymbolicLink"
    Write-Host "  .\shorten-complex-windows-paths.ps1 -CreateSubst"
    Write-Host "  .\shorten-complex-windows-paths.ps1 -CreatePSDrive"
    Write-Host "  .\shorten-complex-windows-paths.ps1 -CreateJunction -ApplyPackage"
    Write-Host "  .\shorten-complex-windows-paths.ps1 -CleanUp"
}
