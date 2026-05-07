# Shorten Complex Windows Paths with Junctions, Symlinks & SUBST

This repository accompanies the Darien's Tips video:

**Shorten Complex Windows Paths with Junctions, Symlinks & SUBST**

Complex Windows paths can occasionally cause problems when working with offline update packages, DISM, `Add-WindowsPackage`, and other servicing workflows. Sometimes the problem is not only path length. The issue can also be the combination of spaces, braces, commas, parentheses, dashes, update names, and other special characters.

This guide demonstrates several ways to expose the same files through a shorter, cleaner path without moving the original folder structure.

## What You Will Learn

- How to shorten complex Windows folder paths
- How to create an NTFS directory junction with PowerShell
- How to create a directory symbolic link for local or UNC paths
- How to use `SUBST` to map a long folder path to a drive letter
- How to use `mklink` from Command Prompt
- Why `New-PSDrive` is useful but not always recognized by servicing tools
- How to safely verify and clean up links and drive mappings

## Files

| File | Purpose |
|---|---|
| `shorten-complex-windows-paths.ps1` | PowerShell companion script for creating junctions, symlinks, SUBST mappings, PSDrives, optional package installation, and cleanup. |
| `README.md` | Documentation, examples, and safety notes. |

## Core Concepts

### NTFS Junction

An NTFS junction is a local folder-to-folder redirect using an NTFS reparse point.

Example:

```powershell
New-Item -ItemType Junction -Path "C:\Updates" -Target "D:\Long\Complex\Update\Folder"
```

### Directory Symbolic Link

A directory symbolic link is more flexible than a junction and can point to local paths, relative paths, or UNC network paths.

Example:

```powershell
New-Item -ItemType SymbolicLink -Path "C:\Updates" -Target "\\server\share\Long\Complex\Update\Folder"
```

### SUBST

`SUBST` maps a folder path to a temporary drive letter.

Example:

```powershell
subst U: "D:\Long\Complex\Update\Folder"
```

Then the folder can be accessed as:

```powershell
U:\
```

### New-PSDrive

`New-PSDrive` creates a PowerShell drive through the PowerShell provider system.

Example:

```powershell
New-PSDrive -PSProvider FileSystem -Name M -Root "D:\Long\Complex\Update\Folder"
```

This is useful for PowerShell navigation, but it is not the same as an NTFS junction, directory symbolic link, or `SUBST` drive letter. Some external tools and servicing components may not understand the PowerShell drive path.

## Example Video Scenario

The video uses a complex Windows Update Catalog-style folder path:

```powershell
$weirdAhssPath = "C:\Shares\Windows Update Catalog\Windows 11\2{4,5}H2\April 30, 2026—KB5083631 (OS Builds 26200.8328 and 26100.8328) Preview"
$daUpdate = "windows11.0-kb5083631-x64_a9979e387050abf3bc9feca1a024033209cbc804.msu"
```

An update command using the original complex path may fail:

```powershell
Add-WindowsPackage -Online -PackagePath "$weirdAhssPath\$daUpdate" -NoRestart
```

A shorter path can simplify the workflow:

```powershell
New-Item -ItemType Junction -Path "C:\Updates" -Target $weirdAhssPath
Add-WindowsPackage -Online -PackagePath "C:\Updates\$daUpdate" -NoRestart
```

## PowerShell Companion Script

The script is designed to be safe by default.

It does **not** apply an update package unless you explicitly use `-ApplyPackage`.

### Show configuration and examples

```powershell
.\shorten-complex-windows-paths.ps1
```

### Create a local directory junction

```powershell
.\shorten-complex-windows-paths.ps1 -CreateJunction
```

### Create a directory symbolic link to a UNC path

```powershell
.\shorten-complex-windows-paths.ps1 -CreateSymbolicLink
```

### Create a SUBST drive mapping

```powershell
.\shorten-complex-windows-paths.ps1 -CreateSubst
```

### Create a temporary PowerShell drive

```powershell
.\shorten-complex-windows-paths.ps1 -CreatePSDrive
```

### Create a junction and apply the update package

Run this from an elevated PowerShell session:

```powershell
.\shorten-complex-windows-paths.ps1 -CreateJunction -ApplyPackage
```

### Create a SUBST mapping and apply the update package

Run this from an elevated PowerShell session:

```powershell
.\shorten-complex-windows-paths.ps1 -CreateSubst -ApplyPackage
```

### Cleanup

```powershell
.\shorten-complex-windows-paths.ps1 -CleanUp
```

## Command Prompt Equivalents

### Create a directory symbolic link

```cmd
set "weirdAhssNetworkPath=\\share\Upgrade\Updates\Windows Update Catalog\Windows 11\2{4,5}H2\April 30 2026 KB5083631 (OS Builds 26200-8328 and 26100-8328) Preview"
mklink /D "C:\Updates" "%weirdAhssNetworkPath%"
```

### Create a local directory junction

```cmd
set "weirdAhssPath=C:\Shares\Windows Update Catalog\Windows 11\2{4,5}H2\April 30, 2026—KB5083631 (OS Builds 26200.8328 and 26100.8328) Preview"
mklink /J "C:\Updates" "%weirdAhssPath%"
```

### Apply an update with DISM

```cmd
set "daUpdate=windows11.0-kb5083631-x64_a9979e387050abf3bc9feca1a024033209cbc804.msu"
DISM /Online /Add-Package /PackagePath:"C:\Updates\%daUpdate%" /NoRestart
```

### Create a SUBST drive and apply an update

```cmd
subst V: "%weirdAhssPath%"
DISM /Online /Add-Package /PackagePath:"V:\%daUpdate%" /NoRestart
```

### Remove a link created by mklink

```cmd
rmdir C:\Updates
```

### Remove a SUBST drive mapping

```cmd
subst /D V:
```

## Verify Before Cleanup

Before removing a link, verify that the path is actually a junction or symbolic link:

```powershell
Get-Item -LiteralPath "C:\Updates" | Select-Object FullName, LinkType, Target
```

Then remove the link:

```powershell
Remove-Item -LiteralPath "C:\Updates"
```

The goal is to remove the link, not the target folder contents.

## Glossary

- **NTFS Junction** — A local folder-to-folder redirect using an NTFS reparse point.
- **Symbolic Link** — A file system link that points to another file, folder, or UNC path.
- **SUBST** — A command that maps a folder path to a temporary drive letter.
- **mklink** — A Command Prompt tool for creating junctions and symbolic links.
- **New-Item** — A PowerShell cmdlet used to create links, files, and folders.
- **DISM** — Deployment Image Servicing and Management; a Windows servicing tool.
- **Add-WindowsPackage** — A PowerShell cmdlet for installing Windows update packages.
- **UNC Path** — Universal Naming Convention; a network path like `\\server\share`.

## Safety Notes

- Test in a lab before using on production systems.
- Verify the link target before running servicing commands.
- Do not remove a path until you confirm whether it is a link or a real folder.
- Run Windows servicing commands from an elevated PowerShell session or elevated Command Prompt.
- Creating directory symbolic links may require elevation unless Developer Mode allows non-elevated symlink creation.
- Keep backups and recovery options available before servicing Windows images or systems.

## Disclaimer

This content is for educational and lab demonstration purposes. Always validate commands in your own environment before using them on production systems. The author is not responsible for data loss, failed updates, misconfigured links, or unintended changes caused by running commands without proper testing, backups, and change-control procedures.

## Related

- YouTube: [Darien's Tips](https://www.youtube.com/@darienstips9409)
- GitHub: [DariensTips](https://github.com/DariensTips)
