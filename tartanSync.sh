#!/bin/bash 

#################################################################################################
#                                                                                               #
# TartanSync                                                                                    #
#                                                                                               #
# Copies the contents of wp-content from a Local wordpress installation to a plesk installation #
# and vice versa.                                                                               #
#                                                                                               #                                                                                              #
# Also carries out a mysqldump of the database, and a search and replace on the site name.      #
#                                                                                               #
# It assumes that the local environment has wp-cli installed and can access it using "wp"       #
#                                                                                               #
#################################################################################################


usage() { 
  echo ""
  echo "##############################################################################"
  echo ""
  echo "Welcome to tartanSync, but you seem to have done something wrong"
  echo ""
  echo Try this:
  echo ""
  echo "Usage: bash tartanSync.sh [<pull|push>] [Source] [Destination]"
  echo ""
  echo "E.g. bash tartanSync.sh pull websiteOnPlesk.com localByFlywheelWebsite"
  echo ""
  echo "Or..."
  echo ""
  echo "E.g. bash tartanSync.sh push localByFlywheelWebsite websiteOnPlesk.com"
  echo ""
  echo "##############################################################################"
  echo ""

  exit 1; }


server="root@165.232.110.116" # The address of the plesk server, which will be accessed using ssh and scp

localPath=(
    "/Users/scott/Local Sites/" # Malcolm, Mac Laptop
    "/Users/Scott/Local Sites/" # Scott Laptop One 
    "/home/scott/Local Sites/"  # Scott Laptop Two
    "/home/scott/Local Sites/" ) # Malcolm Laptop Two

localByFlywheelSubPath='/app/public';
serverPathFirstPart="/var/www/vhosts/";
serverPathSecondPart="/wp-content/";
serverPrimaryPathPart="/httpdocs";

# tartanSync is recursive, calling itself for some of the remote function calls.  In order to 
# achieve this, it passes through some args to itself as followsL



