# THIS SCRIPT IS A WORK IN PROGRESS
This script is currently incomplete. Do not use until this notice has been removed.  
<br />
<br />

# Get-CMAppDepTypeData
Script to gather local application deployment type data from remote machines to identify widespread issues.  

This is sort of a companion script to https://github.com/engrit-illinois/Compare-AssignmentRevisions.  

While Compare-AssignmentRevisions looks primarily at locally-cached assignment data across endpoints, Get-CMAppDepTypeData looks at locally-cached application data across endpoints. Looking at locally-cached assignment data is useful to determine if endpoints are looking for incorrect revisions of a deployment (more details on the Compare-Assignments README). Looking at locally-cached application data (or more specifically, the locally-cached data about those applications' available deployment types) is useful to determine if endpoints are missing this deployment type data, which is another reason that Software Center may display only a subset of the applications deployed to it.  

Gathering both types of data in a single script turned out to be more trouble than it was worth, so I've moved this application data-gathering functionality here.  
<br />
<br />

# Requirements
- Requires PowerShell 7
- 
<br />
<br />

# Usage
WIP
<br />
<br />

# Interpretation
WIP
<br />
<br />

# Remediation
This script performs no remediation on endpoints. It's sole purpose is to gather data to better inform your actions.  

If an individual endpoint is having problems, frequently this can be resolved either by running code to revaluate the MECM client's assignments (see here: https://github.com/engrit-illinois/force-software-center-assignment-evaluation), or by simply reinstalling the MECM client.  

This script is primarily to determine if there are some endpoints which _all_ have problems with a specific deployment/application, which could imply that there is something wrong with that object on the MECM side. If you find that is the case, some possible remediation actions are:  
- Re-distribute the content of the offending deployment
- Delete and recreate the offending deployment
- Increment the revision of the deployment's application's deployment type, by making a benign edit (such as to the name string) and saving it. This should trigger all (functioning) clients where this deployment type is deployed to refresh their assignment data.
<br />
<br />

# Parameters

### -Computer \<string[]\>
WIP

### -SearchBase \<string\>
WIP

### -Collection \<string\>
WIP

### -Csv \<string\>
Optional string.  
The full path of a CSV file to output resulting data to.  
If omitted, no CSV will be created.  
If `:TS:` is given as part of the string, it will be replaced by a timestamp of when the script was started, with a format specified by `-LogFileTimestampFormat`.  
Specify `:ENGRIT:` to use a default path (i.e. `c:\engrit\logs\<Module-Name>_<timestamp>.csv`).  

### -Log \<string\>
Optional string.  
The full path of a text file to log to.  
If omitted, no log will be created.  
If `:TS:` is given as part of the string, it will be replaced by a timestamp of when the script was started, with a format specified by `-LogFileTimestampFormat`.  
Specify `:ENGRIT:` to use a default path (i.e. `c:\engrit\logs\<Module-Name>_<timestamp>.log`).  

### -ThrottleLimit \<int\>
Optional integer

### -SiteCode \<string\>
Optional string, representing the Site Code ID for your SCCM site.  
Default value is `MP0`, because that's the author's site.  
You can change the default value near the top of the script.  

### -Provider \<string\>
Optional string, representing the hostname of your provider.  
Use whatever you use in the console GUI application.  
Default value is `sccmcas.ad.uillinois.edu`, because that's the author's provider.  
You can change the default value near the top of the script.  

### -CMPSModulePath \<string\>
Optional string, representing the local path where the ConfigurationManager Powershell module exists.  
Default value is `$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1`, because there's where it is for us.  
You may need to change this, depending on your SCCM (Console) version. The path has changed across various versions of SCCM, but the environment variable used by default should account for those changes in most cases.  
You can change the default value near the top of the script.  

### -NoConsoleOutput
Optional switch.  
If specified, progress output is not logged to the console.  

### -Indent \<string\>
Optional string.  
The string used as an indent, when indenting log entries.  
Default is four space characters.  

### -LogFileTimestampFormat \<string\>
Optional string.  
The format of the timestamp used in filenames which include `:TS:`.  
Default is `yyyy-MM-dd_HH-mm-ss`.  

### -LogLineTimestampFormat \<string\>
Optional string.  
The format of the timestamp which prepends each log line.  
Default is `[HH:mm:ss:ffff]⎵`.  

### -Verbosity \<int\>
Optional integer.  
The level of verbosity to include in output logged to the console and logfile.  
Currently not significantly implemented.  
Default is `0`.  
<br />
<br />

# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.