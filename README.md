Picasso
=======
Picasso is a PowerShell v3.0+ provisioning/deployment script which uses a single linear JSON file to determine what commands to execute.

Picasso is named so, as you take a just built empty server/computer and 'paint' it like a canvas using Picasso. The JSON file you pass in is called a 'palette' and this contains a 'paint' object which is an array of 'colours'.


Features
========
The following are all supported by Picasso:

* Install/upgrade/uninstall software via Chocolatey
* Clone/checkout repositories from Git/SVN
* Build projects/solutions using MSBuild
* Run specified commands using either Command Prompt or PowerShell
* Install/uninstall and stop/start Windows services
* Copy files/folders with inclusions/exclusions
* Call Vagrant
* Add/remove entries from the hosts file


Dependencies
============
Picasso only depends on a few applications, and when required will automatically install them for you:

* Chocolatey
* git
* svn
* Vagrant

The above will only be installed when Picasso needs to use them. For example, using a software type colour to install node.js will automatically install Chocolatey as well, or cloning a Git branch will auto-install Git if needed.


To Do
=====
There are still quite a few things I wish to add to Picasso, the following is a short list:

* Bower and npm support
* Installing wesbites via IIS
* SSDT publishing


Examples
========
Picasso is typically best run by having the path to it within you environment's PATH. The following examples will all assume Picasso is within your PATH.

To chain them together, just append more colour objects within the paint array. This way you can clone a branch from Git which is a simple WCF Service, build it and then install the service and start it.

As a side note, each colour can have an optional "description" key-value. This value get written to the console for informational purposes only, and to help you find specific sections in the log outputted.


Running Picasso
---------------
```bash
picasso example.json
picasso -version
picasso -help
```


Installing Software
-------------------
This example palette will install Git onto the computer that Picasso is run:
```json
{
	"palette": {
		"paint": [
			{
				"type": "software",
				"names": [ "git" ],
				"ensure": "installed",
				"versions": [ "latest" ]
			}
		]
	}
}
```
The above palette will ensure that Git is installed, and is installed up to the latest version (that is available to Chocolatey). If you wish to install a specific version of Git, then you would supply the version such as "versions": [ "1.8.3" ].

If the version key is not supplied, then the install will default to the latest version. If you try to install software that is already installed, then Picasso will upgrade the software to what ever version you supply. If the version is less than the one installed then nothing will happen; so first you'll have to uninstall then re-install.

If you specify multiple names to install such as '"names": [ "git", "curl" ]', then you must either specify all possible versions. If you omit the versions key then all software will be installed to the latest version. Specifying one version means all software will attempt to be installed to that version.

If you instead wish to uninstall some software (so long as it was originally installed by Chocolately), then the following example palette will uninstall, say, Git
```json
{
	"palette": {
		"paint": [
			{
				"type": "software",
				"names": [ "git" ],
				"ensure": "uninstalled"
			}
		]
	}
}
```
Here you'll notice that the version key is not required, as you're uninstalling software.


Cloning a Branch from Git
-------------------------
Picasso has the ability to clone a branch from any Git server. Simply supply the remote path to your branch as well as the branch's name, along with a local path/name to which to clone, and Picasso will pull down the branch for you.
```json
{
	"palette": {
		"paint": [
			{
				"type": "git",
				"remote": "https://path/to/some/branch.git",
				"localpath": "C:\\path\\to\\place\\branch",
				"localname": "NewBranch",
				"branchname": "master"
			}
		]
	}
}
```
This will pull down our master branch, an rename the auto-created folder to be "NewBranch" at the specified local path. If Picasso sees that the local folder already exists, the current one is renamed with the current date appended.


Building a Project using MSBuild
--------------------------------
Picasso is able to build a .NET project/solution using MSBuild (so long as the computer has MSBuild available). One of the required keys for MSBuild is the path to where the MSBuild.exe can be found.
```json
{
	"palette": {
		"paint": [
			{
				"type": "msbuild",
				"path": "C:\\path\\to\\your\\msbuild.exe",
				"project": "C:\\path\\to\\your\\project.csproj",
				"arguments": "/p:Configuration=Debug"
			}
		]
	}
}
```