if [ $1 == "path" ] # Check to find out if the remote directory in arg 2 exists.
  then
    if [[ -d $2 ]]
      then
        echo "true"
      else
        echo "false"
    fi
    exit
  elif [ $1 == "pullDbase" ] # Actions to take on the remote plesk server to pull the database
    then 
      site_url=$2
      siteID=$(plesk ext wp-toolkit --list | grep $site_url | awk '{print $1;}') # Get the siteiD from plesk wp-toolkit
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db export db.sql # Use that ID to export the database.
      exit
  elif [ $1 == "pushDbase" ] # Actions to take on the remote plesk server to push the database to plesk and search/replace
    then 
      site_url=$2
      prefix='https://'
      old_url=$3
      siteID=$(plesk ext wp-toolkit --list | grep $site_url | awk '{print $1;}') # Get the siteiD from plesk wp-toolkit
      new_site_url=${site_url#"$prefix"}

      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db export db_bak.sql # Create the backup
      wait
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db import db.sql # Import the database dump previously scp'd
      wait
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- search-replace $old_url $new_site_url # rewrite the local url to the remote url
      wait
      rm db.sql
      exit
  elif [ $1 == "pushDbaseDryRun" ] # Actions to take on the remote plesk server to push the database to plesk and search/replace
    then 
      site_url=$2
      prefix='https://'
      old_url=$3
      siteID=$(plesk ext wp-toolkit --list | grep $site_url | awk '{print $1;}') # Get the siteiD from plesk wp-toolkit
      site_url=${site_url#"$prefix"}
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db export db_dryrun.sql
      wait
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db import db.sql # Import the database dump previously scp'd
      wait
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- search-replace $old_url $site_url --dry-run # rewrite the local url to the remote url
      wait
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db import db_dryrun.sql
      wait
      rm db_dryrun.sql
      exit
  elif [ $1 == "pushDbaseRollback" ] # Actions to take on the remote plesk server to push the database to plesk and search/replace
    then 
      site_url=$2
      old_url=$3
      siteID=$(plesk ext wp-toolkit --list | grep $site_url | awk '{print $1;}') # Get the siteiD from plesk wp-toolkit
      plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db import db_bak.sql
      exit
  elif [ $1 == "chn" ] # Get the user and group of wp-content on plesk
    then 
      USER=$(stat -c '%U' $2)
      GROUP=$(stat -c '%G' $2)
      echo "$USER:$GROUP"
      exit
  elif [ $# -ne 3 ] # Catchall 
    then 
      usage
  else # at this point we have three args, as per usage.
    action=$1
fi

# Check to see if mysql is available in this term on local
STR=$(printenv | grep mysql)
SUB='mysql'
if [[ "$STR" != *"$SUB"* ]]; then
  echo "You don't have mysql available in ENV.  You'll be needing that..."
  echo "Because I'm helpful, here's the command:"
  echo "export PATH=${PATH}:/usr/local/mysql/bin/ && source ~/.zshrc"
  echo "and oh, you do have mysql installed right ;-)"
  exit
fi
# Check to see if wp-cli is available in this term on local
STR=$(wp | grep WordPress)
SUB='WordPress'
if [[ "$STR" != *"$SUB"* ]]; then
  echo "You don't have wp-cli installed and/or aliased to wp.  You'll be needing that..."
  echo "Here's where to find the how-to..."
  echo "https://wp-cli.org/"
  echo "But in case that site goes offline, here are the commands:"
  echo "First, download it:"
  echo "   curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
  echo "Then, check it's installed by:"
  echo "   php wp-cli.phar --info"
  echo "If it is, then make it executable:"
  echo "   chmod +x wp-cli.phar"
  echo "Then move it to binaries:"
  echo "   sudo mv wp-cli.phar /usr/local/bin/wp"
  echo "Finally check it again by:"
  echo "   wp --info"
  exit
fi

# Test for the existence of each entry in localPath on the machine the script is running on.
# Then, as a belt a braces move, remove the last character of that path if it's a '/', but not otherwise,
# then add a '/' to the end var.
# The result is that if we forget to add '/' where rsync requires it, this will capture that mistake and
# fix it for us, leaving us fat, dumb and happy (and with a working script.)

for i in "${!localPath[@]}";
  do
    if [[ -d ${localPath[$i]} ]]; then
      thisLocalPath=${localPath[$i]%/}'/'
    fi
done


# Deal with the special case of sub-domains, and plesk having a different path for those.

if [[ $action == 'pull' ]]; 
  then  
    # E.g. tartanSync % tartanSync pull test.wildcamping.scot testwildcampingscot
    echo "Pulling... "
    remoteWebsiteName=$2
    localWebsiteName=$3
    remoteDBName=$2    
    searchreplaceOldWebsiteName=$2
    searchreplaceNewWebsiteName="$3.local"
  elif [[ $action == 'push' ]]; then 
    # E.g. tartanSync push testwildcampingscot test.wildcamping.scot
    echo "Pushing... "
    remoteWebsiteName=$3
    localWebsiteName=$2
    remoteDBName=$3
    searchreplaceOldWebsiteName="$2.local"
    searchreplaceNewWebsiteName=$3
  else
    echo "You sure you typed that right?  You haven't asked for a push or a pull..."
    exit 1
fi

localWebsite="$thisLocalPath$localWebsiteName$localByFlywheelSubPath$serverPathSecondPart" 
# E.g. /Users/Scott/Local Sites/testwildcampingscot/app/public/wp-content/




# Detect from the remote website name whether this is a sub-domain, but counting the '.'s

count=$(awk -F"." '{print NF-1}' <<< "${remoteWebsiteName}")

if [ $count = 2 ] ; 
  then # it's a subdomain, e.g. test.tartan.com
    primaryDomain=$(echo $remoteWebsiteName | sed 's/^[^.]*.//g')
    remoteWebsiteName=$primaryDomain/$remoteWebsiteName
  else # it's a domain, e.g. tartan.com
    remoteWebsiteName="$remoteWebsiteName$serverPrimaryPathPart"
fi

remoteWebsite="$serverPathFirstPart$remoteWebsiteName$serverPathSecondPart"  
# e.g. /var/www/vhosts/wildcamping.scot/test.wildcamping.scot/wp-content/

# Tell the user what you're about to do
if [[ $action == 'pull' ]]; then
  echo "Pulling $remoteWebsite to $localWebsite"
elif [[ $action == 'push' ]]; then
  echo "About to push:"
  echo "   $localWebsite to"
  echo "   $remoteWebsite"
else
  echo "Not pushing or pulling"
fi


# Check to see if both the local directory and the remote directory actually exist.  If they don't exit.
if [[ -d $localWebsite ]]
  then
    echo "Local dir found.  All good..."
  else
    echo "Hmmm....  Local dir not found.  Exiting"
    exit 1
fi

dirExists=$(ssh $server 'bash -s' < ./tartanSync.sh path $remoteWebsite)


if [ "$dirExists" = false ] ; 
  then
    echo 'Hmmm.... Remote website not found.  Exiting...'
    exit 1
  else
    echo "Remote dir found.  All good..."
fi


# Check to see if the table_prefix remote and locally are the same.  Warn and exit if not.
table_prefix_local=$(grep table_prefix < "${localWebsite}"../wp-config.php)
table_prefix_remote=$(ssh $server grep table_prefix "${remoteWebsite}"../wp-config.php)

if [[ "$table_prefix_local" != "$table_prefix_remote" ]]; then
    echo "***************************************************************************"
    echo "Mismatch between the table_prefixes in remote and local wp-config.php files."
    echo "Better to be safe than sorry, so halting this now so it can be fixed."
    echo "Here are the values:"
    echo "   On the remote server, this was found:"
    echo "      $table_prefix_remote"
    echo "   And on the local server, this was found:"
    echo "      $table_prefix_local"
    echo "***************************************************************************"
    exit
fi

# Check to see if the local wp-config.php has a mysqld.sock set for this site
mysqld_sock=$(grep DB_HOST < "${localWebsite}"../wp-config.php)
if [[ $mysqld_sock != *"mysqld.sock"* ]]; then
  echo "***************************************************************************"
  echo "You haven't set the mysqld sock, have you..."
  echo "OK, the instructions are in github readme, here's the link:"
  echo "https://github.com/Tartan-Web-Design/tartanSync"
  echo "But essentially, you need to:"
  echo "  1. Go to the Local app,"
  echo "  2. Press the (i) next to PHP Version"
  echo "  3. Find the line under Loaded Configuration File"
  echo "  4. Copy the string between /run/ and /conf/ (should look like random characters"
  echo "  5. Go the wp-config.php, and find the line that looks like:"
  echo "      define( 'DB_HOST', 'localhost' );"
  echo "  6. And replace it with this line:"
  echo "      define( 'DB_HOST', 'localhost:/Users/scott/Library/Application Support/Local/run/XXXXXXX/mysql/mysqld.sock' );"
  echo "  where XXXXXXX is the string from step (4)"
  echo "It just needs done once, at the creation of each new local site"
  echo "***************************************************************************"
  exit
fi

# Check to see if the remote site has SSL enabled 
# remote_https_check=$(curl -s https://$remoteDBName)
# if [[ $remote_https_check != *"https://$remoteDBName"* ]]; then
#   echo "***************************************************************************"
#   echo "Just checked the remote site there - doesn't have SSL enabled"
#   echo "   OR it's not running"
#   echo "   OR Wordpress isn't installed"
#   echo "Could you sort that out first please."
#   echo "I need both sides to have SSL later in the process"
#   echo "Ta"
#   echo "***************************************************************************"
#   exit
# fi

# Check to see if the local site has SSL enabled 

# local_https_check=$(curl -s https://$localWebsiteName.local)
# if [[ $local_https_check != *"https://$localWebsiteName.local"* ]]; then
#   echo "***************************************************************************"
#   echo "Just checked the local site there - doesn't have SSL enabled"
#   echo "   OR it's not running"
#   echo "   OR Wordpress isn't installed"
#   echo "Could you sort that out first please."
#   echo "I need both sides to have SSL later in the process"
#   echo "Ta"
#   echo "***************************************************************************"
#   exit
# fi

# Get the user and group owners of the remoteWebsite dir, to make sure we set them back once we transfer
websiteChown=$(ssh $server 'bash -s' < ./tartanSync.sh chn $remoteWebsite)
echo User:Group - $websiteChown


function sanity_check_WPContent {

#################################################################################################
#                                                                                               #
# function: sanityCheckWPContent                                                                #
#                                                                                               #
#  A function which provides a command line check whenever something is actually being          #
#  written.  Called for both pull and push.  Anything other than full-throated agreement        #
#  results in the script exitting.                                                              #
#                                                                                               #
#################################################################################################

  echo ""
  echo "========================================================="
  echo "======  IS THIS A DRY RUN, FULL RUN or ROLL BACK?  ======"
  echo "========================================================="
  echo ""

  syncWPContent=true

  read -p "Choose carefully (or hit return to skip):  (d/f/r)? " choice
  case $choice in
    d|D)
      run="dry-run"
    ;;
    f|F)
      run="full-run"
    ;;
    r|R)
      run="roll-back"
    ;;
  *)
      echo "OK, not syncing the wp-content folder... "
      syncWPContent=false
    ;;
  esac
}

