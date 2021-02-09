#!/bin/bash


STR=$(printenv | grep mysql)
SUB='mysqlx'
if [[ "$STR" != *"$SUB"* ]]; then
  echo "It's not there."

fi