# Purpose: 

 This script will

 1  display the current version.
 2. automatically suggest a  version update.
 3. Incorporate contents of file GIT_MSG into the git commit message.
 4. pull a list of changes from git history,
       prepend this to a file called CHANGES
       - (under the title of the new version number)
 5. Create a GIT tag

# Assumptions:

 1. repository has been initialised.
 2. .gitignore file has been populated.

# Files

 Works with two files (will create if not present)
 
1. CHANGES:

The CHANGES files contains  the most recent output from git log
 edited by removing author, date and commit lines

2. GIT_MSG:

The file GIT_MSG contains content to be written to current git commit.

Note: should be emptied after git commit to prepare for next commit.