Running Specific Commands
-------------------------
For the things that Picasso doesn't do, such as renaming folders or if you wish to run an inhouse script, you can use the command type colour to run commands from the prompt. You have the option of either Command Prompt or PowerShell, and you can run any command you wish.
```json
{
	"palette": {
		"paint": [
			{
				"type": "command",
				"prompt": "cmd",
				"command": "echo Hello, world!"
			},
			{
				"type": "command",
				"prompt": "powershell",
				"command": "echo 'Hello, world again!'"
			}
		]
	}
}
```


Installing a Service
--------------------
Something else Picasso can do it install/uninstall and stop/start Windows services. If you are installing a service then the absolute path to the installer in required however, if you are just uninstalling one then the path can be omitted.

The following palette will install and start a service.
```json
{
	"palette": {
		"paint": [
			{
				"type": "service",
				"name": "Test Service",
				"path": "C:\\absolute\\path\\to\\your\\service.exe",
				"ensure": "installed",
				"state": "started"
			}
		]
	}
}
```

The following palette will uninstall a service.
```json
{
	"palette": {
		"paint": [
			{
				"type": "service",
				"name": "Test Service",
				"ensure": "uninstalled"
			}
		]
	}
}
```

If you are ensuring a service is installed and started, and it already is then the service will be restarted.



Copying Files/Directories
-------------------------
Picasso is able to copy files/folders from one location to another. This is useful for copying files from one system to another; for general maintenance of builds; or creating backups of files/folders. If you specify a path to copy to where all folders don't exist, Picasso will create them for you.

You can also specify files/folders to include/exclude using:

* excludeFiles
* excludeFolders
* includeFiles
* includeFolders

The following palette will copy a folder, and then backup a file within it:
```json
{
	"palette": {
		"paint": [
			{
				"type": "copy",
				"from": "C:\\path\\to\\some\\folder",
				"to": "C:\\path\\to\\some\\other\\folder"
			},
			{
				"type": "copy",
				"from": "C:\\path\\to\\some\\other\\folder\\test.txt",
				"to": "C:\\path\\to\\some\\other\\folder\\backups\\test.txt"
			}
		]
	}
}
```

The following palette will copy a folder, excluding html/js files; but including a src folder only:
```json
{
	"palette": {
		"paint": [
			{
				"type": "copy",
				"from": "C:\\path\\to\\some\\folder",
				"to": "C:\\path\\to\\some\\other\\folder",
				"excludeFiles": [ "*.html", "*.js" ],
				"includeFolders": [ "src" ]
			}
		]
	}
}
```


Calling Vagrant
---------------
Picasso now also supports the ability to call "vagrant up" or other commands such as

* halt
* destroy
* suspend
* share
* etc.

from with a Picasso palette. You will need to supply a path to where a Vagrantfile is located in order for the command to work.

The following palette with navigate to a folder, and call "vagrant up":
```json
{
	"palette": {
		"paint": [
			{
				"type": "vagrant",
				"path": "C:\\path\\to\\project",
				"command": "up"
			}
		]
	}
}
```


Updating the hosts File
-----------------------
Picasso will let you update the hosts file, by allowing you to add/remove entries. To add an entry you will need both the IP/Hostname however, to remove an entry on requires one or both.

When removing, if you supply only either the IP or Hostname, all lines with that IP or Hostname will be removed. If you specify both, then only lines that have both the IP/Hostname will be removed.

The following palette will add an entry to the hosts
```json
{
	"palette": {
		"paint": [
			{
				"type": "hosts",
				"ensure": "added",
				"ip": "127.0.0.3",
				"hostname": "test.local.com"
			}
		]
	}
}
```

The following will remove all entries with the passed IP
```json
{
	"palette": {
		"paint": [
			{
				"type": "hosts",
				"ensure": "removed",
				"ip": "127.0.0.3"
			}
		]
	}
}
```