function sanity_check_Dbase {

#################################################################################################
#                                                                                               #
# function: sanityCheckDbase                                                                    #
#                                                                                               #
#  A function which provides a command line check whenever something is actually being          #
#  written.  Called for both pull and push.  Anything other than full-throated agreement        #
#  results in the script exitting.                                                              #
#                                                                                               #
#################################################################################################

  echo ""
  echo "========================================================="
  echo "======  DO YOU WANT TO SYNC THE DATABASE ?         ======"
  echo "========================================================="
  echo ""

  syncDbase=true

  read -p "Choose carefully (or hit return to exit):  (d/f/r)? " choice
  case $choice in
    d|D)
      run="dry-run"
    ;;
    f|F)
      run="full-run"
    ;;
    r|R)
      run="roll-back"
    ;;
  *)
      echo "OK, not syncing the database... "
      syncDbase=false
    ;;
  esac
}



function doSync {

#################################################################################################
#                                                                                               #
# function: doSync                                                                              #
#                                                                                               #
#  Called push and pull (not rollback)
#                                                                                               #
#################################################################################################

  if [ $action == "push" ]; 
    then
      if [[ $run == "full-run" ]]; 
        then
          echo This is a FULL RUN, PUSH...
          echo BACKING UP first...  
          echo Source: "${remoteWebsite}" 
          echo Backup Location: "${remoteWebsite%/}_bak"

          ssh $server rsync --owner --group --archive --compress --delete -eh "${remoteWebsite}" "${remoteWebsite%/}_bak"

          echo ""
          echo Backup done...
          echo Rsyncing...

          rsync --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "${localWebsite}" "$server:${remoteWebsite}"
          ssh $server chown -R "${websiteChown}" "${remoteWebsite}"

      elif [[ $run == "dry-run" ]]; 
        then

          echo ""
          echo This is a DRY RUN, PUSH...

          rsync --dry-run --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "${localWebsite}" "$server:${remoteWebsite}"

      else

        echo Rolling back the last push
        ssh $server rsync --owner --group --archive --compress --delete -eh "${remoteWebsite%/}_bak/" "${remoteWebsite}" 
        ssh $server chown -R "${websiteChown}" "${remoteWebsite}"

      fi

    else # Pulling

      if [[ $run == "full-run" ]]; 
        then

          echo FULL RUN, PULL...
          echo BACKING UP...  Source: "${localWebsite}" Backup Location: "${localWebsite%/}_bak"

          rsync --owner --group --archive --compress --delete -eh "${localWebsite}" "${localWebsite%/}_bak"

          echo PULLING...

          rsync --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "$server:${remoteWebsite}" "${localWebsite}"

      elif [[ $run == "dry-run" ]]; then

        echo ""
        echo This is a DRY RUN, PULL...

        rsync --dry-run --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "$server:${remoteWebsite}" "${localWebsite}"

      else

        echo Rolling back the last pull
        rsync --owner --group --archive --compress --delete -eh "${localWebsite%/}_bak/" "${localWebsite}" 
    fi
  fi

}

