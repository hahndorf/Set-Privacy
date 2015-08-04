# Set-Privacy
PowerShell script to batch-change privacy settings in Windows 10

## Description

With so many different privacy settings in Windows 10, it makes sense to have a script to change them.

## Requirements

- Windows 10

## Installation and Usage

###Getting the script

There are several ways to get the script file to your computer, download the zip, clone the repository, save the content manually into a file. 
You can also get it with PowerShell:

Open a PowerShell window, first cd into a directory of your choice to store the script in, e.g.:

	cd ~\Downloads

then download the script by running the following:

	(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/hahndorf/Set-Privacy/master/Set-Privacy.ps1') | out-file .\Set-Privacy.ps1 -force 

After downloading a PowerShell script from the Internet, you should always review it to make sure it doesn't do anything bad.

###Running the script

Assuming you are still in the location you downloaded the script to, find out more about the parameters you can use for the script:

    help .\Set-Privacy.ps1 -full

and finally run it with one of the required parameters:

    .\Set-Privacy.ps1 -Strong

###Problems running the script

You may get one of the following messages when trying to run a script:

**Execution Policy**

    ...Set-Privacy.ps1 cannot be loaded because running scripts is disabled on this system...

PowerShell doesn't allow the execution of unsigned scripts, to
allow the execution of local unsigned scripts for this session run:

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

To change the execution policy permanently, run:

	Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force