Import-Module "C:\vagrant\Functions.psm1"

Try
{
    Install-NuGet -Verbose
    Set-PsGalleryTrust -Policy Trusted -Verbose

    Install-Module xWebAdministration
    Install-Module cNtfsAccessControl
    Install-Module xCertificate
    Install-Module xSQLServer
    Install-Module SqlServer -AllowClobber

    Write-Output "Disable IE first-run dialog"
    New-Item -Path 'REGISTRY::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft' -Name 'Internet Explorer' -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path 'REGISTRY::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer' -Name 'Main' -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -Path 'REGISTRY::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main' -PropertyType DWORD -Name 'DisableFirstRunCustomize' -Value 1 -ErrorAction SilentlyContinue | Out-Null
    
    # Change SQL auth mode because the OS template we're using has it set to Windows-Only
    # This should be part of the SQL Server setup script (or a part of the original template, possibly created with )
    Write-Output "Set SQL authentication mode to Mixed"
    Set-ItemProperty -Path 'REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQLServer' -Name 'LoginMode' -Value 2 | Out-Null
    Restart-Service -Name MSSQLSERVER

    Write-Output "DSC prep complete"
}
Catch
{
    Write-Error "DSC prep incomplete!"
}