function doDbaseSync {

#################################################################################################
#                                                                                               #
# function: doDbaseSync                                                                        #
#                                                                                               #
#                                                                                               #
#################################################################################################

if [[ $action == 'pull' ]]; 
  then
    if [[ $run == "full-run" ]]; 
      then

        echo Syncing Dbase 
        pullDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pullDbase https://$remoteDBName)
        scp -r $server:$remoteWebsite/../db.sql "${localWebsite}"..
        cd "$localWebsite"..
        wp db export db_bak.sql
        wp db import db.sql 
        echo Search and Replace - Replacing $searchreplaceOldWebsiteName with $searchreplaceNewWebsiteName
        wp search-replace $searchreplaceOldWebsiteName $searchreplaceNewWebsiteName 

    elif [[ $run == "dry-run" ]]; 
      then
        echo Dry Run Sync of Dbase 
        pullDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pullDbase https://$remoteDBName)
        scp -r $server:$remoteWebsite/../db.sql "${localWebsite}"..
        cd "$localWebsite"..
        wp db export db_dryrun.sql
        wp db import db.sql 
        echo Dry-run replacing $searchreplaceOldWebsiteName with $searchreplaceNewWebsiteName
        wp search-replace $searchreplaceOldWebsiteName $searchreplaceNewWebsiteName --dry-run
        wp db import db_dryrun.sql
        rm db_dryrun.sql
        rm db.sql
    else
        echo Rollback of Local Dbase 
        cd "$localWebsite"..
        wp db import db_bak.sql
    fi

  elif [[ $action == 'push' ]]; 
    then
      if [[ $run == "full-run" ]]; 
        then
          echo Syncing Dbase 
          runLocation=$(pwd)
          cd "$localWebsite"..
          wp db export db.sql
          scp -r db.sql $server:$remoteWebsite../db.sql 
          cd $runLocation
          echo cd $runLocation
          echo $remoteDBName $searchreplaceOldWebsiteName
          pushDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pushDbase https://$remoteDBName $searchreplaceOldWebsiteName)
          echo pushDbaseResult $pushDbaseResult
          successMessage='Success: Imported'
          replaceSuccessMessage='replacements'
          if [[ "$pushDbaseResult" == *"$successMessage"* ]] ; 
            then
              echo $successMessage database
          else
              echo Failed to import
              exit
          fi
    
          if [[ "$pushDbaseResult" == *"$replaceSuccessMessage"* ]] ; 
            then

              printf '%s\n' "${pushDbaseResult}"
            else
              echo Failed to search and replace
              exit
          fi
      elif [[ $run == "dry-run" ]]; 
        then
          echo Dry Run Sync of Remote Dbase 

          runLocation=$(pwd)
          cd "$localWebsite"..
          wp db export db.sql
          scp -r db.sql $server:$remoteWebsite../db.sql 
          cd $runLocation
          echo ABOUT TO DRY-RUN 
          pushDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pushDbaseDryRun https://$remoteDBName $searchreplaceOldWebsiteName)

          successMessage='Success: Imported'
          replaceSuccessMessage='replacements'
          if [[ "$pushDbaseResult" == *"$successMessage"* ]] ; 
            then
              echo $successMessage database
          else
              echo Failed to import
              exit
          fi
          if [[ "$pushDbaseResult" == *"$replaceSuccessMessage"* ]] ; 
            then

              printf '%s\n' "${pushDbaseResult}"
          else
              echo Failed to search and replace
              exit
          fi

      else
          echo Rollback of Remote Dbase 
          pushDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pushDbaseRollback $remoteDBName $searchreplaceOldWebsiteName)
          printf '%s\n' "${pushDbaseResult}"
      fi

  else
      exit 1
  fi

}

sanity_check_WPContent
if [ $syncWPContent == true ]; 
  then
    doSync
fi

sanity_check_Dbase

if [ $syncDbase == true ]; 
  then
    doDbaseSync
fi


