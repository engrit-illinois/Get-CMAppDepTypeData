# Documentation home: https://github.com/engrit-illinois/Get-CMAppDepTypeData
# By mseng3

function Get-CMAppDepTypeData {
	
	param(
		[Parameter(Position=0,Mandatory=$true,ParameterSetName="Computer")]
		[string[]]$Computer,
		
		[string]$SearchBase = "OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu",
		
		[Parameter(Position=0,Mandatory=$true,ParameterSetName="Collection")]
		[string]$Collection,
		
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
		
		[int]$Verbosity = 0
	)
	
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
	
	function log {
		param (
			[Parameter(Position=0)]
			[string]$Msg = "",
			
			# Replace this value with whatever the default value of the full log file path should be
			[string]$Log = $Log,

			[int]$L = 0, # level of indentation
			[int]$V = 0, # verbosity level

			[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
			[string]$FC = (get-host).ui.rawui.ForegroundColor, # foreground color
			[ValidateScript({[System.Enum]::GetValues([System.ConsoleColor]) -contains $_})]
			[string]$BC = (get-host).ui.rawui.BackgroundColor, # background color

			[switch]$E, # error
			[switch]$NoTS, # omit timestamp
			[switch]$NoNL, # omit newline after output
			[switch]$NoConsole, # skip outputting to console
			[switch]$NoLog # skip logging to file
		)
		if($E) { $FC = "Red" }

		$ofParams = @{
			"FilePath" = $Log
			"Append" = $true
		}
		
		$whParams = @{}
		
		if($NoNL) {
			$ofParams.NoNewLine = $true
			$whParams.NoNewLine = $true
		}
		
		if($FC) { $whParams.ForegroundColor = $FC }
		if($BC) { $whParams.BackgroundColor = $BC }

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

		# Each message can be given a custom verbosity ($V), and so can be displayed or ignored depending on $Verbosity
		# Check if this particular message is too verbose for the given $Verbosity level
		if($V -le $Verbosity) {

			# Check if this particular message is supposed to be logged
			if(-not $NoLog) {

				# Check if we're allowing logging
				if($Log) {

					# Check that the logfile already exists, and if not, then create it (and the full directory path that should contain it)
					if(-not (Test-Path -PathType "Leaf" -Path $Log)) {
						New-Item -ItemType "File" -Force -Path $Log | Out-Null
						log "Logging to `"$Log`"."
					}
					
					$Msg | Out-File @ofParams
				}
			}

			# Check if this particular message is supposed to be output to console
			if(-not $NoConsole) {

				# Check if we're allowing console output at all
				if(-not $NoConsoleOutput) {
					Write-Host $Msg @whParams
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
	
	function Get-RunTime($startTime) {
		New-Timespan -Start $startTime -End (Get-Date)
	}
	
	function Prep-MECM {
		log "Preparing connection to MECM..." -l 1
		$initParams = @{}
		if((Get-Module ConfigurationManager) -eq $null) {
			# The ConfigurationManager Powershell module switched filepaths at some point around CB 18##
			# So you may need to modify this to match your local environment
			Import-Module $CMPSModulePath @initParams -Scope Global
		}
		if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
			New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $Provider @initParams
		}
		Set-Location "$($SiteCode):\" @initParams
		log "Done prepping connection to MECM." -l 1 -v 2
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
		
		# https://tighetec.co.uk/2022/06/01/passing-functions-to-foreach-parallel-loop/
		$f_log = ${function:log}.ToString()
		$f_addm = ${function:addm}.ToString()
		$f_count = ${function:count}.ToString()
		
		$comps = $comps | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
			$Verbosity = $using:Verbosity
			$LogLineTimestampFormat = $using:LogLineTimestampFormat
			$Indent = $using:Indent
			${function:log} = $using:f_log
			
			$f_addm = $using:f_addm
			$f_count = $using:f_count
			
			$comp = $_
			$compName = $comp.Name
			
			log "[$compName] Getting data..." -L 1 -V 1 -NoLog
			
			if(-not (Test-Connection $comp.Name -Quiet -Count 1)) {
				$comp.Responded = $false
			}
			else {
				$comp.Responded = $true
				
				$scriptBlock = {
					param(
						[int]$CimTimeoutSec,
						[bool]$Responded,
						[string]$f_addm,
						[string]$f_count
					)
					${function:addm} = $using:f_addm
					${function:count} = $using:f_count
					
					$err = $false
					$errReasons = @()
					
					try {
						$mecmClientVer = Get-CIMInstance -Namespace "root\ccm" -Class "SMS_Client" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec | Select -ExpandProperty "ClientVersion"
					}
					catch {
						$err = $true
						$errReasons += @("Failed to get MECM client version!")
					}
					
					try {
						$psVer = $PSVersionTable.PSVersion.ToString()
					}
					catch {
						$err = $true
						$errReasons += @("Failed to get PowerShell version!")
					}
					
					try {
						$osVer = Get-CIMInstance -Class "Win32_OperatingSystem" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec | Select -ExpandProperty "Version"
					}
					catch {
						$err = $true
						$errReasons += @("Failed to get OS version!")
					}
					
					try {
						$makeModel = Get-CIMInstance -Class "Win32_ComputerSystem" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec
						$make = $makeModel | Select -ExpandProperty "Manufacturer"
						$model = $makeModel | Select -ExpandProperty "Model"
					}
					catch {
						$err = $true
						$errReasons += @("Failed to get make/model!")
					}
					
					try {
						$apps = Get-CIMInstance -Namespace "root\ccm\clientsdk" -Class "CCM_Application" -ErrorAction "Stop" -OperationTimeoutSec $CimTimeoutSec | Select * -ExcludeProperty "Icon"
					}
					catch {
						$err = $true
						$errReasons += @("Failed to get application data!")
					}
					
					if($apps) {
						$apps | ForEach-Object {
							$app = $_
							
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
					}
				}
				
				$comp.Apps = Invoke-Command -ComputerName $comp.Name -ArgumentList $CimTimeoutSec,$comp.Responded,$f_addm,$f_count -ScriptBlock $scriptBlock
			}
			
			log "[$compName] Done getting data." -L 1 -V 1 -NoLog
			
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
	
	function Do-Stuff {
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
	
	Do-Stuff
	
	log "EOF"
	
}