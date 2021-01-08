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
        old_url=$3
        siteID=$(plesk ext wp-toolkit --list | grep $site_url | awk '{print $1;}') # Get the siteiD from plesk wp-toolkit
        plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db import db.sql # Import the database dump previously scp'd
        plesk ext wp-toolkit --wp-cli -instance-id $siteID -- search-replace $old_url $site_url # rewrite the local url to the remote url
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

if [[ $action == 'pull' ]]; then  
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
 echo "Not pushing or pulling"
 exit 1
fi

localWebsite="$thisLocalPath$localWebsiteName$localByFlywheelSubPath$serverPathSecondPart" 
# E.g. /Users/Scott/Local Sites/testwildcampingscot/app/public/wp-content/

# Detect from the remote website name whether this is a sub-domain, but counting the '.'s

count=$(awk -F"." '{print NF-1}' <<< "${remoteWebsiteName}")

if [ $count = 2 ] ; then # it's a subdomain, e.g. test.tartan.com
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


if [ "$dirExists" = false ] ; then
  echo 'Hmmm.... Remote website not found.  Exiting...'
  exit 1
else
	echo "Remote dir found.  All good..."
fi

# Get the user and group owners of the remoteWebsite dir, to make sure we set them back once we transfer
websiteChown=$(ssh $server 'bash -s' < ./tartanSync.sh chn $remoteWebsite)
echo User:Group - $websiteChown


function sanity_check {

#################################################################################################
#                                                                                               #
# function: sanityCheck                                                                        #
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
echo "Good choice.  Exitting... "
exit 1

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

if [ $action == "push" ]; then

  if [[ $run == "full-run" ]]; then

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

 elif [[ $run == "dry-run" ]]; then

  echo ""
  echo This is a DRY RUN, PUSH...

  rsync --dry-run --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "${localWebsite}" "$server:${remoteWebsite}"

else

  echo Rolling back the last push
  ssh $server rsync --owner --group --archive --compress --delete -eh "${remoteWebsite%/}_bak/" "${remoteWebsite}" 
  ssh $server chown -R "${websiteChown}" "${remoteWebsite}"

fi

    else # Pulling

      if [[ $run == "full-run" ]]; then

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

echo Syncing Dbase

if [[ $action == 'pull' ]]; then
  pullDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pullDbase $remoteDBName)
    scp -r $server:$remoteWebsite/../db.sql "${localWebsite}"..
    cd "$localWebsite"..
    wp db import db.sql 
    echo Replacing $searchreplaceOldWebsiteName with $searchreplaceNewWebsiteName
    wp search-replace $searchreplaceOldWebsiteName $searchreplaceNewWebsiteName 

  elif [[ $action == 'push' ]]; then

    runLocation=$(pwd)
    cd "$localWebsite"..
    wp db export db.sql
    scp -r db.sql $server:$remoteWebsite../db.sql 
    cd $runLocation
    pushDbaseResult=$(ssh $server 'bash -s' < ./tartanSync.sh pushDbase $remoteDBName $searchreplaceOldWebsiteName)

    successMessage='Success: Imported'
    replaceSuccessMessage='replacements'
    if [[ "$pushDbaseResult" == *"$successMessage"* ]] ; then
      echo $successMessage database
    else
      echo Failed to import
      exit
    fi
    if [[ "$pushDbaseResult" == *"$replaceSuccessMessage"* ]] ; then

      printf 'Made%s\n' "${pushDbaseResult#*Made}"
    else
      echo Failed to search and replace
      exit
    fi


  else
    exit 1
  fi





}

sanity_check
doSync
doDbaseSync


