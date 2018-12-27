Import-Module "$PSScriptRoot\Functions.psm1"

$VagrantDir      = Join-Path $env:USERPROFILE 'vagrant'
#$VagrantFilePath = Join-Path $VagrantDir 'vagrantfile'
#$NewVagrantFile  = Join-Path $PSScriptRoot 'vagrantfile'
$RewriteFilePath = Join-Path $VagrantDir "rewrite_amd64.msi"
    
# Check for local admin privelages
$Principal = New-Object System.Security.Principal.WindowsPrincipal ( [System.Security.Principal.WindowsIdentity]::GetCurrent() )
If ( $Principal.IsInRole( [System.Security.Principal.WindowsBuiltInRole]::Administrator ) -eq $False )
{
    Write-Warning "This script requires administrative privelages. Please re-run the script as Admin."
    Return
}

$FirewallParams =
@{
    DisplayName   = "Allow VirtualBox"
    Direction     = "Inbound"
    Program       = "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe"
    RemoteAddress = "Any"
    Action        = "Allow"
    Enabled       = "True"
    Profile       = "Any"
}

If ( -not ( Get-NetFirewallRule -DisplayName $FirewallParams.DisplayName -ErrorAction SilentlyContinue ) )
{
    New-NetFirewallRule @FirewallParams
}
Else
{
    Write-Verbose "Firewall rule `"$( $FirewallParams.DisplayName )`" is already added"
}

# Download DSC resources (modules)
Install-NuGet -Verbose
Set-PsGalleryTrust -Policy Trusted -Verbose

# Download and install applications
Install-Chocolatey -Verbose
Install-ChocolateyPackage -Package virtualbox -Verbose
Install-ChocolateyPackage -Package vagrant -Verbose
# Current version of Vagrant Manager has issues; skipping it for now (otherwise is super cool)
#Install-ChocolateyPackage -Package vagrant-manager -Verbose

If ( -not ( Test-Path $RewriteFilePath ) )
{
    Write-Output "Downloading IIS URL Rewrite installer.."
    $RewriteUri = 'http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi'
    ( New-Object System.Net.WebClient ).DownloadFile( $RewriteUri, $RewriteFilePath )
}

# Copy Vagrant settings file to main directory
If ( -not (Test-Path $VagrantDir) )
{
    New-Item -Path $VagrantDir -ItemType Directory
}

#If ( Test-Path $VagrantFilePath )
#{
#    Write-Verbose "File `"$VagrantFilePath`" already exists, backing up existing file."
#    $VagrantFileBackup = Join-Path $VagrantFilePath ( Get-Date -Format u )
#    Copy-Item -Path $VagrantFilePath -Destination $VagrantFileBackup
#}
#Copy-Item -Path $NewVagrantFile -Destination $VagrantFilePath -Force

# Create and provision VMs (via vagrantfile)
Set-Location -Path $VagrantDir
Try
{
    C:\HashiCorp\Vagrant\bin\vagrant.exe up

    Write-Host "Connecting to virtual machine (RDP)"
    Connect-Mstsc -User 'itxdev\administrator' -Password 'vagrant' -ComputerName "localhost:33389"
    Write-Host -ForegroundColor Green "Provisioning complete!"
}
Catch
{
    Write-Warning "Unable to spin up virtual machine! Error: $( $Error[0].Exception.Message )"
}
