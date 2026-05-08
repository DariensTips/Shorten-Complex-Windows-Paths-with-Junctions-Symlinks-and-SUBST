<#
.SYNOPSIS
    Demo companion script for shortening complex Windows paths with junctions, symlinks, SUBST, and New-PSDrive.

.DESCRIPTION
    This file is intentionally written to align with the video presentation/script.
    It avoids helper functions and keeps the commands visible, direct, and easy to
    copy/paste during a tutorial.

    Recommended use:
    - Run one section at a time.
    - Update paths to match your lab.
    - Verify targets before creating or removing links.
    - Use an elevated PowerShell session for Windows servicing commands.

.NOTES
    Video Title:
    Shorten Complex Windows Paths with Junctions, Symlinks & SUBST

    Author: Darien's Tips
    YouTube: https://www.youtube.com/@darienstips9409
    GitHub:  https://github.com/DariensTips
#>

# ==================================================================================================
# (A) Introduction
# ==================================================================================================

# Complex Windows Update Catalog-style path.
$weirdAhssPath = "C:\Shares\Windows Update Catalog\Windows 11\2{4,5}H2\April 30, 2026—KB5083631 (OS Builds 26200.8328 and 26100.8328) Preview"

# MSU update package name.
$daUpdate = "windows11.0-kb5083631-x64_a9979e387050abf3bc9feca1a024033209cbc804.msu"

# Example that may fail in some scenarios because of the complex path.
# Run from an elevated PowerShell session if testing with a real package.
# Add-WindowsPackage -Online -PackagePath "$weirdAhssPath\$daUpdate" -NoRestart

# Similar-length path with fewer special characters.
$longAhssPath = "C:\Shares\Windows Update Catalog\Windows 11\2xH2\April 30 2026 KB5083631 (OS Builds 26200-8328 and 26100-8328) Preview"

# Example using the cleaner path.
# Add-WindowsPackage -Online -PackagePath "$longAhssPath\$daUpdate" -NoRestart


# ==================================================================================================
# (B) What is...?
# ==================================================================================================

<#
NTFS Junction:
    A local folder-to-folder redirect using an NTFS reparse point.

Directory Symbolic Link:
    A file system link that can point to a local folder, relative path, or UNC network path.

SUBST:
    A command that associates an existing folder path with a temporary drive letter.

Important distinction:
    Junctions and symbolic links create file system links.
    SUBST creates a temporary virtual drive letter.
#>


# ==================================================================================================
# (C) PowerShell: New-Item
# ==================================================================================================

# One remedy is to use New-Item to create either an NTFS junction or a directory symbolic link.

# Local folder target for a junction.
# The -Path value is the new link path.
# The -Target value is the existing folder being exposed through the link.

# Verify whether the link path already exists.
Test-Path -LiteralPath "C:\Updates"

# Create a local directory junction.
# Use this when the target is a local folder.
New-Item -ItemType Junction -Path "C:\Updates" -Target $weirdAhssPath

# Network UNC target for a directory symbolic link.
$weirdAhssNetworkPath = "\\share\Upgrade\Updates\Windows Update Catalog\Windows 11\2{4,5}H2\April 30 2026 KB5083631 (OS Builds 26200-8328 and 26100-8328) Preview"

# If the target is a network share, use a directory symbolic link instead of a junction.
# IMPORTANT:
# Remove or rename C:\Updates before running this if the junction above already exists.
# New-Item -ItemType SymbolicLink -Path "C:\Updates" -Target $weirdAhssNetworkPath

# Listing the linked folder shows the target contents through the shorter path.
Get-ChildItem -Path "C:\Updates"

# List the root of the C: drive and notice the link attribute.
Get-ChildItem -Path "C:\"

# Show the link type and target.
Get-ItemProperty -Path "C:\Updates" | Select-Object *

# Open the root of C: in File Explorer.
explorer.exe "C:\"

# Apply the update using the shortened path.
# Run from an elevated PowerShell session if testing with a real package.
# Add-WindowsPackage -Online -PackagePath "C:\Updates\$daUpdate" -NoRestart


# ==================================================================================================
# (D) PowerShell: SUBST
# ==================================================================================================

# SUBST associates a path with a drive letter.
# This can shorten and simplify long or complicated paths.

