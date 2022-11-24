# Summary
Script to gather local application deployment type data from remote machines to identify widespread issues.  

This is sort of a companion script to https://github.com/engrit-illinois/Compare-AssignmentRevisions.  

While Compare-AssignmentRevisions looks primarily at locally-cached assignment data across endpoints, Get-CMAppDepTypeData looks at locally-cached application data across endpoints. Looking at locally-cached assignment data is useful to determine if endpoints are looking for incorrect revisions of a deployment (more details on the Compare-Assignments README). Looking at locally-cached application data (or more specifically, the locally-cached data about those applications' available deployment types) is useful to determine if endpoints are missing this deployment type data, which seems to be another reason that Software Center may display only a subset of the applications deployed to it. As noted in the `Compare-AssignmentRevisions` README, this can also cause deployment reporting to be incomplete. It seems as though when the client runs into one of these problems it stops processing further deployments, causing both issues.  

Gathering both types of data in a single script turned out to be more trouble than it was worth, so I've moved this application data-gathering functionality here.  
<br />
<br />

# Requirements
- Requires PowerShell 7
<br />
<br />

# Usage
1. Download `Report-AMTStatus.psm1` to the appropriate subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
2. Run it, e.g.: `Get-CMAppDepTypeData -Collection "UIUC-ENGR-All Systems" -Csv ":ENGRIT:" -Log ":ENGRIT:"`.
3. Review the generated CSV. See the notes below for how to interpret the results.
<br />
<br />

# Interpretation
The resulting CSV will have one row for every app deployement for every computer. This data comes from the specific WMI store the computer uses to cache information about its deployments. This data _should_ include a list of deployment types available for each app. But sometimes computers are missing this deployment type information, and this can cause the issues noted in the summary above.  

Each row in the CSV will list some stats about the computer, the name of the deployed app, the names of the deployment types for that app, and for convenience, a count of the deployment types. If an app is missing its deployment type data, no deployment type names will be listed and the `AppDTCount` column will contain `0`.  

An issue with an individual endpoint will manifest as many rows, representing multiple deployments on the same computer, where the `AppDtCount` is 0. The easiest way to identify this is to sort the data first by the `AppDTCount` column (ascending), and then by the `Computer` column. If you see the same computer listed many times with an `AppDTCount` of `0`, then that client may have issues.  

A widespread issue will manifest as many rows, representing the same deployment across different computers, where the `AppDTCount` is 0. The easiest way to identify this is to sort the data first by the `AppDTCount` column (ascending), and then by the `AppName` column. If you see the same app listed many times across different computers with an `AppDTCount` of `0`, then that appor deployment may have an issue.  
<br />
<br />

# Remediation
This script performs no remediation on endpoints. It's sole purpose is to gather data to better inform your actions.  

If an individual endpoint is having problems, frequently this can be resolved either by running code to revaluate the MECM client's assignments (see here: https://github.com/engrit-illinois/force-software-center-assignment-evaluation), or by simply reinstalling the MECM client.  

This script is primarily to determine if there are some endpoints which _all_ have problems with a specific deployment/application, which could imply that there is something wrong with that object on the MECM side. If you find that is the case, some possible remediation actions are:  
- Re-distribute the content of the offending deployment
- Delete and recreate the offending deployment
- Increment the revision of the deployment's application's deployment type, by making a benign edit (such as to the name string) and saving it. This should trigger all (functioning) clients where this deployment type is deployed to refresh their assignment data.
- Update the content of the deployment type of the offending application (right-click -> Update Content).
- Remove invalid references to deleted applications in the offending application's supersedence chain. See [Get-AppSupersedence](https://github.com/engrit-illinois/Get-AppSupersedence) for an easier way to identify this issue.
- Prune the supersedence chain of the offending application. Very long supersedence chains are known to cause issues.
<br />
<br />

# Parameters

### -Computer \<string[]\>
Required string array, when `-Collection` is not specified.  
An array of strings representing AD computer object names, or wildcard queries for AD computer object names.  
e.g.:  
  - `-Computer "comp-name-01"`
  - `-Computer "comp-name-01","comp-name-02"`
  - `-Computer "comp-name-*"`
  - `-Computer "comp-name-*","comp-name2-*"`
  - `-Computer "comp-name-01","comp-name2-*"`

Only computer names which are found as objects in AD (under the given `-SearchBase`) will be considered and acted upon.  

### -SearchBase \<string\>
Optional string.  
The Distinguished Name (OUDN) of the Organizational Unit (OU) under which to search for AD computers.  
Default is `"OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`.  

### -Collection \<string\>
Required string, when `-Computer` is not specified.  
A string representing the name of a MECM collection.  
Only computer names which are found as members of the given collection will be considered and acted upon.  

### -Csv \<string\>
Optional string.  
The full path of a CSV file to output resulting data to.  
If omitted, no CSV will be created (which more or less defeats the purpose of running this script).  
If `:TS:` is given as part of the string, it will be replaced by a timestamp of when the script was started, with a format specified by `-LogFileTimestampFormat`.  
Specify `:ENGRIT:` to use a default path (i.e. `c:\engrit\logs\<Module-Name>_<timestamp>.csv`).  

### -Log \<string\>
Optional string.  
The full path of a text file to log to.  
If omitted, no log will be created.  
If `:TS:` is given as part of the string, it will be replaced by a timestamp of when the script was started, with a format specified by `-LogFileTimestampFormat`.  
Specify `:ENGRIT:` to use a default path (i.e. `c:\engrit\logs\<Module-Name>_<timestamp>.log`).  

### -ThrottleLimit \<int\>
Optional integer.  
The maximum number of endpoints to poll simultaneously.  
Default is `50`.  

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
