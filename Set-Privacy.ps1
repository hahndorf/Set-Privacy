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
.PARAMETER Admin
    Updates machine settings rather than user settings, still requires Strong,Balanced or Default switches. Needs to run as elevated admin.

.EXAMPLE       
    Set-Privacy -Balanced
    Runs the script to set the balanced privacy settings  
.EXAMPLE       
    Set-Privacy -Strong -Admin
    Runs the script to set the strong settings on the machine level. This covers Windows update and WiFi sense.      
.NOTES
    Should work on Windows 10 and higher
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
  [switch]$Balanced,
  [parameter(ParameterSetName = "Balanced")]
  [parameter(ParameterSetName = "Default")]
  [parameter(ParameterSetName = "Strong")]
  [switch]$Admin
)


Begin
{

#requires -version 3

# check https://fix10.isleaked.com/ for changing things manually.

    # ----------- Helper Functions -----------

    Function Test-RegistryValue([String]$Path,[String]$Name){

      if (!(Test-Path $Path)) { return $false }
   
      $Key = Get-Item -LiteralPath $Path
      if ($Key.GetValue($Name, $null) -ne $null) {
          return $true
      } else {
          return $false
      }
    }

    Function Get-RegistryValue([String]$Path,[String]$Name){

      if (!(Test-Path $Path)) { return $null }
   
      $Key = Get-Item -LiteralPath $Path
      if ($Key.GetValue($Name, $null) -ne $null) {
          return $Key.GetValue($Name, $null)
      } else {
          return $null
      }
    }

    Function Remove-RegistryValue([String]$Path,[String]$Name){

        $old = Get-RegistryValue -Path $Path -Name $Name
        if ($old -ne $null)
        {
            Remove-ItemProperty -Path "$Path" -Name "$Name"
            Write-Host "$Path\$Name removed" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "$Path\$Name does not exist" -ForegroundColor Green
        }

    }

    Function Create-RegistryKey([string]$path)
    {        
        # creates a parent key and if needed grandparent key as well
        # for this script that is good enough

        If (!(Test-Path $Path))
        {
            $parent = [System.IO.Path]::GetDirectoryName($path)
            If (!(Test-Path $parent))
            {
                New-item -Path $parent | Out-Null
            }

            New-item -Path $Path | Out-Null
        }
    }

    Function Add-RegistryDWord([String]$Path,[String]$Name,[int32]$value){

        $old = Get-RegistryValue -Path $Path -Name $Name
        if ($old -ne $null)
        {
            if ([int32]$old -eq $value)
            {
                Write-Host "$Path\$Name already set to $value" -ForegroundColor Green
                return
            }
        }


        If (Test-RegistryValue $Path $Name)
        {
            Set-ItemProperty -Path $Path -Name $Name –Value $value
        }
        else
        {
            Create-RegistryKey -path $path
            New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $value | Out-Null
        }


        Write-Host "$Path\$Name changed to $value" -ForegroundColor Yellow
    }

    Function Add-RegistryString([String]$Path,[String]$Name,[string]$value){


        $old = Get-RegistryValue -Path $Path -Name $Name
        if ($old -ne $null)
        {
            if ([string]$old -eq $value)
            {
                Write-Host "$Path\$Name already set to $value" -ForegroundColor Green
                return
            }
        }

        If (Test-RegistryValue $Path $Name)
        {
            Set-ItemProperty -Path $Path -Name $Name –Value $value
        }
        else
        {
            Create-RegistryKey -path $path
            New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $value |Out-Null
        }

        Write-Host "$Path\$Name changed to $value" -ForegroundColor Yellow
    }

    Function Get-AppSID(){

        Get-ChildItem "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Mappings" | foreach {

        $key = $_.Name -replace "HKEY_CURRENT_USER","HKCU:"

        $val = Get-RegistryValue -Path $key -Name "Moniker" 

        if ($val -ne $null)
        {
            if ($val -match "^microsoft\.people_")
            {
                $script:sidPeople = $_.PsChildName
            }
            if ($val -match "^microsoft\.windows\.cortana")
            {
                $script:sidCortana = $_.PsChildName
            }
        }     
    }              
    }

    Function DeviceAccess([string]$guid,[string]$value){
        Add-RegistryString -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{$guid}" -Name Value -Value $value
    }

    Function DeviceAccessName([string]$name,[string]$value){
        Add-RegistryString -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\$name" -Name Value -Value $value
    }

    Function DeviceAccessApp([string]$app,[string]$guid,[string]$value){

        Add-RegistryString -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\$app\{$guid}" -Name Value -Value $value
    }

    Function Report(){

        Write-Host "Privacy settings changed"
        Exit 0
    }

    # ----------- User Privacy Functions -----------
    
    Function EnableWebContentEvaluation([int]$value){
        
        # Turn on SmartScreen Filter
        Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name EnableWebContentEvaluation -Value $value
    }

    Function TIPC([int]$value){

        # Send Microsoft info about how to write to help us improve typing and writing in the future
        Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name Enabled -Value $value
    }

    Function AdvertisingInfo([int]$value){

       # Let apps use my advertising ID for experience across apps
        Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name Enabled -Value $value
    }

    Function HttpAcceptLanguageOptOut([int]$value){

        # Let websites provice locally relevant content by accessing my language list
        Add-RegistryDWord -Path "HKCU:\Control Panel\International\User Profile" -Name HttpAcceptLanguageOptOut -Value $value
    }

    Function SpeachInkingTyping([string]$value){

    # needs work, does about 64 registry changes

    }

    Function Location([string]$value){

        DeviceAccess -guid "BFA794E4-F964-4FDB-90F6-51056BFE4B44" -value $value
    }

    Function Camera([string]$value){

        DeviceAccess -guid "E5323777-F976-4f5b-9B55-B94699C46E44" -value $value
    }

    Function Microphone([string]$value){
        DeviceAccess -guid "2EEF81BE-33FA-4800-9670-1CD474972C3F" -value $value
    }

    Function Contacts([string]$value){

        $exclude = $script:sidCortana + "|" + $script:sidPeople

        Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess | ForEach-Object{

            $app = $_.PSChildName

            if ($app -ne "Global")
            {
                $key = $_.Name -replace "HKEY_CURRENT_USER","HKCU:"

                $contactsGUID = "7D7E8402-7C54-4821-A34E-AEEFD62DED93"
           
                $key += "\{$contactsGUID}"

                if (Test-Path "$key")
                {
                    if ($app -notmatch $exclude)
                    {
                        DeviceAccessApp -app $app -guid $contactsGUID -value $value
                    }
                }
            }
        }
    }

    Function Calendar([string]$value){
        DeviceAccess -guid "D89823BA-7180-4B81-B50C-7E471E6121A3" -value $value
    }

    Function AccountInfo([string]$value){
        DeviceAccess -guid "C1D23ACC-752B-43E5-8448-8D0E519CD6D6" -value $value
    }

    Function Messaging([string]$value){

        DeviceAccess -guid "992AFA70-6F47-4148-B3E9-3003349C1548" -value $value
    }

    Function Radios([string]$value){

        DeviceAccess -guid "A8804298-2D5F-42E3-9531-9C8C39EB29CE" -value $value
    }

    Function LooselyCoupled([string]$value){

        DeviceAccessName -name "LooselyCoupled" -value $value
    }

    Function NumberOfSIUFInPeriod([int]$value){

        if ($value -lt 0)
        {
            # remove entry
            Remove-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name NumberOfSIUFInPeriod
        }
        else
        {
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name NumberOfSIUFInPeriod -Value $value
        }
    }

    # ----------- Machine Settings Functions -----------

    Function DODownloadMode([int]$value){

        # 0 = Off
        # 1 = PCs on my local network
        # 3 = PCs on my local network, and PCs on the Internet

        Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name DODownloadMode -Value $value        
    }

    Function WifiSense([int]$value){

         Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\features" -Name WiFiSenseCredShared -Value $value        
         Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\features" -Name WiFiSenseOpen -Value $value        
    }

    Function Telemetry ([bool]$enable){

        if ($enable)
        {
            Set-service -Name DiagTrack -Status Running -StartupType Automatic
            & sc.exe config dmwappushservice start= delayed-auto
            Set-service -Name dmwappushservice -Status Running
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollectiong" -Name AllowTelemetry -Value 1
        }
        else
        {
            Stop-Service -Name dmwappushservice -Force
            Stop-Service -Name DiagTrack -Force
            Set-service -Name DiagTrack -StartupType Disabled
            Set-service -Name dmwappushservice -StartupType Disabled  
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollectiong" -Name AllowTelemetry -Value 0                      
        }
    }
    
}
Process
{
    
    $myOS = Get-CimInstance -ClassName Win32_OperatingSystem -Namespace root/cimv2 -Verbose:$false

    if ([int]$myOS.BuildNumber -lt 10240)
    {   
        Write-Warning "Your OS version is not supported, Windows 10 or higher is required" 
        Exit 101
    }

    if ($Admin)
    {

        $UserCurrent = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $userIsAdmin = $false
        $UserCurrent.Groups | ForEach-Object { if($_.value -eq "S-1-5-32-544") {$userIsAdmin = $true} }

        if (!($userIsAdmin))
        {
            Write-Warning "When using -admin, please run this script as elevated administrator"
            Exit 102
        }

        if ($Strong)
        {
            DODownloadMode -value 0
            WifiSense -value 0
            Telemetry -enable $false
        }
        if ($Balanced)
        {
            DODownloadMode -value 1
            WifiSense -value 0
            Telemetry -enable $false
        }
        if ($Default)
        {
            DODownloadMode -value 3
            WifiSense -value 1
            Telemetry -enable $true
        }

        Report
    }

    Get-AppSID

    if ($Strong)
    {
        # turn off as much as we can

        EnableWebContentEvaluation -value 0
        TIPC -value  0
        AdvertisingInfo -value 0    
        HttpAcceptLanguageOptOut -value 1
        Location -value "Deny"
        Camera -value "Deny"
        Microphone -value "Deny"
        SpeachInkingTyping -value "Deny"
        AccountInfo -value "Deny"
        Contacts -value "Deny"
        Calendar -value "Deny"
        Messaging -value "Deny"
        Radios -value "Deny"
        LooselyCoupled -value "Deny"
        NumberOfSIUFInPeriod -value 0        
        Report        
    }

    if ($Balanced)
    {
        # still have to decide what to turn off

        EnableWebContentEvaluation -value 1
        TIPC -value  0
        AdvertisingInfo -value 0    
        HttpAcceptLanguageOptOut -value 1
        Location -value "Deny"
        Camera -value "Deny"
        Microphone -value "Deny"
        SpeachInkingTyping -value "Deny"
        AccountInfo -value "Deny"
        Contacts -value "Deny"
        Calendar -value "Deny"
        Messaging -value "Deny"
        Radios -value "Deny"
        LooselyCoupled -value "Deny"
        NumberOfSIUFInPeriod -value 0

        Report        
    }

    if ($Default)
    {
        EnableWebContentEvaluation -value 1
        TIPC -value 1
        AdvertisingInfo -value 1    
        HttpAcceptLanguageOptOut -value 0
        Location -value "Allow" 
        Camera -value "Allow"  
        Microphone -value "Allow"    
        SpeachInkingTyping -value "Allow" 
        AccountInfo -value "Allow"
        Contacts -value "Allow"
        Calendar -value "Allow"
        Messaging -value "Allow"
        Radios -value "Allow"
        LooselyCoupled -value "Allow"
        NumberOfSIUFInPeriod -value -1

        Report
    }

}
End
{


}
