
# Purspose: 

 This script will

 1  display the current version.
 2. automatically suggest a  version update.
 3. Incorporatet contents of file GIT_MSG into the git commit message.
 4. pull a list of changes from git history,
       prepend this to a file called CHANGES
       - (under the title of the new version number)
 5. Create a GIT tag

# Assumptions:

 1. repository has been initialised.
 2. .gitnore file has been populated.

# Files

 Works with three files (will create if not present)
   CHANGES:
 just most recent output from git log
 edited by removing author, date and commit lines

   VERSION:
 maintains version number
 format is:  MAJOR.minor.patch

   GIT_MSG:
 content to be written to current git commit.
 note: should be emptied after git commit to prepare
 for next commit.


