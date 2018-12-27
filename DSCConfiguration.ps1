
[DSCLocalConfigurationManager()]
Configuration MetaConfiguration
{
    Node 'localhost'
    {
        Settings
        {
            ConfigurationMode              = 'ApplyOnly'
            ConfigurationModeFrequencyMins = 60
            RefreshMode                    = 'Push'
            RebootNodeIfNeeded             = $True
        }
    }
}

Configuration DscConfiguration
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName cNtfsAccessControl
    Import-DscResource -ModuleName xCertificate
    Import-DscResource -ModuleName xSQLServer

    Node localhost
    {
        # Site files
        $WebsiteFilesZipPath = "C:\vagrant\domain.tld.zip"
        $WebsitePath         = "c:\inetpub\domain.tld"
        $WebsiteName         = "domain.tld"

        # SSL certificate
        $WebsiteCertPath       = "C:\vagrant\domain.tld.pfx"
        $WebsiteCertThumbprint = ""
        $WebsiteCertPassword   = Get-Content -Path "C:\vagrant\CertPassword.txt" | ConvertTo-SecureString -AsPlainText -Force
        $WebsiteCertCredential = [PSCredential]::new( 'null', $WebsiteCertPassword )

        # SQL info
        $SQLDBName       = "domain"
        $SQLDBBackupPath = "C:\vagrant\domain-db.bak"
        $SQLInstanceName = "MSSQLSERVER"
        $SQLUser         = 'vagrant'
        $SQLPassword     = $SQLUser

        $DirectoryPermissions = @(
            @{
                User = "IIS AppPool\$WebsiteName"
                Path = $WebsitePath
            }
        )
        $Features =
        @(
            'NET-Framework-Core'
            'NET-Framework-Features'
            'NET-Framework-45-Core'
            'NET-Framework-45-Features'
            'Web-Mgmt-Tools'
        )

        ForEach ( $Feature in $Features )
        {
            WindowsFeature $Feature
            {
                Ensure = 'Present'
                Name   = $Feature
            }
        }
        WindowsFeature "IIS_All"
        {
            Ensure = 'Present'
            Name   = 'Web-WebServer'
            IncludeAllSubFeature = $True
        }
        Script InstallUrlRewrite
        {
            DependsOn = '[WindowsFeature]IIS_All'
            GetScript = 
            {
                @{ Result = 'UrlRewrite' }
            }
            TestScript = 
            {
                # Return True if UrlRewrite is present
                Test-Path -Path ( Join-Path $Env:SystemRoot 'System32\inetsrv\rewrite.dll' )
            }
            SetScript = 
            {
                # Install UrlRewrite
                Start-Process "C:\vagrant\rewrite_amd64.msi" -ArgumentList ( '/quiet', '/norestart' ) -Wait

            }
        }
        xWebAppPool AppPool
        {
            DependsOn = '[WindowsFeature]IIS_All'
            Ensure    = 'Present'
            Name      = $WebsiteName
        }
        xWebsite DefaultWebSite
        {
            DependsOn = '[WindowsFeature]IIS_All'
            Ensure    = 'Absent'
            Name      = 'Default Web Site'
        }
        xPfxImport Certificate
        {
            Ensure     = 'Present'
            Thumbprint = $WebsiteCertThumbprint
            Path       = $WebsiteCertPath
            Credential = $WebsiteCertCredential
            Location   = 'LocalMachine'
            Store      = 'WebHosting'
        }
        File WebsiteDirectory
        {
            DestinationPath = $WebsitePath
            Ensure          = 'Present'
            Type            = 'Directory'
        }
        Archive WebsiteFiles
        {
            DependsOn   = '[WindowsFeature]IIS_All',
                          '[File]WebsiteDirectory'
            Ensure      = 'Present'
            Path        = $WebsiteFilesZipPath
            Destination = $WebsitePath
            #Validate    = $True
            #Force       = $True
        }
        ForEach ( $Permission in $DirectoryPermissions )
        {
            cNtfsPermissionEntry "Permission.$( $Permission.User ):$( $Permission.Path )"
            {
                DependsOn                = '[Archive]WebsiteFiles',
                                           '[xWebAppPool]AppPool'
                Ensure                   = 'Present'
                Path                     = $Permission.Path
                Principal                = $Permission.User
                AccessControlInformation = @(
                    cNtfsAccessControlInformation
                    {
                        AccessControlType  = 'Allow'
                        FileSystemRights   = 'Modify'
                        Inheritance        = 'ThisFolderSubfoldersAndFiles'
                        NoPropagateInherit = $False
                    }
                )
            }

            # Enforce NTFS permission inheritance
            cNtfsPermissionsInheritance "PermissionInheritance.$( $Permission.User ):$( $Permission.Path )"
            {
                DependsOn = '[Archive]WebsiteFiles',
                            '[xWebAppPool]AppPool'
                Path      = $Permission.Path
                Enabled   = $True
            }
        }
        xWebSite IISSite
        {
            DependsOn       = '[Archive]WebsiteFiles',
                              '[xWebAppPool]AppPool',
                              '[xPfxImport]Certificate',
                              '[Script]InstallUrlRewrite'
            Name            = $WebsiteName
            Ensure          = 'Present'
            State           = 'Started'
            PhysicalPath    = $WebsitePath
            ApplicationPool = $WebsiteName
            BindingInfo     = @(
                MSFT_xWebBindingInformation
                {
                        Protocol  = 'HTTP'
                        Port      = 80
                        HostName  = $WebsiteName
                        IPAddress = '*'
                }
                MSFT_xWebBindingInformation
                {
                        Protocol              = 'HTTPS'
                        Port                  = 443
                        CertificateStoreName  = 'WebHosting'
                        CertificateThumbprint = $WebsiteCertThumbprint
                        HostName              = $WebsiteName
                        IPAddress             = '*'
                        SSLFlags              = '0'
                }
                MSFT_xWebBindingInformation
                {
                        Protocol  = 'HTTP'
                        Port      = 80
                        HostName  = "www.$WebsiteName"
                        IPAddress = '*'
                }
                MSFT_xWebBindingInformation
                {
                        Protocol              = 'HTTPS'
                        Port                  = 443
                        CertificateStoreName  = 'WebHosting'
                        CertificateThumbprint = $WebsiteCertThumbprint
                        HostName              = "www.$WebsiteName"
                        IPAddress             = '*'
                        SSLFlags              = '0'
                }
            )
        }
        xSQLServerAlias SqlAlias
        {
            Ensure               = 'Present'
            Name                 = 'SQLEXPRESS'
            ServerName           = 'localhost'
        }
        xSQLServerLogin SQLUser
        {
            Ensure          = "Present"
            Name            = $SQLUser
            LoginCredential = [PSCredential]::new( $SQLUser, ( $SQLPassword | ConvertTo-SecureString -AsPlainText -Force ) )
            LoginType       = "SQLLogin"
            SQLServer       = $env:COMPUTERNAME
            SQLInstanceName = $SQLInstanceName
            LoginMustChangePassword        = $False
            LoginPasswordExpirationEnabled = $False
            LoginPasswordPolicyEnforced    = $False
        }
        Script DBRestore
        {
            GetScript  = { @{ Result = "RestoreDatabase" } }
            TestScript =
            {
                # Always return false since this is just a PoC
                $False
            }
            SetScript  =
            {
                $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("domain", "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\domain.mdf")
                $RelocateLog  = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("domain_log", "C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\domain_log.ldf")

                $RestoreDBParams = @{
                    ServerInstance  = ".\"
                    Database        = "domain"
                    BackupFile      = $using:SQLDBBackupPath
                    RelocateFile    = @( $RelocateData, $RelocateLog )
                    ReplaceDatabase = $True
                    Verbose         = $True
                }

                Restore-SqlDatabase @RestoreDBParams
            }
        }
        xSQLServerDatabaseRole DBOwner
        {
            DependsOn            = "[Script]DBRestore"
            Ensure               = 'Present'
            SQLServer            = $env:COMPUTERNAME
            SQLInstanceName      = $SQLInstanceName
            Name                 = "vagrant"
            Role                 = 'db_owner'
            Database             = $SQLDBName
        }
        Script ConnectionStrings
        {
            GetScript  = { @{ Result = "Absent" } }
            TestScript =
            {
                # Always return false since this is just a PoC
                $False
            }
            SetScript  =
            {
                $FilePath = 'C:\inetpub\domain.tld\web.config'
                $ConnectionString = "Data Source=localhost;Initial Catalog=domain;User ID=$using:SQLUser;Password=$using:SQLPassword"
                [xml] $Xml = Get-Content -Path $FilePath
                ( $Xml.configuration.connectionStrings.add | Where { $_.name -eq "SiteSqlServer" } ).connectionString = $ConnectionString
                ( $Xml.configuration.appSettings.add | Where { $_.key -eq "SiteSqlServer" } ).value = $ConnectionString
                $Xml.Save( $FilePath )
            }
        }
        Script HostFileEntry
        {
            GetScript  = { @{ Result = "HostFileEntry" } }
            TestScript =
            {
                $Hosts = Get-Content "$( $env:windir )\system32\Drivers\etc\hosts"
                If ( $Hosts -match 'domain.tld www.domain.tld' ) 
                { $True }
                Else
                { $False }
            }
            SetScript  =
            { 
                Add-Content -Encoding UTF8  "$( $env:windir )\system32\Drivers\etc\hosts" "127.0.0.1 domain.tld www.domain.tld"
            }
        }
        File StartupWebsiteShortcut
        {
            DestinationPath = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\StartUp\$WebsiteName.url"
            Contents        = "[{000214A0-0000-0000-C000-000000000046}]`r`nProp3=19,11`r`n[InternetShortcut]`r`nIDList=`r`nURL=https://$WebsiteName"
        }
    }
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $True
        }
    )
}

# Unzip website files before DSC runs; this will speed up the process considerably
If ( ( Test-Path "c:\inetpub\domain.tld" ) -eq $False )
{
    Expand-Archive -Path "C:\vagrant\domain.tld.zip" -DestinationPath "c:\inetpub\domain.tld" -ErrorAction SilentlyContinue
}

$OutputPath = $env:TEMP
New-Item -Path $OutputPath -ItemType Directory -ErrorAction SilentlyContinue

# Push LCM settings
MetaConfiguration -OutputPath $OutputPath
Set-DSCLocalConfigurationManager -Path $OutputPath -Verbose

# Push DSC configuration
DscConfiguration -ConfigurationData $ConfigurationData -OutputPath $OutputPath
Start-DscConfiguration -ComputerName localhost -Path $OutputPath -Wait -Force -Verbose
