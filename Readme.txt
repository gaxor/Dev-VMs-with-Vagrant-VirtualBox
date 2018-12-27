DESCRIPTION:
	These scripts are a proof of concept that uses VirtualBox, Vagrant, and Desired State Configuration to standardize local devleopment server environments.
	Note:
    	This vagrant configuration uses a template OS (box) from Vagrant Cloud. Box: w16s-sql17d User: gusztavvargadr
		This is for three reasons:
			1. Microsoft does not allow programmatic downloading of Windows ISOs, so this gets us the OS
			2. This box quickly supplies recent updates
			3. This box quickly supplies SQL Server
		Ideally we would create our own box with HashiCorp's "Packer" application to have more in-house security and standardization.

PREREQUISITES (IMPORTANT!):
	1: The following files must exist in "C:/Users/USER_NAME/vagrant/" (you may need to create this directory):
		- All provided scripts (unzipped)
		- domain.tld.zip - Website files (this zip will be directly extracted to the website directory)
		- domain-db.bak - Website database backup file
		- domain.tld.pfx - SSL certificate
	2: "CertPassword.txt" must include the password required to open the PFX file

RUNNING THE SCRIPT:
	Run "Install.bat" - You will automatically be connected to the VM by RDP when finished (you will need to click "OK" to bypass "unknown publisher" warning).

RE-ZERO VM(S):
	Run "Re-Zero VMs.bat"

NOTES:
	This is a rough proof of concept; some things present should be done differently in production.
	Please be patient, the first run will take some time to complete depending on your system specs (~1hr in my test lab)
	Everything in these scripts is written to be idempotent.
	For added performance gains, further utilizing VirtualBox's linked cloning can be used instead of waiting for Vagrant to re-provision VMs from the base Box image.
