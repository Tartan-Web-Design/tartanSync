#!/bin/bash

site_url=$1

echo $1 

siteID=$(plesk ext wp-toolkit --list | grep $site_url | awk '{print $1;}')
echo $siteID
plesk ext wp-toolkit --wp-cli -instance-id $siteID -- db export NEWdb.sql
