# Set-Privacy.ps1
PowerShell script to batch-change privacy settings in Windows 10

## Description

With so many different privacy settings in Windows 10, it makes sense to have a script to change them.

## Requirements

- Windows 10

##Getting the script

There are several ways to get the script file to your computer, download the zip, clone the repository, save the content manually into a file. 
You can also get it with PowerShell:

Open a PowerShell window, first cd into a directory of your choice to store the script in, e.g.:

	cd ~\Downloads

then download the script by running the following:

	(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/hahndorf/Set-Privacy/master/Set-Privacy.ps1') | out-file .\Set-Privacy.ps1 -force 

After downloading a PowerShell script from the Internet, you should always review it to make sure it doesn't do anything bad.

##Running the script

Assuming you are still in the location you downloaded the script to, run it with one of the required parameters:

    .\Set-Privacy.ps1 -Strong

this sets the privacy settings for the current user to **Strong**, you also have the choice of **Default** (same as the Windows Express Setup settings) and **Balanced** (somewhere in the middle)

There are some settings for computer rather than individual users, to change those run with the -admin switch

    .\Set-Privacy.ps1 -Strong -admin

###Getting more help

To find out more about the parameters you can use for the script:

    help .\Set-Privacy.ps1 -full

##Problems running the script

You may get one of the following messages when trying to run a script:

**Execution Policy**

    ...Set-Privacy.ps1 cannot be loaded because running scripts is disabled on this system...

PowerShell doesn't allow the execution of unsigned scripts, to
allow the execution of local unsigned scripts for this session run:

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force

To change the execution policy permanently, run:

	Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force


##Changes in the Privacy section (user mode)

Changes are made on all tabs except `Diagnostic and usage data on the Feedback and diagnostics tab` and the `Background Apps` tab.

**-Strong** turns off as many settings as possible

**-Balanced** keeps: General-SmartScreen and General-LanguageList on

**-Default** turns on everything

##Changes in -admin mode

###Automatic Updates

Choose How Updates Are Delivered:

**-Strong** turns off sharing

**-Balanced** enables sharing on the local network

**-Default** enabled sharing with the internet

###Wi-Fi Sense

**-Strong and -Balanced** turn off something, but as I don't have Wi-Fi, I couldn't test this.

**-Default** turns it back on.

###Windows Defender SpyNet

**-Strong** turns off `Cloud-based protection` and `Sample submission`

**-Balanced and -Default** allow both.

###Diagnostic and usage data 

This is on the Privacy - Feedback and diagnostics tab

**-Strong and -Balanced** set this to `Basic`

**-Default** sets this to `Full (Recommended)`