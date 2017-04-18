

Function UninstallApp([String] $app) {
	Write "uninstalling $app"
	Get-AppxPackage | ?{$_.Name -Match $app} |Remove-AppxPackage
}

UninstallApp -app "king.com.ParadiseBay"
UninstallApp -app "Microsoft.XboxApp"
UninstallApp -app "Microsoft.Office.OneNote"
UninstallApp -app "Microsoft.SkypeApp"
UninstallApp -app "Twitter"
UninstallApp -app "Microsoft.Messaging"
UninstallApp -app "Microsoft.XboxIdentityProvider"
UninstallApp -app "Microsoft.OneConnect"
UninstallApp -app "Microsoft.Advertising.Xaml"
UninstallApp -app "Microsoft.Office.OneNote"
UninstallApp -app "Microsoft.WindowsMaps"
UninstallApp -app "microsoft.windowscommunicationsapps"
UninstallApp -app "Microsoft.ZuneMusic"
UninstallApp -app "Microsoft.BingWeather"
UninstallApp -app "Microsoft.ZuneVideo"
UninstallApp -app "Microsoft.MicrosoftStickyNotes"

# OneDrive is complicated:
taskkill /f /im OneDrive.exe
& "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall