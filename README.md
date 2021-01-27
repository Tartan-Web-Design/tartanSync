# tartanSync


Ignore this - it's a test of twist.


## How to install tartanSync

Tartansync requires the following:

- wp-cli 
  - To be installed, and available through the alias "wp"
  - NB, this link: https://wp-cli.org has the most up to date how-to on doing this.
  - Be sure to test that the alias and executable is functioning by openning a new term and typing "wp".  You should get a help screen.

- mysql
  - See https://dev.mysql.com/doc/mysql-osx-excerpt/5.7/en/osx-installation-pkg.html
  - NB, ensure that the path to mysql is included in ENV.  
    - export PATH=${PATH}:/usr/local/mysql/bin/
    - source ~/.zshrc

- Tartansync
  - Download or git pull Tartansync to your local machine
  - Ensure that the path to the location of Tartansync is included in ENV.
    - export PATH=${PATH}:/Users/scott/Dropbox/Tartan/git/tartanSync/
    - source ~/.zshrc
  - Add an alias to reducing typing strain:
    - nano ~/.zshrc
    - alias tartanSync="bash tartanSync.sh"
  
 ## How to use tartanSync
 
 Tartansync assumes that you're pushing and pulling between a LocalbyFlywheel wordpress site and a Plesk wordpress site.
 
 Usage is:
  - tartanSync.sh [<pull|push>] [Source] [Destination], where:
    - For Pull
      - Source: Remote website on the plesk server.  E.g. test.wildcamping.scot
      - Destination: Local site (the folder name, not the .local name.)  E.g. testwildcampingscot
    - For Push
      - Source: Local site (the folder name, not the .local name.0  E.g. testwildcampingscot
      - Destination: Remote website on the plesk server.  E.g. test.wildcamping.scot
      
 ## Flow
 
 The script does the following:
 
  1. Checks to see if what you've asked makes sense, and whether it can find the directories in question.
  2. For wp-content, asks whether this is a full run, dry run or roll-back.
  3. Executes the command (full run | dry run | roll-back) for wp-content
  4. For database sync, asks whether this is a full run, dry run or roll-back.
  5. Executes the command (full run | dry run | roll-back) for the database.
  
 ## Things to note
 
 - The roll-back attempts to return the system to the same state as it was immediately before your last command, but only to one level.
 - You can full run, dry run and roll-back each of wp-content and the database individually.  Be careful here, as during roll-back, it is pulling the backup from the last time that particular option had a full-run.  That might not be your last command.

 
