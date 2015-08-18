Picasso
=======
Picasso is a PowerShell provisioning script which using a single linear JSON file to determine what commands to execute.

Picasso is named so, as you take a just built empty server/computer and 'paint' it like a canvas using Picasso. The JSON file you pass in is called a 'palette' and this contains a 'paint' object which is an array of 'colours'.

Picasso currently is able to install/upgrade/uninstall software; clone repositories using Git/SVN; Build projects/solutions using MSBuild, and also run commands via the Command Prompt.

In order for Picasso to install/upgrade/uninstall software it requires a Chocolatey installation. But fear not, for if Picasso detects that Chocolatey is not installed, it will install it for you.

Examples
========
Running Picasso
---------------
```bash
.\Picasso.ps1 example.json
.\Picasso.ps1 -help
```

Install Git
-----------
This example palette will install Git onto the computer that Picasso is run:
```json
{
	"palette": {
		"paint": [
			{
				"type": "software",
				"name": "git",
				"ensure": "installed",
				"version": "latest"
			}
		]
	}
}
```
The above palette will ensure that Git is installed, and is installed up to the latest version (that is available to Chocolatey). If you wish to install a specific verion of Git, then you would supply the version such as "version": "1.8.3".

If the version key is not supplied, the the install will default to the latest version. If you try to install software that is already installed, then Picasso will upgrade the software to what ever version you supply. If the version is less than the one installed then nothing will happen; so first you'll have to uninstall then install.

Uninstall Git
-------------
This example palette will uninstall Git
```json
{
	"palette": {
		"paint": [
			{
				"type": "software",
				"name": "git",
				"ensure": "uninstalled"
			}
		]
	}
}
```
Here you'll notice that the version key is not required, as you're uninstalling software.
