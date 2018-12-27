Import-Module "$env:USERPROFILE\vagrant\Functions.psm1"
Restore-VagrantEnvironment

Write-Host "Connecting to virtual machine (RDP)"
Connect-Mstsc -User 'dev\administrator' -Password 'vagrant' -ComputerName "localhost:33389"
Write-Host -ForegroundColor Green "Provisioning complete!"
