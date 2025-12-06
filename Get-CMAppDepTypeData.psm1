# Documentation home: https://github.com/engrit-illinois/Get-CMAppDepTypeData
# By mseng3

function Get-CMAppDepTypeData {
	
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=$true,ParameterSetName="Computer")]
		[string[]]$Computer,
		
		[string]$SearchBase = "OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		[Parameter(Position=0,Mandatory=$true,ParameterSetName="Collection")]
		[string]$Collection,
		
		[switch]$DisablePsVersionCheck,
		
		# ":ENGRIT:" will be replaced with "c:\engrit\logs\$($MODULE_NAME)_:TS:.csv"
		# ":TS:" will be replaced with start timestamp
		[string]$Csv,
		
		# ":ENGRIT:" will be replaced with "c:\engrit\logs\$($MODULE_NAME)_:TS:.log"
		# ":TS:" will be replaced with start timestamp
		[string]$Log,
		
		[int]$ThrottleLimit = 50,
		
		[int]$CimTimeoutSec = 60,
		
		[string]$SiteCode="MP0",
		[string]$Provider="sccmcas.ad.uillinois.edu",
		[string]$CMPSModulePath="$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1",

		# This logging is designed to output to the console (Write-Host) by default
		# This switch will silence the console output
		[switch]$NoConsoleOutput,
		
		[string]$Indent = "    ",
		[string]$LogFileTimestampFormat = "yyyy-MM-dd_HH-mm-ss",
		[string]$LogLineTimestampFormat = "[HH:mm:ss] ",
		[switch]$LogLinePrependComputerName,
		
		[int]$Verbosity = 0
	)
	
	begin {
		# Logic to determine final log filename
		$MODULE_NAME = "Get-CMAppDepTypeData"
		$ENGRIT_LOG_DIR = "c:\engrit\logs"
		$ENGRIT_LOG_FILENAME = "$($MODULE_NAME)_:TS:"
		$START_TIMESTAMP = Get-Date -Format $LogFileTimestampFormat

		if($Log) {
			$Log = $Log.Replace(":ENGRIT:","$($ENGRIT_LOG_DIR)\$($ENGRIT_LOG_FILENAME).log")
			$Log = $Log.Replace(":TS:",$START_TIMESTAMP)
		}
		if($Csv) {
			$Csv = $Csv.Replace(":ENGRIT:","$($ENGRIT_LOG_DIR)\$($ENGRIT_LOG_FILENAME).csv")
			$Csv = $Csv.Replace(":TS:",$START_TIMESTAMP)
		}
		
		# Check that the logfile already exists, and if not, then create it (and the full directory path that should contain it)
		if(-not (Test-Path -PathType "Leaf" -Path $Log)) {
			New-Item -ItemType "File" -Force -Path $Log | Out-Null
		}
		$ASYNC_WRITER = [System.IO.TextWriter]::Synchronized([System.IO.File]::AppendText($Log))
		log "Logging to `"$Log`"."
	
		function log {
			param (
				[Parameter(Position=0)]
				[string]$Msg = "",
				
				[Parameter(Position=1)]
				[string]$ComputerName,

				[int]$L = 0, # level of indentation
				[int]$V = 0, # verbosity level

				[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
				[string]$FC = (get-host).ui.rawui.ForegroundColor, # foreground color
				[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
				[string]$BC = (get-host).ui.rawui.BackgroundColor, # background color
				
				[switch]$OutFile, # Uses Out-File instead of the async writer
				[switch]$E, # error
				[switch]$NoTS, # omit timestamp
				[switch]$NoNL, # omit newline after output
				[switch]$NoConsole, # skip outputting to console
				[switch]$NoLog, # skip logging to file
				[switch]$PassThru # Pass through final formatted string instead of sending to Write-Host (will ignore coloring/NoNewLine parameters)
			)
			if($E) { $FC = "Red" }
			
			if($ComputerName) {
				$Msg = "[$ComputerName] $Msg"
			}
			
			# Custom indent per message, good for making output much more readable
			for($i = 0; $i -lt $L; $i += 1) {
				$Msg = "$Indent$Msg"
			}

			# Add timestamp to each message
			# $NoTS parameter useful for making things like tables look cleaner
			if(-not $NoTS) {
				if($LogLineTimestampFormat) {
					$ts = Get-Date -Format $LogLineTimestampFormat
				}
				$Msg = "$ts$Msg"
			}
			
			if($ComputerName) {
				if($LogLinePrependComputerName) {
					$Msg = "[$ComputerName] $Msg"
				}
			}

			# Each message can be given a custom verbosity ($V), and so can be displayed or ignored depending on $Verbosity
			# Check if this particular message is too verbose for the given $Verbosity level
			if($V -le $Verbosity) {

				# Check if this particular message is supposed to be logged
				if(-not $NoLog) {

					# Check if we're allowing logging
					if($Log) {
						if($OutFile) {
							$Msg | Out-File -FilePath $Log -Append
						}
						else {
							$ASYNC_WRITER.WriteLine($Msg)
						}
					}
				}

				# Check if this particular message is supposed to be output to console
				if(-not $NoConsole) {

					# Check if we're allowing console output at all
					if(-not $NoConsoleOutput) {
						
						if($PassThru) {
							$Msg
						}
						else {
							Write-Host $Msg
						}
					}
				}
			}
		}
		
		# Shorthand for an annoying common line to add new members to objects
		function addm($property, $value, $object, $adObject = $false) {
			if($adObject) {
				# This gets me EVERY FLIPPIN TIME:
				# https://stackoverflow.com/questions/32919541/why-does-add-member-think-every-possible-property-already-exists-on-a-microsoft
				$object | Add-Member -NotePropertyName $property -NotePropertyValue $value -Force
			}
			else {
				$object | Add-Member -NotePropertyName $property -NotePropertyValue $value
			}
			$object
		}
		
		
		# Handy utility function to reliably count members of an array that might be empty
		# Because of Powershell's weird way of handling arrays containing null values
		# i.e. null values in arrays still count as items in the array
		function count($array) {
			$count = 0
			if($array) {
				# If we didn't check $array in the above if statement, this would return 1 if $array was $null
				# i.e. @().count = 0, @($null).count = 1
				$count = @($array).count
				# We can't simply do $array.count, because if it's null, that would throw an error due to trying to access a method on a null object
			}
			$count
		}
		
		function Validate-SupportedPowershellVersion {
			if(-not (Test-SupportedPowershellVersion)) {
				Throw "Unsupported PowerShell version!"
			}
		}

		function Test-SupportedPowershellVersion {
			if($DisablePsVersionCheck) {
				log "-DisablePsVersionCheck was specified. Skipping PowerShell version check."
				return $true
			}
			
			log "This custom module only supports PowerShell v7+. Checking PowerShell version..."
			
			$ver = $Host.Version
			log "PowerShell version is `"$($ver.Major).$($ver.Minor)`"." -L 1
			if($ver.Major -ge 7) {
				return $true
			}
			return $false
		}
		
		function Get-RunTime($startTime) {
			New-Timespan -Start $startTime -End (Get-Date)
		}
		
		function Prep-MECM {
			log "Preparing connection to MECM..."
			
			# Import the ConfigurationManager.psd1 module
			log "Checking if the ConfigurationManager PowerShell module is imported..." -L 1
			
			$success = $true
			if($null -eq (Get-Module "ConfigurationManager")) {
				log "Module was not found. Importing it..." -L 2
				try {
					Import-Module $CMPSModulePath -Scope "Global" -ErrorAction "Stop"
				}
				catch {
					log "Failed to import module!" -E -L 3
					$success = $false
				}
				
				if($success) {
					log "Module successfully imported." -L 3
				}
			}
			else {
				log "Module already imported." -L 2
			}
			
			if($success) {
				# Connect to the site's drive if it is not already present
				# Normally, the necessary PSDrive is automaticall created during the ConfigurationManager module's Import-Module process.
				# This is just a fallback in case the PSDrive is closed or fails to connect.
				log "Checking if the $($SiteCode): PSDrive was successfully created when importing $CM_MODULE_NAME PowerShell module..." -L 1
				
				$drive = Get-PSDrive -Name $SiteCode -PSProvider "CMSite" -ErrorAction "SilentlyContinue"
				if($null -eq $drive) {
					try {
						log "PSDrive was not found. Creating it..." -L 2
						$drive = New-PSDrive -Name $SiteCode -PSProvider "CMSite" -Root $Provider -Scope "Global" -ErrorAction "Stop"
					}
					catch {
						log "Failed to create PSDrive!" -E -L 3
						$success = $false
					}
					
					if($success) {
						log "PSDrive successfully created." -L 3
					}
				}
				else {
					log "PSDrive already exists." -L 2
				}
			}
			
			if($success) {
				# Set the current location to be the site code.
				log "Setting present working directory to PSDrive..." -L 1
				Set-Location "$($SiteCode):\"
				
				log "Done prepping connection to MECM."
			}
			else {
				log "MECM connection prep did not succeed!" -E
			}
		}
		
		function Get-CompNameList($compNames) {
			$list = ""
			foreach($name in $compNames) {
				$list = "$list, $name"
			}
			$list = $list.Substring(2,$list.length - 2) # Remove leading ", "
			$list
		}
		
		function Get-CompNames {
			log "Getting list of computer names..."
			if($Computer) {
				log "-Computer was specified. Getting computer names from AD..." -l 1 -v 1
				$compNames = @()
				$Computer | ForEach-Object {
					$query = $_
					$results = Get-ADComputer -SearchBase $SearchBase -Filter "name -like `"$query`"" | Select -ExpandProperty Name
					$compNames += @($results)
				}
				$list = Get-CompNameList $compNames
				log "Found $($compNames.count) matching AD computers: $list." -l 1
			}
			elseif($Collection) {
				log "-Collection was specified. Getting members of collection: `"$Collection`"..." -l 1 -v 1
				
				$myPWD = $pwd.path
				Prep-MECM
				
				$colObj = Get-CMCollection -Name $Collection
				if(!$colObj) {
					log "The given collection was not found!" -l 1
				}
				else {
					# Get comps
					$comps = Get-CMCollectionMember -CollectionName $Collection | Select Name,ClientActiveStatus
					if(!$comps) {
						log "The given collection is empty!" -l 1
					}
					else {
						# Sort by active status, with active clients first, just in case inactive clients might come online later
						# Then sort by name, just for funsies
						$comps = $comps | Sort -Property @{Expression = {$_.ClientActiveStatus}; Descending = $true}, @{Expression = {$_.Name}; Descending = $false}
						
						$compNames = $comps.Name
						$list = Get-CompNameList $compNames
						log "Found $($compNames.count) computers in `"$Collection`" collection: $list." -l 1
					}
				}
				
				Set-Location $myPWD
			}
			else {
				log "Somehow neither the -Computer, nor -Collection parameter was specified!" -l 1
			}
			
			log "Done getting list of computer names." -v 2
			
			$compNames
		}
		
		# Make array of objects representing computers
		function Get-Comps($compNames) {
			log "Making array of objects to represent each computer..."
		
			# Make sure $comp is treated as an array, even if it has only one member
			# Not sure if this is necessary, but better safe than sorry
			$compNames = @($compNames)
			
			# Make new array to hold objects representing computers
			$comps = @()
			
			foreach($compName in $compNames) {
				$hash = @{
					"Name" = $compName
					"Responded" = $null
					"Error" = $null
					"ErrorReasons" = @()
					"MecmClientVer" = $null
					"PsVer" = $null
					"OsVer" = $null
					"Make" = $null
					"Model" = $null
					"Apps" = @()
					"Skip" = $false
				}
				$comp = New-Object PSObject -Property $hash
				$comps += @($comp)
			}
			
			log "Done making computer object array." -v 2
			$comps
		}
		
		function Get-Data($comps) {
			log "Getting data for all computers..."
			
			# Save these functions to strings so they can be reused/re-created within the scope of the ForEach-Object -Parallel scriptblock:
			# https://tighetec.co.uk/2022/06/01/passing-functions-to-foreach-parallel-loop/
			$f_log = ${function:log}.ToString()
			$f_addm = ${function:addm}.ToString()
			$f_count = ${function:count}.ToString()
			
			$comps = $comps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
				$ASYNC_WRITER = $using:ASYNC_WRITER
				$Log = $using:Log
				$Verbosity = $using:Verbosity
				$Indent = $using:Indent
				$LogLineTimestampFormat = $using:LogLineTimestampFormat
				$LogLinePrependComputerName = $using:LogLinePrependComputerName
				${function:log} = $using:f_log
				
				# Save these functions to strings so they can be sent to and reused/re-created within the scope of the Invoke-COmmand scriptblock:
				$f_log = $using:f_log
				$f_addm = $using:f_addm
				$f_count = $using:f_count
				
				$comp = $_
				$compName = $comp.Name
				
				log "Getting data..." $compName -L 1 -V 1
				
				if(-not (Test-Connection $comp.Name -Quiet -Count 1)) {
					$comp.Responded = $false
					log "Did not respond to ping!" $compName -L 2 -V 2
				}
				else {
					$comp.Responded = $true
					log "Responded to ping." $compName -L 2 -V 2
					
					$scriptBlock = {
						param(
							[int]$CimTimeoutSec,
							[bool]$Responded,
							$ASYNC_WRITER,
							[string]$Log,
							[int]$Verbosity,
							[string]$Indent,
							[string]$LogLineTimestampFormat,
							[string]$LogLinePrependComputerName,
							[string]$f_log,
							[string]$f_addm,
							[string]$f_count
						)
						
						${function:log} = $f_log
						${function:addm} = $f_addm
						${function:count} = $f_count
						
						$err = $false
						$errReasons = @()
						
						$compName = $env:ComputerName
						
						log "Getting MECM client version..." $compName -L 3 -V 2 -NoLog
						try {
							$mecmClientVer = Get-CIMInstance -Namespace "root\ccm" -Class "SMS_Client" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec | Select -ExpandProperty "ClientVersion"
						}
						catch {
							$err = $true
							$errReasons += @("Failed to get MECM client version!")
						}
						
						log "Getting PowerShell version..." $compName -L 3 -V 2 -NoLog
						try {
							$psVer = $PSVersionTable.PSVersion.ToString()
						}
						catch {
							$err = $true
							$errReasons += @("Failed to get PowerShell version!")
						}
						
						log "Getting Win32_OperatingSystem WMI info..." $compName -L 3 -V 2 -NoLog
						try {
							$osVer = Get-CIMInstance -Class "Win32_OperatingSystem" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec | Select -ExpandProperty "Version"
						}
						catch {
							$err = $true
							$errReasons += @("Failed to get OS version!")
						}
						
						log "Getting Win32_ComputerSystem WMI info..." $compName -L 3 -V 2 -NoLog
						try {
							$makeModel = Get-CIMInstance -Class "Win32_ComputerSystem" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec
							$make = $makeModel | Select -ExpandProperty "Manufacturer"
							$model = $makeModel | Select -ExpandProperty "Model"
						}
						catch {
							$err = $true
							$errReasons += @("Failed to get make/model!")
						}
						
						log "Getting CCM_Application WMI info..." $compName -L 3 -V 2 -NoLog
						try {
							$apps = Get-CIMInstance -Namespace "root\ccm\clientsdk" -Class "CCM_Application" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec | Select * -ExcludeProperty "Icon"
						}
						catch {
							$err = $true
							$errReasons += @("Failed to get application data!")
						}
						
						log "Parsing app info..." $compName -L 3 -V 2 -NoLog
						if($apps) {
							$apps | Sort Name | ForEach-Object {
								$app = $_
								log "Parsing app info for app `"$($app.Name)`"..." $compName -L 4 -V 3 -NoLog
								
								# For some dumb reason, Get-CIMInstance doesn't return the __PATH property like Get-WMIObject does, so reconstruct it
								# https://jdhitsolutions.com/blog/powershell/8541/getting-ciminstance-by-path/
								# https://jdhitsolutions.com/blog/wmi/3105/adding-system-path-to-ciminstance-objects/
								$serverName = $app.CimSystemProperties.ServerName
								$cimClass = $app.CimClass.ToString() -replace "/","\"
								$modelName = $app.Id.ToString()
								$machineTarget = $app.IsMachineTarget.ToString().ToLower()
								$revision = $app.Revision.ToString()
								$path = "\\$($serverName)\$($cimClass).Id=`"$($modelName)`",IsMachineTarget=$($machineTarget),Revision=`"$($revision)`""
								$app = addm "Path" $path $app
								
								# Get AppDTs for each app
								try {
									$appDTs = [wmi]$path | Select -ExpandProperty "AppDTs"
									
									$appDTCount = count $appDTs
									$app = addm "AppDTCount" $appDTCount $app
									
									if($appDTCount -gt 0) {
										$appDTNames = $appDTs | Select -ExpandProperty "Name"
										$appDTNamesString = $appDTNames -join "`",`""
										$appDTNamesString = "`"$($appDTNamesString)`""
										$app = addm "AppDTNames" $appDTNamesString $app
									}
								}
								catch {
									$err = $true
									$errReasons += @("Failed to get application deployment type data!")
								}
								
								# Add misc. info to each app
								$app = addm "Computer" $serverName $app
								$app = addm "Responded" $Responded $app
								$app = addm "Error" $err $app
								$app = addm "ErrorReasons" $errReasons -join " " $app
								$app = addm "MecmClientVer" $mecmClientVer $app
								$app = addm "PsVer" $psVer $app
								$app = addm "OsVer" $osVer $app
								$app = addm "Make" $make $app
								$app = addm "Model" $model $app
								
								$app
							}
						}
						else {
							$err = $true
							$errReasons += @("Application data was empty!")
							$errReasonsString = $errReasons -join ";"
							log $errReasonsString $compName -L 4 -V 3 -NoLog
						}
						log "Done parsing app info..." $compName -L 3 -V 3 -NoLog
					}
					
					log "Invoking commands..." $compName -L 2 -V 2
					$comp.Apps = Invoke-Command -ComputerName $comp.Name -ArgumentList $CimTimeoutSec,$comp.Responded,$ASYNC_WRITER,$Log,$Verbosity,$Indent,$LogLineTimestampFormat,$LogLinePrependComputerName,$f_log,$f_addm,$f_count -ScriptBlock $scriptBlock -InformationVariable "logs"
					log "Logs:" $compName -L 2 -V 3
					$logs | ForEach-Object {
						log $_ -V 3 -NoTS
					}
					log "End of logs:" $compName -L 2 -V 3
				}
				log "Done getting data." $compName -L 1 -V 1
				
				$comp
			}
			log "Done getting data for all computers."
			
			$comps
		}
		
		function Export-Apps($comps) {
			log "Exporting app information to CSV..."
			
			if($Csv) {
				log "Merging data from all computers..." -l 1
				# Merge all apps from all comps into single array
				$apps = @()
				$comps | ForEach-Object {
					$apps += @($_.Apps)
				}
				
				# Export apps
				log "Exporting to `"$Csv`"..." -l 1
				if(-not (Test-Path -PathType "Leaf" -Path $Csv)) {
					$shutup = New-Item -ItemType File -Force -Path $Csv
				}
				$apps | Sort Computer,Name | Select Computer,Error,ErrorReasons,MecmClientVer,PsVer,OsVer,Make,Model,@{Name="AppName";Expression={$_.Name}},AppDTNames,AppDTCount | Export-Csv -NoTypeInformation -Path $Csv
			}
			else {
				log "No path was specified for -Csv! Skipping export." -l 1
			}
		}
	}
	
	process {
		Validate-SupportedPowershellVersion
		
		$startTime = Get-Date
		
		$compNames = Get-CompNames
		if($compNames) {
			$comps = Get-Comps $compNames
			$comps = Get-Data $comps
			Export-Apps $comps
		}
		
		$runTime = Get-RunTime $startTime
		log "Runtime: $runTime"
	}
	
	end {

	}
	
	clean {
		log "Cleaning up..."
		$ASYNC_WRITER.Close()
		log "EOF" -OutFile
	}
}