#!/bin/bash
set -e

command -v jq >/dev/null 2>&1 || { echo >&2 "Please install http://stedolan.github.io/jq/download/  Aborting."; exit 1; }
 
 
echo "[$(date +%FT%T)+00:00] Starting grid"
grid_uuid=`curl -X POST --silent --user ${FLOOD_API_TOKEN}: https://api.flood.io/grids \
 -F "grid[infrastructure]=demand" \
 -F "grid[instance_quantity]=1" \
 -F "grid[region]=ap-southeast-2" \
 -F "grid[stop_after]=60" | jq -r ".response.uuid"`
 
 while [ `curl --silent --user ${FLOOD_API_TOKEN}: https://api.flood.io/grids/${grid_uuid} | \
  jq -r '.response.status == "started"'` = "false" ]; do
  echo -n "."
  sleep 3
done

echo
  
echo "[$(date +%FT%T)+00:00] Starting flood on grid ${grid_uuid}"
flood_uuid=`curl -X POST --silent --user ${FLOOD_API_TOKEN}: https://api.flood.io/floods \
 -F "flood[tool]=jmeter-2.13" \
 -F "flood[threads]=10" \
 -F "flood[privacy]=public" \
 -F "flood[name]=Build New" \
 -F "flood[notes]=Build Notes" \
 -F "flood[tag_list]=ci,load" \
 -F "flood_files[]=@scripts/jmeter/002_MCI.jmx" \
 -F "flood_files[]=@scripts/jmeter/MCI.csv" \
 -F "grid=${grid_uuid}" \
 -F "region=ap-southeast-2" | jq -r ".response.uuid"`
 
 echo "[$(date +%FT%T)+00:00] Waiting for flood to finish ${flood_uuid}"
while [ `curl --silent --user ${FLOOD_API_TOKEN}: https://api.flood.io/floods/${flood_uuid} | \
  jq -r '.response.status == "finished"'` = "false" ]; do
  echo -n "."
  sleep 3
done
