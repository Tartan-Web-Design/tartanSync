#!/bin/bash -x

#################################################################################################
#                                                                                               # 
# TART.SH - Bash script for syncing Local to Live on Plesk.                                     #
#                                                                                               #
# Below there are a number of arrays, and each relate to the other by index.  I.e. index 0 in   #
# each array relates to the same call.                                                          #
# Therefore one call may relate to:                                                             #
#   localPath[0]                                                                                #
#   localSubPath[0]                                                                             #
#   environment [0]                                                                             #
# and so forth.                                                                                 #
#                                                                                               #   
#  Copyright Tartan Webdesign Ltd, 2020                                                         #
#                                                                                               #
#################################################################################################



# localPath is the path to the local source to rsync.  It varies by machine, and is 
# combined with localSubPath to get the full path through to wp-content.
# NB the script checks for the existence of these folders one by one; it's
# not dependent on the particular website being pulled.

localPath=( 
    "/Users/scott/Local Sites/" # Malcolm, Mac Laptop
    "/Users/Scott/Local Sites/" # Scott Laptop One <TBC>
    "/home/scott/Local Sites/" ) # Scott Laptop Two <TBC>

# localSubPath is concatenated with localPath to get the complete path to the local
# location of the files.  That is:
# localPath + localSubPath = full local path, e.g.
# "/Users/scott/Local Sites/" + "testwildcampingscot/app/public/wp-content/ = "/Users/scott/Local Sites/testwildcampingscot/app/public/wp-content/"

localSubPath=(
    "testwildcampingscot/app/public/wp-content/" 
    "tartan-live/app/public/wp-content/test/" 
    "wild/app/public/wp-content/test/"
    "tartan/app/public/wp-content/")

# environment is used to capture the index for localSubPath, serverPath and websiteChown in the following way:
#   The input variable -e is must be one of the e=${OPTARG} args in getopts below.  $e is then instantiated to that arg input.  e.g. "test"
#   The array "environment" MUST be in the same order as the options in e=${OPTARG}
#   Below is an iteration through the environment array looking for the input from -e.  
#   When it finds it, the index of the iteration is the index used to pull out the correct data from localSubPath, serverPath and websiteChown
# It therefore obviously follows that:
#   WHen adding a new site, environment and e=${OPTARG} must be updated at the same time.
#   localSubPath, serverPath and websiteChown likewise need to be updated so that the relative entry agrees with both environment and e=${OPTARG}

environment=(
    "test" 
    "tartan" 
    "wildcamping"
    "tartan-staging")

# server is invariant for the same Plesk installation.  If we ever get more than one, this script will need to be updated with an addition
# commandline arg.

server="root@165.232.110.116"

# serverPath is the path on the Plesk server listed at server, to the appropriate folder which is to be synced.
# NB that the order of this needs to be maintained with environment, as discussed above.

serverPath=(
    "/var/www/vhosts/wildcamping.scot/test.wildcamping.scot/wp-content/" 
    "/var/www/vhosts/tartanwebdesign.net/httpdocs/wp-content/test/" 
    "/var/www/vhosts/wildcamping.scot/httpdocs/wp-content/test/"
    "/var/www/vhosts/tartanwebdesign.net/staging.tartanwebdesign.net/wp-content")

# websiteChown is the user:group that the pushed folder to the server needs to be changed to in order for Plesk to have the correct priviledges to 
# server the pages.
# NB as with localSubPath and serverPath, each index needs to agree.  I.e. index 2 on all of these arrays needs to relate to the same push.

websiteChown=(
    "wildcamping:psacln" 
    "tartan:psacln" 
    "wildcamping:psacln"
    "tartan:psacln")




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


        printf "======  Answering yes to the next question will complete the operation  ======"
        
        read -p "Continue (y/n)?" choice
        case $choice in
                y|\
                Y)
                :  # Do nothing
                ;;
                *)
                    echo Exitting...
                    exit 1
                ;;
            esac
}

