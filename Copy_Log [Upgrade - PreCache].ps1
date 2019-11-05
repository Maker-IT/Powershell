<#

 Titre : Copie de logs pour la mise à niveau de Windows 10.

 Description : copie fichiers de logs du dossier Panther et smsts.log

               Exécution de l'utilisataire SetupDiag.exe
               
               Parse fichier xml afin de remonter les drivers ou applications non compatible

                    <nom PC>-incompatible-drivers.csv  <nom PC>-incompatible-apps.csv

 Path : <path log>\<version target OS>\PreCache_<date&heure>

#>

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment

$date = Get-Date -UFormat "%m-%d-%Y_%R" | ForEach-Object { $_ -replace ":", "h" }

#[string]$pathlog = "C:\LOG\Upgrade\1809\PreCache_"
$pathlog = $tsenv.value("UpgradePathLog")
$targetOS = $tsenv.value("SMSTSTargetOSBuild")
[string]$pathlog = $pathlog+"\"+$targetOS+"\PreCache_"+$date

# create folder
If (-not (Test-Path $pathlog)){
    New-Item -Path "$pathlog" -ItemType Directory
}
$tsenv.value("UpgradePathLog")=$pathlog

If(-not (Test-Path "$pathlog\Panther")){
    New-Item -Path "$pathlog\Panther" -ItemType Directory
}

If(-not (Test-Path "$pathlog\SMSTS")){
    New-Item -Path "$pathlog\SMSTS" -ItemType Directory
}

# save panther and scanresult.xml
if (Test-Path "$($env:SystemDrive)\`$Windows.~BT\Sources\Panther"){
	Copy-Item "$($env:SystemDrive)\`$Windows.~BT\Sources\Panther\*.*" "$pathlog\Panther" -Force
    Copy-Item "$($env:SystemDrive)\`$Windows.~BT\Sources\Panther\ScanResult.xml" "$pathlog" -Force
}
elseif (Test-Path "$($env:SystemDrive)\Windows.old\WINDOWS\panther\NewOs\Panther") {
    Copy-Item "$($env:SystemDrive)\Windows.old\WINDOWS\panther\NewOs\Panther\*.*" "$pathlog\Panther" -Force
	Copy-Item "$($env:SystemDrive)\Windows.old\WINDOWS\panther\NewOs\Panther\ScanResult.xml" "$pathlog" -Force
}
######



# save smstslog
if (Test-Path "$($env:SystemDrive)\Windows\CCM\Logs\SMSTSLog\smsts.log"){
	Copy-Item "$($env:SystemDrive)\Windows\CCM\Logs\SMSTSLog\smsts*.log" "$pathlog\SMSTS" -Force
}
elseif (Test-Path "$($env:SystemDrive)\_SMSTaskSequence\smsts.log"){
	Copy-Item "$($env:SystemDrive)\_SMSTaskSequence\smsts*.log" "$pathlog\SMSTS" -Force
}
elseif (Test-Path "$($env:SystemDrive)\Windows\CCM\Logs\smsts.log") {
	Copy-Item "$($env:SystemDrive)\Windows\CCM\Logs\smsts*.log" "$pathlog\SMSTS" -Force
}
######



###### Launch Tools SetupDiag.exe

# Check that .Net 4.6 minimum is installed
If (Get-ChildItem "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" | Get-ItemPropertyValue -Name Release | ForEach-Object { $_ -ge 393295 }){
   
     If (Test-Path "C:\temp\SetupDiag.exe"){

	    If(-not (Test-Path "$pathlog\DiagResult")){
		    New-Item -Path "$pathlog\DiagResult" -ItemType Directory
	    }

$name = $env:COMPUTERNAME
[string]$LogResult = $pathlog+"\"+$name+"__results"	
	
		Try{
            Start-Process -FilePath "C:\temp\SetupDiag.exe" -ArgumentList "/Output:$LogResult.log  /ZipLogs:true" -Wait -ErrorAction Stop

		}
		Catch{
		   "[ERROR] There was an error starting SetupDiag.exe: $_" | Out-file -FilePath "$pathlog\DiagResult\SetupDiagResults.log" -Force 
		}
			
	}
}
Else{
    "[ERROR] .Net Framework 4.6 is required to run SetupDiag.exe" | Out-file -FilePath "$pathlog\DiagResult\SetupDiagResults.log" -Force
}
######


###### PARSE XML TO CSV APPS & DRIVER

$compatDatafolder = "$pathlog\Panther"
$OutputCSVfileapps = "$pathlog\$env:COMPUTERNAME-incompatible-apps.csv"
$OutputCSVfiledrivers = "$pathlog\$env:COMPUTERNAME-incompatible-drivers.csv"
$files = Get-ChildItem "$CompatDataFolder\CompatData*" | Sort-Object LastWriteTime -Descending

$DriverPackages = @()
$apps = @()

if ($files.count -gt 0) {

	$files | ForEach-Object {

		[xml]$compatFile = gc $_.FullName

		if ($compatFile.ChildNodes.Count -gt 0) {

			If ($compatFile.ChildNodes.Programs -ne $null){

				$apps += $compatFile.ChildNodes.Programs.Program | Select @{N="ComputerName";E={$env:computername}},Name,Id


				Write-Host "Found $($apps.count) incompatible apps"
				
			}
			
            If ($compatFile.ChildNodes.DriverPackages -ne $null){

          #      NOT ERROR (search solution for catch inf name and search information
          #      $Driverinf += $compatFile.ChildNodes.DriverPackages.DriverPackage | Select Inf

          #      $drivers = Get-WindowsDriver -Online -Driver "$Driverinf"

          #      $providername = $Drivers[0].providername
          #      $HardwareDescription = $Drivers[0].HardwareDescriptio
          #      $ClassName = $Drivers[0].ClassName
          #      $ClassDescription = $Drivers[0].ClassDescription
          #      $version = $Drivers[0].version

		  #		search information for add inf information
				$DriverPackages += $compatFile.ChildNodes.DriverPackages.DriverPackage | Select @{N="ComputerName";E={$env:computername}}, Inf, BlockMigration, HasSignedBinaries

			}
		} 

	}

	$apps | export-csv $OutputCSVFileapps -delimiter ";"
    $DriverPackages | export-csv "$pathlog\$env:COMPUTERNAME-incompatible-driver.csv" -delimiter ";"
}
else {
	Write-Host "Did not find any CompatData files in $CompatDataFolder"
}
######
