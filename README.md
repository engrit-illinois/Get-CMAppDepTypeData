# THIS SCRIPT IS A WORK IN PROGRESS

# Get-CMAppDepTypeData
Script to gather local application deployment type data from remote machines to identify widespread issues.  

This is sort of a companion script to https://github.com/engrit-illinois/Compare-AssignmentRevisions.  

While Compare-AssignmentRevisions looks primarily at locally-cached assignment data across endpoints, Get-CMAppDepTypeData looks at locally-cached application data across endpoints. Looking at locally-cached assignment data is useful to determine if endpoints are looking for incorrect revisions of a deployment (more details on the Compare-Assignments README). Looking at locally-cached application data (or more specifically, the locally-cached data about those applications' available deployment types) is useful to determine if endpoints are missing this deployment type data, which is another reason that Software Center may display only a subset of the applications deployed to it.  

Gathering both types of data in a single script turned out to be more trouble than it was worth, so I've moved this application data-gathering functionality here.  

# Usage
WIP

# Parameters
WIP

# Notes
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.