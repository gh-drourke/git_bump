# Purpose: 

This script is a personal script for myself to automate the process of commits to branches and tags.
 
It does the following:

## 1. Add all files and commit to local branch.
 
A list of current changes is maintained in a file called GIT_MSG. This file becomes the message content of "$ git commit -m <GIT_MSG>

## 2. Handle TAG commits

The current version is displayed along with a suggested version.

An annotated tag version is created with the suggested version tag.

## 3. Maintain a history of git log.

An edited list of all git messages is put into a file called 'CHANGES'

This log is filtered by the removal lines starting with "author", "date" and "commit" 

# Assumptions:

 1. repository has been initialised.

 2. .gitignore file has been populated.

# Files

 Works with two files (will create if not present)
 
1. CHANGES

The CHANGES files contains  the most recent output from git log edited by removing author, date and commit lines

2. GIT_MSG:

The file GIT_MSG contains content to be written to current git commit.

Note: This file should be emptied after git commit to prepare for next commit.


# Tagging

Tags are maintained in a three digit format: Major.minor.patch

1. Any branch commit can receive a lightweight tag.

    - branch commits that have a bumped path number do not qualify for a tag commit.

2. An annotated tag can be made after any branch commit.

3. A 'suggested tag' is offered based on the next in a sequence.

# Usage

1. Download script and place on PATH.

2. Change to directory of the repository being worked on.

3. Run the command:

    $ git_bump