function getVariables {
#################################################################################################
#                                                                                               # 
# function: getVariables                                                                        #
#                                                                                               #
#  Parse the commandline inputs into global variables for use in doSync and doRollBack          #                                                                 #
#                                                                                               #
#################################################################################################


    # Based on the input variables, get the remote path on the server.

    if [ $r == "dry-run" ]; then
        run="--dry-run"
    else
        run=""
    fi

# Iterate through the environment array looking for the arg passed in under -e.
# NB we're capturing the index such that environment = -e 
# and storing it in environmentIndex for use in pulling out the appropriate array
# values in localPath, serverPath and websiteChown.

echo "{$environment[0]}"

    for i in "${!environment[@]}"; 
    do
        if [[ $e == ${environment[$i]} ]]; then
            environmentIndex=$i
        fi
    done

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

# The following is similar to the last in terms of idiot-proofing.  However,
# the correct server path is stored in serverPath, in the appropriate order.  See above for more discussion.

    thisServerPath=${serverPath[$environmentIndex]%/}'/'

echo thisServerPath = $thisServerPath
echo thisLocalPath = $thisLocalPath
echo environmentIndex = $environmentIndex

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

    if [ -z "${r}" ] || [ -z "${e}" ] || [ -z "${p}" ] || [ -z "${m}" ]; then
        usage
    fi

getVariables

# In pseudo-code, the following has this structure:
#
#   If <we're pushing>
#       If <this isn't a dry-run>
#           Quick sanity check - "are you sure?"
#           Backup on the server
#       else <this is a dry run>
#           Just say so
#       (in either case...)
#           Rsync (run or dry-run) to the server as target.  NB only difference is the contents of $run, set above
#           Chown the folder just created on the server
#       
#   else <we're pulling>
#       If <this isn't a dry-run>
#           Quick sanity check - "are you sure?"
#           Backup on the local machine
#       else <this is a dry run>
#           Just say so
#           Rsync (run or dry-run) to the local machine as target.  NB only difference is the contents of $run, set above
# 

    if [ $p == "push" ]; then

        if [[ $run == "" ]]; then

            sanity_check
            echo BACKING UP...  Source: "${thisServerPath}" Backup Location: "${thisServerPath%/}_bak"

# Backup works using rsync.  It:
#   Removes the last backup (which is in the same location as the target folder, with the extension '_bak'
#   Copies the target folder that is about to be rsynced over to the backup foler (*_bak)

            ssh -i ~/.ssh/rsync -p 22 $server rm -R "${thisServerPath%/}_bak"
            ssh -i ~/.ssh/rsync -p 22 $server rsync --owner --group --archive --compress --delete -eh "${thisServerPath}" "${thisServerPath%/}_bak"
            echo PUSHING...

        else 
            echo DRY RUN...
        fi

# This is the actual rsync that moves data between server and the local machine.
# NB $run, which toggles between a --dry-run and a full run.

        rsync $run --owner --group --archive  --compress --delete -e  "ssh -i ~/.ssh/rsync -p 22" --stats "${thisLocalPath}${localSubPath[$environmentIndex]}" "$server:${thisServerPath}"

# chown make the pushed files available to Plesk.  Without this step, everything's borked.

        echo Running Chown on Destination...
        ssh -i ~/.ssh/rsync -p 22 $server chown -R "${websiteChown[$environmentIndex]}" "${thisServerPath}"
    
    else # Pulling

        if [[ $run == "" ]]; then
        
            sanity_check

            echo BACKING UP...  Source: "${thisLocalPath}${localSubPath[$environmentIndex]}" Backup Location: "${thisLocalPath}${localSubPath[$environmentIndex]%/}_bak"

# Take a local backup.  Exactly as discussed above for the push, only in reverse.  I.e. the _bak folder is in the same location as the folder being pulled
# to on the local machine.

            rsync --owner --group --archive --compress --delete -eh "${thisLocalPath}${localSubPath[$environmentIndex]}" "${thisLocalPath}${localSubPath[$environmentIndex]%/}_bak" 
            echo PULLING...
 
        else 
            echo DRY RUN...
        fi
# This is the actual rsync that moves data between server and the local machine.
# NB $run, which toggles between a --dry-run and a full run.

        rsync $run --owner --group --archive --compress --delete  -e  "ssh -i ~/.ssh/rsync -p 22" --stats "$server:${thisServerPath}" "${thisLocalPath}${localSubPath[$environmentIndex]}" 
    fi


}


