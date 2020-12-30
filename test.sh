#!/bin/bash

string="staging.tartan.net"
char="."



count=$(awk -F"${char}" '{print NF-1}' <<< "${string}")


if [ $count = 2 ] ; then
	echo yea
	result=$(echo $string | sed 's/^[^.]*.//g')
	echo $result
else
	echo no
fi