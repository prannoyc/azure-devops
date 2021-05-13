#!/bin/bash
set -e

# Check we have the jq binary to make parsing JSON responses a bit easier
command -v jq >/dev/null 2>&1 || \
{ echo >&2 "Please install http://stedolan.github.io/jq/download/  Aborting."; exit 1; }

# Start a flood
echo
echo "[$(date +%FT%T)+00:00] Starting flood"
flood_uuid=$(curl -u flood_live_34692b03460e8d12544b01ddc7524b2335ef5e32ba: -X POST https://api.flood.io/floods \
-F "flood[tool]=jmeter" \
-F "flood[threads]=5" \
-F "flood[project]=Default" \
-F "flood[privacy]=public" \
-F "flood[name]=CI Shakeout" \
-F "flood_files[]=@scripts/jmeter/MCI.csv" \
-F "flood_files[]=@scripts/jmeter/002_MCI.jmx" \
-F "flood[grids][][infrastructure]=demand" \
-F "flood[grids][][instance_quantity]=1" \
-F "flood[grids][][region]=us-west-2" \
-F "flood[grids][][instance_type]=m5.xlarge" \
-F "flood[grids][][stop_after]=15" | jq -r ".uuid")

echo "flood launched"

# Wait for flood to finish
echo "[$(date +%FT%T)+00:00] Waiting for flood $flood_uuid"
while [ $(curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid | \
  jq -r '.status == "finished"') = "false" ]; do
  echo -n "."
  sleep 3
done

# Get the summary report
flood_report=$(curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid/report | \
  jq -r ".summary")

echo
echo "[$(date +%FT%T)+00:00] Detailed results at https://flood.io/$flood_uuid"
echo "$flood_report"

# Optionally store the CSV results
echo
echo "[$(date +%FT%T)+00:00] Storing CSV results at results.csv"
curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid/result.csv > result.csv