function doRollBack {

#################################################################################################
#                                                                                               # 
# function: doRollBack                                                                          #
#                                                                                               #          
#  Called when -m input arg (ie, mode) is set to 'rollback' rather than 'sync'.                 #                                                           
#                                                                                               #
#  Previously, a folder was created in the same location as the folder being sync'd             #
#  with the extension '_bak'.  E.g. syncing wp_content results in wp_content_bak in             #
#  the same location.                                                                           #   
#                                                                                               #  
#  NB, only the previous full run rsync generates a _bak folder.  That is, it's an undo with    #  
#  one level, and is only intended for those "Oh fuck" moments.                                 #    
#                                                                                               #  
#  Calling this function therefore engaged "Oh fuck", and rollsback one level                   #
#                                                                                               #  
#################################################################################################

# If all the required parameters aren't passed in, return the "usage" help as output

    if [ -z "${r}" ] || [ -z "${e}" ] || [ -z "${p}" ] || [ -z "${m}" ]; then
        usage
    fi

    echo Rolling back: "${r}" "${e}" "${p}"

    getVariables

    if [[ $r == "run" ]]; then

        if [ $p == "push" ]; then
            echo ROLLING BACK...  Backup Location: "${thisServerPath%/}_bak" Target: "${thisServerPath}" 
            sanity_check
            ssh -i ~/.ssh/rsync -p 22 $server rm -R "${thisServerPath%/}"
            ssh -i ~/.ssh/rsync -p 22 $server mv "${thisServerPath%/}_bak" "${thisServerPath%/}"
            ssh -i ~/.ssh/rsync -p 22 $server chown -R "${websiteChown[$environmentIndex]}" "${thisServerPath}"

        else # Pull
            echo ROLLING BACK...  Backup Location: "${thisLocalPath}${localSubPath[$environmentIndex]%/}_bak" Target: "${thisLocalPath}${localSubPath[$environmentIndex]}"
            sanity_check
            rm -R "${thisLocalPath}${localSubPath[$environmentIndex]}"
            mv "${thisLocalPath}${localSubPath[$environmentIndex]%/}_bak" "${thisLocalPath}${localSubPath[$environmentIndex]}"
        fi

    else
        echo Nothing to do - you can\'t rollback on a dry-run...
    fi

}

#################################################################################################
#                                                                                               # 
# function: main                                                                                #
#                                                                                               #     
#  Parse the input args                                                                         #  
#  Set the variables,                                                                           #   
#  Show the usage and exit or,                                                                  #  
#  Call the appropriate action.                                                                 #     
#                                                                                               #     
#################################################################################################


# Pull in and parse the command line variables
# 

usage() { echo "Usage: $0 [-r <run|dry-run>] [-e <test|tartan|wildcamping>] [-p <push|pull>]" 1>&2; exit 1; }

while getopts ":r:e:p:m:" o; do
    case "${o}" in
        r)
            r=${OPTARG}
            case $r in
                run|\
                dry-run)
                :  # Do nothing
                ;;
                *)
                    usage
                    exit 1
                ;;
            esac
            ;;
        p)
            p=${OPTARG}
            case $p in
                push|\
                pull)
                :  # Do nothing
                ;;
                *)
                    usage
                    exit 1
                ;;
            esac
            ;;
        e)
            e=${OPTARG}
			case $e in
  				test|\
                tartan|\
  				wildcamping|\
  				tartan-staging)
    			:  # Do nothing
    			;;
  				*)
    				usage
    				exit 1
    			;;
			esac
            ;;
        m)
            m=${OPTARG}
            case $m in
                sync)
                    doSync
                :  # Do nothing
                ;;
                rollback)
                    doRollBack
                :  # Do nothing
                ;;
                *)
                    usage
                    exit 1
                ;;
            esac
            ;;

            
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))


