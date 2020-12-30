#!/bin/bash 

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


server="root@165.232.110.116"

if [ $# -lt 3 ]
	then
		if [ $1 == "path" ] 
			then
				if [[ -d $2 ]]
					then
    					echo "true"
					else
						echo "false"
				fi
				exit
			elif [ $1 == "chn" ] 
				then 
		 			USER=$(stat -c '%U' $2)
		 			GROUP=$(stat -c '%G' $2)
     				echo "$USER:$GROUP"
				exit
			else
	    		usage
    	fi
  	else
  		action=$1
fi



localPath=(
    "/Users/scott/Local Sites/" # Malcolm, Mac Laptop
    "/Users/Scott/Local Sites/" # Scott Laptop One <
    "/home/scott/Local Sites/"  # Scott Laptop Two
    "/home/scott/Local Sites/" ) # Malcolm Laptop Two

localByFlywheelSubPath='/app/public/wp-content/test/';
serverPathFirstPart="/var/www/vhosts/";
serverPathSecondPart="/wp-content/test/";
serverPrimaryPathPart="/httpdocs";


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
  			echo "Pulling... "
  		remoteWebsiteName=$2
		localWebsite="$thisLocalPath$3$localByFlywheelSubPath"
	elif [[ $action == 'push' ]]; then
		  	echo "Pushing... "
  		remoteWebsiteName=$3
		localWebsite="$thisLocalPath$2$localByFlywheelSubPath"
	else
  			echo "Not pushing or pulling"
  		exit 1
	fi


char="."

count=$(awk -F"." '{print NF-1}' <<< "${remoteWebsiteName}")

if [ $count = 2 ] ; then
	primaryDomain=$(echo $remoteWebsiteName | sed 's/^[^.]*.//g')
	remoteWebsiteName=$primaryDomain/$remoteWebsiteName
else
	remoteWebsiteName="$remoteWebsiteName$serverPrimaryPathPart"
fi

remoteWebsite="$serverPathFirstPart$remoteWebsiteName$serverPathSecondPart"





  	if [[ $action == 'pull' ]]; then
  		echo "Pulling $remoteWebsite to $localWebsite"
	elif [[ $action == 'push' ]]; then
  		echo "About to push:"
  		echo "   $localWebsite to"
  		echo "   $remoteWebsite"
	else
  		echo "Not pushing or pulling"
	fi

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

websiteChown=$(ssh $server 'bash -s' < ./tartanSync.sh chn $remoteWebsite)


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
#  Called when -m input arg (ie, mode) is set to sync rather than rollback.                     #
#  NB this does not necessarily mean that the folders will be synced, as the combination        #
#  sync + dry-run is valid.                                                                     #
#                                                                                               #
#  Therefore distinct only from doRollBack                                                      #
#                                                                                               #
#################################################################################################

# If all the required parameters aren't passed in, return the "usage" help as output

    if [ $action == "push" ]; then

        if [[ $run == "full-run" ]]; then
            	echo This is a FULL RUN, PUSH...
            	echo BACKING UP first...  
            	echo Source: "${remoteWebsite}" 
            	echo Backup Location: "${remoteWebsite%/}_bak"
            ssh -i ~/.ssh/rsync -p 22 $server rsync --owner --group --archive --compress --delete -eh "${remoteWebsite}" "${remoteWebsite%/}_bak"
            	echo ""
            	echo Backup done...
				echo Rsyncing...
         	rsync --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "${localWebsite}" "$server:${remoteWebsite}"
        	ssh -i ~/.ssh/rsync -p 22 $server chown -R "${websiteChown}" "${remoteWebsite}"

        elif [[ $run == "dry-run" ]]; then
        		echo ""
            	echo This is a DRY RUN, PUSH...
			rsync --dry-run --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "${localWebsite}" "$server:${remoteWebsite}"
        else
        		echo Rolling back the last push
        	ssh -i ~/.ssh/rsync -p 22 $server rm -R "${remoteWebsite%/}"
            ssh -i ~/.ssh/rsync -p 22 $server mv "${remoteWebsite%/}_bak" "${remoteWebsite%/}"
            ssh -i ~/.ssh/rsync -p 22 $server chown -R "${websiteChown}" "${remoteWebsite}"

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
        	rm -R "${localWebsite}"
            mv "${localWebsite%/}_bak" "${localWebsite%/}"
 
        fi
    fi


}




sanity_check
doSync



