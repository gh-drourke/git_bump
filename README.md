# Purpose

This is a personal script to to maintain a local and optional remote git repository that supports the following workflow:

1. Changes that need to be documented are done so by editing a separate file GIT_MSG.

2. For each local git commit:
    
    - GIT_MSG becomes the message for the commit

    - a local lightweight tag is generated for a 'git tag' command. The commit and tag can then be pushed to the remote repository.
    
    - Optionally, an annotated tag is created 

3. After the commit, GIT_MSG is emptied by the user.

4. Before any push to remote,  the option is given to run ssh-agent and add all private keys starting with "id_". Example:  "id_rsa"

# Script's Functionality

## 1. Handles staging and commits to local branch

The user maintains a list of changes since the last commit in a file called GIT_MSG. 

This file becomes the message content to the '-m' option when executing "$ git commit -m <GIT_MSG>"

## 2. Handles TAG commits

After a "git commit" another "git tag" is presented as an optional.

Both lightweight and annotated tags are supported, though at the moment, the name version description is used for both.

## 3. Maintains Version number control

For all commits, the next version number is suggested. 

It is also possible to commit without a version number.

## 4. Maintains a Filtered History of git log

An list of all git messages is put into a file called 'CHANGE_LOG'

This log is filtered by the removal of lines starting with "author", "date" and "commit"

It is updated with each commit.

# Files

 This script works with two auxiliary files

1. GIT_MSG:

The file GIT_MSG is maintained by the user and contains the content of the message to be written to the next "git commit".

This file should be emptied after git commit to prepare for next commit.

As an aid to empting this file after a commit, the file is updated with a marker to indicate what lines have been committed and appear in the git log.

All content above this line should be deleted before the next branch commit.

2. CHANGE_LOG

This file is created and maintained by the script and is changed with every branch commit.

The CHANGES files contains the output from the "git log" command and is filtered by the removal of all lines starting with "author", or  "date".

Note: This file is 'up-to-date' on the local system. However, as it is generated after a local commit, it is now an unstaged file and will not be included in the current push to the remote.

# Version Numbers and Tags

1. Version numbers are strictly maintained in a 3-tuple format: Major.minor.patch

2. A 'tag' is a 'version' prepended by a 'v'. ex. version '1.2.3' becomes tag 'v1.2.3'

3. Version numbers are generated based on the last version and suggested for the current commit.

4. Version numbers and Tags can not be reused.

5. Any branch commit can (and by default does) receive a lightweight tag.

6. An annotated tag can be created after any branch commit.

# Usage

1. Download the script and place on PATH.

2. Change to directory of the repository being worked on.

3. Run the command:

    $ git_bump


