# Purpose

This script does the following:

## 1. Handles staging and commits to local branch

The user maintains a list of changes since the last commit in a file called GIT_MSG. 

This file becomes the message content to the -m option when executing "$ git commit -m <GIT_MSG>"

## 2. Handles TAG commits

After a "git commit" another "git tag" is optional.

## 3. Version number control

For all commits, the next version number is suggested. 

It is also possible to commit without a version tag.

## 4. Maintain a filtered history of git log

An list of all git messages is put into a file called 'CHANGE_LOG'

This log is filtered by the removal of lines starting with "author", "date" and "commit"

It is updated with each commit.

# Assumptions

 ## 1. A git repository has been initialised.

 This script will offer to initialise a repository with the trunk branch called main.

 ## 2. A .gitignore file has been populated.

# Files

 Works with two files (will create if not present)

1. CHANGE_LOG

This file is maintained by the script and is changed with every branch commit.

The CHANGES files contains the output from the "git log" command and is filtered by the removal of all lines starting with "author", "date" or "commit".

2. GIT_MSG:

The file GIT_MSG is maintained by the user and contains the content to be written to the next "git commit".

This file should be emptied after git commit to prepare for next commit.

This file is updated with a marker with each commit at the end to indicate what part appears in the git log.

All content above this line should be deleted before the next branch commit.

# Tagging

Tags are maintained in a three digit format: Major.minor.patch

1. Any branch commit can receive a lightweight tag.

2. An annotated tag can be made after any branch commit.

(to implement: only if it has a version number that corresponds to a local tag commit.)

3. A 'suggested tag' is offered based on the latest tag in a sequence.

4. Tags may not be reused.

5. Tags are strictly used in triplet format: M.m.p

# Usage

1. Download the script and place on PATH.

2. Change to directory of the repository being worked on.

3. Run the command:

    $ git_bump


