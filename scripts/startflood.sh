set -e

echo "[$(date +%FT%T)+00:00] Checking dependencies"
[ -f " /tmp/jq" ] || curl --silent -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 > /tmp/jq
chmod 755 /tmp/jq

FLOOD_API_TOKEN="access_token=flood_live_3363b6988a605e11fd23747a755f2a4ecd4c61a7ae"

echo "[$(date +%FT%T)+00:00] Launching flood"
flood_uuid=$(curl --silent -u $FLOOD_API_TOKEN: -X POST https://api.flood.io/floods \
  -F "flood[tool]=jmeter" \
  -F "flood[threads]=20" \
  -F "flood[rampup]=30" \
  -F "flood[duration]=120" \
  -F "flood[privacy]=public" \
  -F "flood[project]=azure-devops" \
  -F "flood[name]=Build New" \
  -F "flood[tag_list]=ci,load" \
  -F "flood_files[]=@scripts/jmeter/002_MCI.jmx" \
  -F "flood_files[]=@scripts/jmeter/MCI.csv" \
  -F "flood[grids][][infrastructure]=demand" \
  -F "flood[grids][][instance_quantity]=1" \
  -F "flood[grids][][region]=us-west-2" \
  -F "flood[grids][][instance_type]=m5.xlarge" \
  -F "flood[grids][][stop_after]=15" | jq -r ".uuid" )
  
  echo "this looks goofd"

echo "[$(date +%FT%T)+00:00] Waiting for flood https://flood.io/$flood_uuid to finish"
while [ $(curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid | \
  /tmp/jq -r '.status == "finished"') = "false" ]; do
  sleep 3
done

flood_report=$(curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid/report | \
  /tmp/jq -r ".summary")

error_rate=$(curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid | /tmp/jq -r .error_rate)
response_time=$(curl --silent --user $FLOOD_API_TOKEN: https://api.flood.io/floods/$flood_uuid | /tmp/jq -r .response_time)

echo
echo "[$(date +%FT%T)+00:00] Detailed results at https://flood.io/$flood_uuid"
echo "---"
echo "$flood_report"

if [ "$error_rate" -gt "0" ]; then
  echo "Flood test failed with error rate $error_rate%"
  exit 1
fi

if [ "$response_time" -gt "3000" ]; then
  echo "Flood test failed with response time $response_time > 3000ms"
  exit 2
fi
