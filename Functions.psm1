Function Install-Chocolatey
{
    [CmdletBinding()] Param()

    If ( $env:ChocolateyInstall )
    {
        Write-Output 'Chocolatey is installed.'
    }
    Else
    {
        Try
        {
            Write-Verbose 'Installing Chocolatey...'
            Invoke-Expression ( ( New-Object System.Net.WebClient ).DownloadString( 'https://chocolatey.org/install.ps1' ) )
            Write-Output 'Chocolatey installed successfuly.'
        }
        Catch
        {
            Write-Error "Chocolatey failed to install. Chocolatey is required to continue this script. $( $Error[0].Exception.Message )"
            Exit
        }
    }
}

Function Install-ChocolateyPackage
{
    [CmdletBinding()]
    Param
    (
        [String] $Package
    )

    $PackageStatus = Choco list --local-only --exact $Package
    If ( $PackageStatus -Match '1 packages installed.' )
    {
        Write-Output "$Package is installed."
    }
    Else
    {
        Try
        {
            Write-Verbose "Installing $Package..."
            choco install $Package -y
            Write-Output "$Package installed successfuly."
        }
        Catch
        {
            Write-Warning "Package $Package failed to install."
        }
    }
}

Function Install-NuGet
{
    [CmdletBinding()] Param()
    
    Write-Verbose 'Searching for NuGet PackageProvider...'
    If ( ( Get-PackageProvider ).Name -Contains 'NuGet' )
    {
        Write-Output 'NuGet is installed.'
    }
    Else
    {
        Write-Verbose 'Installing NuGet...'
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Write-Output 'NuGet installed successfuly.'
    }
}

Function Set-PsGalleryTrust
{
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory )]
        [ValidateSet( 'Trusted','UnTrusted' )]
        $Policy
    )

    If ( ( Get-PSRepository -Name PSGallery ).InstallationPolicy -EQ $Policy )
    {
        Write-Output "PSGallery is $Policy."
    }
    Else
    {
        Write-Verbose "Setting PSGallery as $Policy source..."
        Set-PSRepository -Name PSGallery -InstallationPolicy $Policy
        Write-Output "PSGallery is now $Policy."
    }
}

Function Connect-Mstsc
{
    # Majority of function code from: https://gallery.technet.microsoft.com/Connect-Mstsc-Open-RDP-2064b10b
    Param
    (
        $User,
        $Password,
        $ComputerName
    )

    $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
    $Process     = New-Object System.Diagnostics.Process
            
    # Remove the port number for CmdKey otherwise credentials are not entered correctly
    If ($ComputerName.Contains(':'))
    {
        $ComputerCmdkey = ($ComputerName -split ':')[0]
    }
    Else
    {
        $ComputerCmdkey = $ComputerName
    }

    # Add credential to Credential Manager
    $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\cmdkey.exe"
    $ProcessInfo.Arguments   = "/generic:TERMSRV/$ComputerCmdkey /user:$User /pass:$($Password)"
    $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $Process.StartInfo       = $ProcessInfo
    [void]$Process.Start()

    # Start remote desktop
    $ProcessInfo.FileName    = "$env:SystemRoot\system32\mstsc.exe"
    $ProcessInfo.Arguments   = "/v $ComputerName"
    $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
    $Process.StartInfo       = $ProcessInfo
    [void]$Process.Start()
}

Function Restore-VagrantEnvironment
{
    Set-Location (Join-Path $env:USERPROFILE 'vagrant')
    C:\HashiCorp\Vagrant\bin\vagrant.exe destroy -f
    C:\HashiCorp\Vagrant\bin\vagrant.exe up
}

Export-ModuleMember -Function *