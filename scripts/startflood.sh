#!/bin/bash

# Shell Script to launch a Flood using Azure Devops
# Written and Developed by Jason Rizio (jason@flood.io)
# 5th May, 2021

# This is free software; see the source for copying conditions. There is NO
# warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

set -e  # exit script if any command returnes a non-zero exit code.
# set -x  # display every command.

MY_FLOOD_TOKEN="<FLOOD API TOKEN HERE>"
echo -e ">>> MY_FLOOD_TOKEN is: $MY_FLOOD_TOKEN"

#function write to stderr if we need to report a fail
echoerr() { echo "$@" 1>&2; }

FLOOD_SLEEP_SECS="10"
FLOOD_API_FLOODS_URL="https://api.flood.io/api/floods"
FLOOD_PROJECT="azure-devops"
FLOOD_NAME="myAzureTest-shellscript"

# PROTIP: use environment variables to pass links to where the secret is really stored: use an additional layer of indirection.
# From https://app.flood.io/account/user/security
if [ -z "$MY_FLOOD_TOKEN" ]; then
   echo -e "\n>>> MY_FLOOD_TOKEN not available. Exiting..."
   exit 9
else
   echo -e "\n>>> MY_FLOOD_TOKEN available. Continuing..."
fi

  # [1.] Launch the Flood via API call
  launch=$(curl -su ${MY_FLOOD_TOKEN}: \
  -X POST ${FLOOD_API_FLOODS_URL} \
  -F "flood[tool]=jmeter" \
  -F "flood[threads]=10" \
  -F "flood[rampup]=30" \
  -F "flood[duration]=120" \
  -F "flood[privacy]=public" \
  -F "flood[name]=${FLOOD_NAME}" \
  -F "flood[tag_list]=ci,shakeout" \
  -F "flood_files[]=@scripts/jmeter/002_MCI.jmx" \
  -F "flood_files[]=@scripts/jmeter/MCI.csv" \
  -F "flood[grids][][infrastructure]=demand" \
  -F "flood[grids][][instance_quantity]=1" \
  -F "flood[grids][][region]=us-west-2" \
  -F "flood[grids][][instance_type]=m5.xlarge" \
  -F "flood[grids][][stop_after]=15" | jq -r ".uuid" )
  

   #-F "flood_files[]=@specs/baseline.ts"
   echo -e "Launch: $launch"

   MY_FLOOD_UUID=$launch
   if [ -z "$MY_FLOOD_UUID" ]; then
    echo -e "\n>>> MY_FLOOD_UUID was not returned. Error: '$launch'"
    echo -e "\n\nExiting..."
    exit 9
   else
    echo -e "\n>>> MY_FLOOD_UUID was returned successfully ($MY_FLOOD_UUID). Continuing..."
   fi

   #Login=$(curl -X POST https://api.flood.io/oauth/token -F 'grant_type=password' -F 'username=$FLOOD_USERNAME' -F 'password=$FLOOD_PASSWORD') #required username and password
   #echo -e "Login: $Login"

   #Token=$(echo $Login | jq -r '.access_token')
   #Patch=$(curl -X PATCH https://api.flood.io/api/v3/floods/$MY_FLOOD_UUID/set-public -H 'Authorization: Bearer '$Token -H 'Content-Type: application/json')

   #echo -e "Token: $Token"
   #echo -e "Patch: $Patch"

   # [2.] Display Grid status
   echo -e "\n>>> [$(date +%FT%T)+00:00] Checking Grid status ... "
   grid_uuid=$(curl --silent --user $MY_FLOOD_TOKEN: -X GET https://api.flood.io/floods/$MY_FLOOD_UUID | jq -r "._embedded.grids[0].uuid" )
   echo -e "\n>>> [$(date +%FT%T)+00:00] Grid UUID: $grid_uuid"
   echo -e "\n>>> [$(date +%FT%T)+00:00] Waiting for Grid to become available ..."
   while [ $(curl --silent --user $MY_FLOOD_TOKEN: -X GET https://api.flood.io/grids/$grid_uuid | jq -r '.status == "started"') = "false" ]; do
     sleep "$FLOOD_SLEEP_SECS"
   done

   # [3.] Display Flood status
   echo -e "\n>>> [$(date +%FT%T)+00:00] Flood is currently running ... waiting until finished ..."
   while [ $(curl --silent --user $MY_FLOOD_TOKEN: -X GET https://api.flood.io/floods/$MY_FLOOD_UUID | jq -r '.status == "finished"') = "false" ]; do
     sleep "$FLOOD_SLEEP_SECS"
   done

   # [4.] Retrieve the Flood Summary Report
   echo -e "\n>>> [$(date +%FT%T)+00:00] Flood has finished ... Getting the summary report ..."
   flood_report=$(curl --silent --user $MY_FLOOD_TOKEN:  -X GET https://api.flood.io/floods/$MY_FLOOD_UUID/report | jq -r ".summary" )
   
   # [5.] Retrieve the mean_error_rate
   echo -e "\n>>> [$(date +%FT%T)+00:00] Getting the mean error rate ..."
   flood_error_rate=$(curl --silent --user $MY_FLOOD_TOKEN:  -X GET https://api.flood.io/floods/$MY_FLOOD_UUID/report | jq -r ".mean_error_rate" )

   #echo -e "\n>>> [$(date +%FT%T)+00:00] Detailed results at https://api.flood.io/floods/$MY_FLOOD_UUID"

   echo "Flood Summary Report: $flood_report"  # summary report
   echo "Flood Mean Error Rate: $flood_error_rate"  # summary report

   # [6.] Verify our SLA for 0 failed transactions
   if [ `echo $flood_error_rate | grep -c "0" ` -gt 0 ]
   then
     echo "FLOOD PASSED: The Flood ran with 0 Failed transactions." 
   else
     echoerr "FLOOD FAILED: The Flood encountered Failed transactions."
   fi
