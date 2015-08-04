<#
.SYNOPSIS
    PowerShell script to batch-change privacy settings in Windows 10
.DESCRIPTION
    With so many different privacy settings in Windows 10, it makes sense to have a script to change them.
.PARAMETER Strong
    Makes changes to allow for the highest privacy
.PARAMETER Default
    Reverts to Windows defaults 
.PARAMETER Balanced
    Turns off certain things but not everything.

.EXAMPLE       
    Set-Privacy -Balanced
    Runs the script to the balanced privacy settings    
.NOTES
    Should work with PowerShell 5 on Windows 10
    Author:  Peter Hahndorf
    Created: August 4th, 2015 
    
.LINK
    https://github.com/hahndorf/Set-Privacy   
#>

param(
  [parameter(Mandatory=$true,ParameterSetName = "Strong")]
  [switch]$Strong,
  [parameter(Mandatory=$true,ParameterSetName = "Default")]
  [switch]$Default,
  [parameter(Mandatory=$true,ParameterSetName = "Balanced")]
  [switch]$Balanced
)


Begin
{

Function Test-RegistryValue([String]$Path,[String]$Name){

  if (!(Test-Path $Path)) { return $false }
   
  $Key = Get-Item -LiteralPath $Path
  if ($Key.GetValue($Name, $null) -ne $null) {
      return $true
  } else {
      return $false
  }
}

Function Add-RegistryDWord([String]$Path,[String]$Name,[int32]$value){

    If (Test-RegistryValue $Path $Name)
    {
        Set-ItemProperty -Path $Path -Name $Name –Value $value
    }
    else
    {
        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $value 
    }


    Write-Verbose "$Path\$Name - $value"
}

Function Add-RegistryString([String]$Path,[String]$Name,[string]$value){

    If (Test-RegistryValue $Path $Name)
    {
        Set-ItemProperty -Path $Path -Name $Name –Value $value
    }
    else
    {
        New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $value 
    }


    Write-Verbose "$Path\$Name - $value"
}

# Turn on SmartScreen Filter
Function EnableWebContentEvaluation([int]$value)
{
    Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name EnableWebContentEvaluation -Value $value
}

# Send Microsoft info about how to write to help us improve typing and writing in the future
Function TIPC([int]$value)
{
    Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name Enabled -Value $value
}

# Let apps use my advertising ID for experience across apps
Function AdvertisingInfo([int]$value)
{
    Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name Enabled -Value $value
}

# Let websites provice locally relevant content by accessing my language list
Function HttpAcceptLanguageOptOut([int]$value)
{
    Add-RegistryDWord -Path "HKCU:\Control Panel\International\User Profile" -Name HttpAcceptLanguageOptOut -Value $value
}

Function DeviceAccess([string]$guid,[string]$value)
{
    Add-RegistryString -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{$guid}" -Name Value -Value $value
}

Function SpeachInkingTyping([string]$value)
{

# needs work, does about 64 registry changes

}

Function Report()
{
    Write-Host "Privacy settings changed"
    Exit 0
}

Function Location([string]$value)
{
    DeviceAccess -guid "BFA794E4-F964-4FDB-90F6-51056BFE4B44" -value $value
}

Function Camera([string]$value)
{
    DeviceAccess -guid "E5323777-F976-4f5b-9B55-B94699C46E44" -value $value
}

Function Microphone([string]$value)
{
    DeviceAccess -guid "2EEF81BE-33FA-4800-9670-1CD474972C3F" -value $value
}

}
Process
{



Function AccountInfo([string]$value)
{
    DeviceAccess -guid "C1D23ACC-752B-43E5-8448-8D0E519CD6D6" -value $value
}


}
End
{

    if ($Strong)
    {
        EnableWebContentEvaluation -value 0
        TIPC -value  0
        AdvertisingInfo  -value 0    
        HttpAcceptLanguageOptOut  -value 1
        Location  -value "Deny"
        Camera  -value "Deny"
        Microphone  -value "Deny"
        SpeachInkingTyping -value "Deny"
        AccountInfo -value "Deny"
        Report        
    }

    if ($Default)
    {
        EnableWebContentEvaluation  -value 1
        TIPC  -value 1
        AdvertisingInfo  -value 1    
        HttpAcceptLanguageOptOut  -value 0
        Location  -value "Allow" 
        Camera  -value "Allow"  
        Microphone  -value "Allow"    
        SpeachInkingTyping -value "Allow" 
        AccountInfo -value "Allow"
        Report
    }

}
