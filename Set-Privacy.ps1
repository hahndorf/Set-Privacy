<#PSScriptInfo

.VERSION 1.0

.GUID bd3a1ade-420c-4ac6-8558-b4f8df963aff

.AUTHOR Peter Hahndorf

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI https://raw.githubusercontent.com/hahndorf/Set-Privacy/master/LICENSE

.PROJECTURI https://github.com/hahndorf/Set-Privacy

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

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
    If this switch is selected, no user settings are changed.
.PARAMETER Features
    A comma separated list of features to disable or enable. Use the Tab key to show all allowed values
.PARAMETER Disable
    Use with -Features to disable all those features
.PARAMETER Enable
   Use with -Features to enable all those features

.EXAMPLE       
    Set-Privacy -Balanced
    Runs the script to set the balanced privacy settings  
.EXAMPLE       
    Set-Privacy -Strong -Admin
    Runs the script to set the strong settings on the machine level. This covers Windows update and WiFi sense.   
.EXAMPLE       
    Set-Privacy -disable -Features WifiSense,ShareUpdates,Contacts 
    Disabled those three features to improve your privacy   
.NOTES
    Requires Windows 10 and higher
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
    [switch]$Admin,
    [parameter(Mandatory=$true,ParameterSetName = "Disable")]
    [switch]$Disable,
    [parameter(Mandatory=$true,ParameterSetName = "Enable")]
    [switch]$Enable,
    [parameter(Mandatory=$true,ParameterSetName = "Enable")]
    [parameter(Mandatory=$true,ParameterSetName = "Disable")]
    [ValidateSet("AdvertisingId","ImproveTyping","Location","Camera","Microphone","SpeachInkingTyping","AccountInfo","Contacts","Calendar","Messaging","Radios","OtherDevices","FeedbackFrequency","ShareUpdates","WifiSense","Telemetry","SpyNet","DoNotTrack","SearchSuggestions","PagePrediction","PhishingFilter")]
    [string[]]$Feature
)           