# Map the complex path to U:.
subst U: "$weirdAhssPath"

# Use the command by itself to display current SUBST mappings.
subst

# Get-PSDrive may show the drive as a file system drive.
Get-PSDrive

# Because SUBST creates a virtual drive-letter substitution, it will not appear as a real volume.
Get-Volume

# Depending on how the command was launched, especially elevation context,
# the substituted drive may not appear everywhere you expect in File Explorer.
# The reliable confirmation method is the SUBST command itself.

# Apply the update using the substituted drive letter.
# Run from an elevated PowerShell session if testing with a real package.
# Add-WindowsPackage -Online -PackagePath "U:\$daUpdate" -NoRestart


# ==================================================================================================
# (E) Command Prompt: mklink
# ==================================================================================================

<#
The following examples are Command Prompt examples.

Open an elevated Command Prompt and run:

mklink /?

Use safe SET syntax so the quotation marks protect the assignment without becoming part of the value.

set "weirdAhssPath=C:\Shares\Windows Update Catalog\Windows 11\2{4,5}H2\April 30, 2026—KB5083631 (OS Builds 26200.8328 and 26100.8328) Preview"
set "daUpdate=windows11.0-kb5083631-x64_a9979e387050abf3bc9feca1a024033209cbc804.msu"

Directory symbolic link for a UNC/network target:

set "weirdAhssNetworkPath=\\share\Upgrade\Updates\Windows Update Catalog\Windows 11\2{4,5}H2\April 30 2026 KB5083631 (OS Builds 26200-8328 and 26100-8328) Preview"
mklink /D "C:\Updates" "%weirdAhssNetworkPath%"

Directory junction for a local folder target:

mklink /J "C:\Updates" "%weirdAhssPath%"

Apply the update with DISM:

DISM /Online /Add-Package /PackagePath:"C:\Updates\%daUpdate%" /NoRestart
#>


# ==================================================================================================
# (F) Command Prompt: SUBST
# ==================================================================================================

<#
The following examples are Command Prompt examples.

Declare variables:

set "weirdAhssPath=C:\Shares\Windows Update Catalog\Windows 11\2{4,5}H2\April 30, 2026—KB5083631 (OS Builds 26200.8328 and 26100.8328) Preview"
set "daUpdate=windows11.0-kb5083631-x64_a9979e387050abf3bc9feca1a024033209cbc804.msu"

Associate the path with a drive letter:

subst V: "%weirdAhssPath%"

Apply the update with DISM:

DISM /Online /Add-Package /PackagePath:"V:\%daUpdate%" /NoRestart
#>


# ==================================================================================================
# (G) New-PSDrive
# ==================================================================================================

# New-PSDrive can shorten and simplify a path inside PowerShell.
# It is useful for PowerShell navigation, but it is not the same as an NTFS junction,
# directory symbolic link, or SUBST drive letter.

# Create a temporary PowerShell FileSystem drive.
New-PSDrive -PSProvider FileSystem -Name M -Root $weirdAhssPath

# Show properties.
Get-ItemProperty "M:\" | Select-Object *

# Navigate into the PowerShell drive and interact with files.
Set-Location "M:\"
Get-ChildItem
Get-FileHash "M:\$daUpdate"

# These may not work with Windows servicing tools because M: is a PowerShell drive,
# not a true file system link or SUBST drive.
# Add-WindowsPackage -Online -PackagePath "M:\$daUpdate" -NoRestart
# DISM /Online /Add-Package /PackagePath:"M:\$daUpdate" /NoRestart

# Return to C:\ before cleanup.
Set-Location "C:\"


# ==================================================================================================
# (H) Clean Up
# ==================================================================================================

# Verify the path before removing it.
Get-Item -LiteralPath "C:\Updates" | Select-Object FullName, LinkType, Target

# Remove the junction or symbolic link.
# This removes the link itself, not the target folder contents.
Remove-Item -LiteralPath "C:\Updates"

# Command Prompt equivalent for removing a link created by mklink:
# rmdir C:\Updates

# Remove the U: drive letter created with SUBST.
subst /D U:

# If you also created V: from Command Prompt, remove it as well:
# subst /D V:

# Remove the temporary PowerShell drive if it exists in this session.
Remove-PSDrive -Name M -ErrorAction SilentlyContinue
