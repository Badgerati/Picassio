# Picassio

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/Badgerati/Picassio/master/LICENSE.txt)

Picassio is a PowerShell v3.0+ automated provisioning/deployment tool, which uses a single JSON file to determine what commands to execute.

Picassio is named so, as you take a just built empty server/computer and 'paint' it like a canvas using Picassio. The JSON file you pass in is called a 'palette' and this contains a 'paint' (with optional 'erase') object which is an array of 'colours'.

All of Picassio's features (colours) are modularised, allowing for people to have the ability to create extension modules - explained at the end of this document.

# Installing
Picassio can be installed via Chocolatey:

```bash
choco install picassio
```

# Features
The following are all supported by Picassio:

* Install/upgrade/uninstall software/packages via Chocolatey, NPM, Bower or NuGet
* Clone/checkout repositories from Git/SVN
* Build projects/solutions using MSBuild
* Run specified commands using either Command Prompt or PowerShell
* Install/uninstall and stop/start Windows services
* Copy files/folders with inclusions/exclusions
* Call Vagrant
* Add/remove entries from the hosts file
* Add/remove website on IIS
* Run node.js applications
* Run tests via NUnit
* Install/uninstall Windows (optional) features such as Web-Server for IIS
* Ability to setup certificates in MMC
* Run cake build scripts
* Run SQL Server scripts or create/restore backups
* Can send emails
* Ability to publish/generate scripts for SSDT
* Support for Network Load Balancer
* Extension modules can be written for third-parties

# Dependencies
Picassio doesn't depend on any external software to run however, when required it will automatically install the following for you:

* Chocolatey
* git
* svn
* Vagrant
* node.js / npm
* cake
* NuGet
* bower

The above will only be installed when Picassio needs to use them. For example, using a Chocolatey type colour to install node.js will automatically install Chocolatey as well, or cloning a Git branch will auto-install Git if needed.

To view the source code, you can see the ps1 scripts via:

* PowerShell ISE
* Your favourite text editor
* Visual Studio (you will need the "PowerShell Tools" Visual Studio extension)

# Examples
To chain them together, just append more colour objects within the paint array. This way you can clone a branch from Git which is a simple WCF Service, build it and then install the service and start it.

As a side note, each colour can have an optional "description" key-value. This value will get written to the console for informational purposes only, and to help you find specific sections in the log outputted.

Note: You can see more examples in the `examples.palette` file bundled with the source code, or view each psm1 module for an example of how to use each one in the header.

## Running Picassio
```bash
picassio -palette example.palette -validate
picassio -palette example.palette -paint
picassio -version
picassio -help
```

Calling just `picassio -paint` in a directory will look for a default 'picassio.palette' file.

## Passing Credentials
Picassio does have support for username/password credentials should you require them. There are two ways to set these credentials:

* Specify the `-username` and `-password` arguments from the CLI
* Add a colour of singular `{ "type": "credentials" }` somewhere in your paint/erase palette sections. When Picassio gets to this type, assuming you haven't already set the credentials, then the user is prompted to enter them

The credentials are passed to every `Start-Module`, `Test-Module`, `Start-Extension` and `Test-Extension` call, and does have the possibility of being null.

## Palette Settings
A palette has two sections: a paint and an erase section. The paint section is designed to deploy and provision the machine, where as the erase section should roll the machine back to a state before it was painted.

When painting the machine it is possible for it to fail, and then you're left in a malformed state. Or what if you wish to roll everything back, and then paint the machine.

Well, Picassio has the following three settings that can be supplied at the top of a palette:

* rollbackOnFail: Runs the opposite section to the one that was just attempted, if the current one fails to run successfully.
* eraseBeforePaint: Runs the erase section first, before painting the current machine.
* eraseAfterPaint: Mostly for testing purposes, but will erase the machine after it has been painted.

```json
{
    "rollbackOnFail": true,
    "eraseBeforePaint": false,
    "eraseAfterPaint": false,
    "paint": [
        "..."
    ],
    "erase": [
        "..."
    ]
}
```

If none of the settings are supplied, then they are all defaulted to false.

## Installing a Service
Something else Picassio can do it install/uninstall and stop/start Windows services. If you are installing a service then the absolute path to the installer in required however, if you are just uninstalling one then the path can be omitted.

The following palette will install and start a service.
```json
{
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
```

The following palette will uninstall a service.
```json
{
    "paint": [
        {
            "type": "service",
            "name": "Test Service",
            "ensure": "uninstalled"
        }
    ]
}
```

If you are ensuring a service is installed and started, and it already is then the service will be restarted.

## Add/remove a website in IIS
Picassio can add/remove, start/stop websites and application pools in IIS. You can also set-up binding for http/https IP/port setting.

When a website is created, the default "*:80:" endpoint is removed, if this is required just specify the binding within the bindings array.

Picassio will also add IIS and application pool users to the website path in IIS. This is so the ApplicationPoolIdentity and IIS users have permissions to see the website directory.

The following palette will setup an entry into the hosts file, and also create a website/app pool in IIS. The website will be accessible from 127.0.0.2 or test.site.com.
```json
{
    "paint": [
        {
            "type": "hosts",
            "ensure": "added",
            "ip": "127.0.0.2",
            "hostname": "test.site.com"
        },
        {
            "type": "iis",
            "ensure": "added",
            "state": "started",
            "siteName": "Test Website",
            "appPoolName": "Test Website",
            "path": "C:\\Website\\TestWebsite",
            "bindings": [
                {
                    "ip": "127.0.0.2",
                    "port": "80",
                    "protocol": "http"
                }
            ]
        }
    ]
}
```

If you use a binding of 'https' you'll also need to pass a "certificate" key-value in the bindings. So if above we used https, a possible certificate could be "*.site.com".

## Add/remove website bindings in IIS
If you already have a website setup in IIS, then Picassio can add/remove binding to an already existing website.

The following palette will add an http binding to a website. This is rather similar to the binding array for a website:
```json
{
    "paint": [
        {
            "type": "iis-binding",
            "ensure": "added",
            "siteName": "Test Website",
            "ip": "127.0.0.2",
            "port": "80",
            "protocol": "http"
        }
    ]
}
```

Again like above, if you use a binding of 'https' you'll also need to pass a "certificate" key-value in the bindings. So if above we used https, a possible certificate could be "*.site.com".
