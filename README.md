# THIS SCRIPT IS A WORK IN PROGRESS

# Get-CMAppDepTypeData
Script to gather local application deployment type data from remote machines to identify widespread issues.  

This is sort of a companion script to https://github.com/engrit-illinois/Compare-AssignmentRevisions.  

While Compare-AssignmentRevisions looks primarily at local cached assignment data across remote machines, Get-CMAppDepTypeData looks at local cached application data across remote machines. Looking at locally-cached assignment data is useful to determine if endpoints are looking for incorrect revisions of a deployment (more details on the Compare-Assignments README). Looking at locally-cached application data (or more specifically, the locally-cached data about those applications' available deployment types) is useful to determine if endpoints are missing this deployment type data, which is another reason that Software Center may display only a subset of the applications deployed to it.  

# Usage
WIP

# Parameters
WIP

# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.