Begin
{

#requires -version 3

# check https://fix10.isleaked.com/ for changing things manually.

    # ----------- Helper Functions -----------

    Function Test-Admin()
    {
        if (!($userIsAdmin))
        {
            Write-Warning "When using -admin switch or specifying a machine setting, please run this script as elevated administrator"
            Exit 102
        }
    }

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

            $grandParent = [System.IO.Path]::GetDirectoryName($parent)
            If (!(Test-Path $grandParent))
            {
                New-item -Path $grandParent | Out-Null
            }

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
            Set-ItemProperty -Path $Path -Name $Name -Value $value
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
            Set-ItemProperty -Path $Path -Name $Name -Value $value
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
    
    Function SmartScreen([int]$value){
        
        # Turn on SmartScreen Filter
        Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost" -Name EnableWebContentEvaluation -Value $value
    }

    Function ImproveTyping([int]$value){

        # Send Microsoft info about how to write to help us improve typing and writing in the future
        Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Input\TIPC" -Name Enabled -Value $value
    }

    Function AdvertisingId([int]$value){

       # Let apps use my advertising ID for experience across apps
        Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name Enabled -Value $value
    }

    Function LanguageList([int]$value){

        # Let websites provice locally relevant content by accessing my language list
        Add-RegistryDWord -Path "HKCU:\Control Panel\International\User Profile" -Name HttpAcceptLanguageOptOut -Value $value
    }

    Function SpeachInkingTyping([bool]$enable){

        if ($enable)
        {
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name AcceptedPrivacyPolicy -Value 1
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name RestrictImplicitTextCollection -Value 0
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name RestrictImplicitInkCollection -Value 0
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name HarvestContacts -Value 1
        }
        else
        {
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" -Name AcceptedPrivacyPolicy -Value 0
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name RestrictImplicitTextCollection -Value 1
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name RestrictImplicitInkCollection -Value 1
            Add-RegistryDWord -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name HarvestContacts -Value 0    
        }
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

    Function OtherDevices([string]$value){

        DeviceAccessName -name "LooselyCoupled" -value $value
    }

    Function FeedbackFrequency([int]$value){

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

    # ----------- Edge Browser Privacy Functions -----------

    [string]$EdgeKey = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\microsoft.microsoftedge_8wekyb3d8bbwe\MicrosoftEdge"

    Function DoNotTrack([int]$value){

       # 1 adds the Do Not Track Header, 0 does not
        Add-RegistryDWord -Path "$EdgeKey\Main" -Name DoNotTrack -Value $value
    }

    Function SearchSuggestions([int]$value){
    
       # 0 disables search suggestions, 1 does not
        Add-RegistryDWord -Path "$EdgeKey\User\Default\SearchScopes" -Name ShowSearchSuggestionsGlobal -Value $value
    }

    Function PagePrediction([int]$value){
    
       # 0 disables PagePrediction, 1 enables them
        Add-RegistryDWord -Path "$EdgeKey\FlipAhead" -Name FPEnabled -Value $value
    }

    Function PhishingFilter([int]$value){
    
       # 0 disables PhishingFilter, 1 enables it
        Add-RegistryDWord -Path "$EdgeKey\PhishingFilter" -Name EnabledV9 -Value $value
    }


    # ----------- Machine Settings Functions -----------

    Function ShareUpdates([int]$value){

        Test-Admin

        # 0 = Off
        # 1 = PCs on my local network
        # 3 = PCs on my local network, and PCs on the Internet

        Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name DODownloadMode -Value $value        
    }

    Function WifiSense([int]$value){

        Test-Admin

        Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\features" -Name WiFiSenseCredShared -Value $value        
        Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\features" -Name WiFiSenseOpen -Value $value        
    }

    Function SpyNet([bool]$enable){

        # Access to these registry keys are not allowed for administrators
        # so this does not work until we change those,
        # we give admins full permissions and after updating the values change it back.

        Test-Admin

$definition = @"
using System;
using System.Runtime.InteropServices;
namespace Win32Api
{
    public class NtDll
    {
        [DllImport("ntdll.dll", EntryPoint="RtlAdjustPrivilege")]
        public static extern int RtlAdjustPrivilege(ulong Privilege, bool Enable, bool CurrentThread, ref bool Enabled);
    }
}
"@
                 
        if (-not ("Win32Api.NtDll" -as [type])) 
        {
            Add-Type -TypeDefinition $definition -PassThru | out-null
        }
        else
        {
             ("Win32Api.NtDll" -as [type]) | Out-Null
        }
       
        $bEnabled = $false
        # Enable SeTakeOwnershipPrivilege
        $res = [Win32Api.NtDll]::RtlAdjustPrivilege(9, $true, $false, [ref]$bEnabled)

        $adminGroupSID = "S-1-5-32-544"

        $adminGroupName = (get-wmiobject -class "win32_account" -namespace "root\cimv2" | where-object{$_.sidtype -eq 4 -and $_.Sid -eq "$adminGroupSID"}).Name 

        # we take ownership from SYSTEM and I tried to give it back but that failed. I don't think that's a problem.
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Windows Defender\Spynet", [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::takeownership)
        $acl = $key.GetAccessControl()
        $acl.SetOwner([System.Security.Principal.NTAccount]$adminGroupName)
        $key.SetAccessControl($acl)

        $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$adminGroupName","FullControl","Allow")
        $acl.SetAccessRule($rule)
        $key.SetAccessControl($acl)

        if ($enable)
        {
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet" -Name "SpyNetReporting" -Value 2
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 1 
        }
        else
        {
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet" -Name "SpyNetReporting" -Value 0    
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 0                   
        }      

        # remove FUll Access ACE again
        $acl.RemoveAccessRule($rule) | Out-Null
        $key.SetAccessControl($acl)
     
    }

    Function Telemetry ([bool]$enable){

        Test-Admin

        # http://winaero.com/blog/how-to-disable-telemetry-and-data-collection-in-windows-10/
        # this covers Diagnostic and usage data in 'Feedback and diagnostics'
        if ($enable)
        {
            Set-service -Name DiagTrack -Status Running -StartupType Automatic
            & sc.exe config dmwappushservice start= delayed-auto | Out-Null
            Set-service -Name dmwappushservice -Status Running
            # just setting the value to zero did not do the trick.
            Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry
        }
        else
        {
            Stop-Service -Name dmwappushservice -Force
            Stop-Service -Name DiagTrack -Force
            Set-service -Name DiagTrack -StartupType Disabled
            Set-service -Name dmwappushservice -StartupType Disabled  
            Add-RegistryDWord -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -Value 0                      
        }
    }

    # ----------- Grouping Functions -----------

    Function Set-StrictPrivacyFeature([bool]$enable)
    {
        #enabled for -default, disabled for -strong and -balanced

        $AllowDeny = "Deny"
        $OnOff = 0      
        $OffOn = 1  
        
        if ($enable)
        {
            $AllowDeny = "Allow"
            $OnOff = 1
            $OffOn = 0
        }

        # General
        AdvertisingId -value $OnOff
        ImproveTyping -value $OnOff          
        # Location
        Location -value $AllowDeny
        # Camera
        Camera -value $AllowDeny
        # Microphone
        Microphone -value $AllowDeny
        # Speach, Inking, Typing
        SpeachInkingTyping -enable $enable
        # Account Info
        AccountInfo -value $AllowDeny
        # Contacts
        Contacts -value $AllowDeny
        # Calendar
        Calendar -value $AllowDeny
        # Messaging
        Messaging -value $AllowDeny
        # Radios
        Radios -value $AllowDeny
        # Other devices
        OtherDevices -value $AllowDeny
        # Feedback & diagnostics         
        if ($enable)
        {
            FeedbackFrequency -value -1
        }
        else
        {
            FeedbackFrequency -value 0
        }

        # Edge

        DoNotTrack -value $OffOn
        SearchSuggestions -value $OnOff 
        PagePrediction -value $OnOff 
        PhishingFilter -value $OnOff 
        
    }

    Function Set-MiscPrivacyFeature([bool]$enable)
    {            
        #enabled for -default and -balanced disabled for -strong 

        if ($enable)
        {
            SmartScreen -value 1
            LanguageList -value 0
        }
        else
        {
            SmartScreen -value 0
            LanguageList -value 1
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

    $UserCurrent = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $userIsAdmin = $false
    $UserCurrent.Groups | ForEach-Object { if($_.value -eq "S-1-5-32-544") {$userIsAdmin = $true} }

    if ($Admin)
    {        
        if ($Strong)
        {
            ShareUpdates -value 0
            WifiSense -value 0
            Telemetry -enable $false
            SpyNet -enable $false
        }
        if ($Balanced)
        {
            # allow LAN sharing of updates
            ShareUpdates -value 1
            WifiSense -value 0
            Telemetry -enable $false
            # in balanced mode, we don't disable SpyNet
            SpyNet -enable $true
        }
        if ($Default)
        {
            ShareUpdates -value 3
            WifiSense -value 1
            Telemetry -enable $true
            SpyNet -enable $true
        }

        Report
    }

    # this gets internal IDs for certain Apps like Cortana which we need in some functions
    Get-AppSID

    if ($Strong)
    {
        # turn off as much as we can   
        Set-MiscPrivacyFeature -enable $false
        Set-StrictPrivacyFeature -enable $false        
        Report        
    }

    if ($Balanced)
    {
        Set-MiscPrivacyFeature -enable $true
        Set-StrictPrivacyFeature -enable $false
        
        Report        
    }

    if ($Default)
    {
        Set-MiscPrivacyFeature -enable $true
        Set-StrictPrivacyFeature -enable $true  
        Report
    }

    # handle specific features

    $AllowDeny = "Deny"
    $OnOff = 0
    $OffOn = 1   
    $DoEnable = $false  
        
    if ($Enable)
    {
        $AllowDeny = "Deny"
        $OnOff = 1
        $OffOn = 0
        $DoEnable = $true 
    }


    $Feature | ForEach-Object {

        switch ($_) 
            { 
                "AdvertisingId" {AdvertisingId -value $OnOff;break} 
                "ImproveTyping" {ImproveTyping -value $OnOff;break} 
                "Location" {Location -value $AllowDeny;break}
                "Camera" {Camera -value $AllowDeny;break} 
                "Microphone" {Microphone -value $AllowDeny;break} 
                "SpeachInkingTyping" {SpeachInkingTyping -enable $DoEnable;break} 
                "AccountInfo" {AccountInfo -value $AllowDeny;break} 
                "Contacts" {Contacts -value $AllowDeny;break} 
                "Calendar" {Calendar -value $AllowDeny;break} 
                "Messaging" {Messaging -value $AllowDeny;break} 
                "Radios" {Radios -value $AllowDeny;break} 
                "OtherDevices" {OtherDevices -value $AllowDeny;break} 
                "FeedbackFrequency" {
                        if ($Enable) {
                            FeedbackFrequency -value -1;
                        }
                        else
                        {
                            FeedbackFrequency -value 0;
                        }
                        break} 
                "ShareUpdates" {
                        if ($Enable) {
                            ShareUpdates -value 3;
                        }
                        else
                        {
                            ShareUpdates -value 0;
                        }
                        break}
                "WifiSense" {WifiSense -value $OnOff;break}                                                                    
                "Telemetry" {Telemetry -enable $DoEnable;break} 
                "SpyNet" {SpyNet -enable $DoEnable ;break}
                "DoNotTrack" {DoNotTrack -value $OffOn;break}  
                "SearchSuggestions" {SearchSuggestions -value $OnOff;break}  
                "PagePrediction" {PagePrediction -value $OnOff;break}  
                "PhishingFilter" {PhishingFilter -value $OnOff;break}  
                default {"ooops, nothing selected"}
            }
    }

}
End
{


}
