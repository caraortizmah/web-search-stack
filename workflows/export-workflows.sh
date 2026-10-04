#!/bin/bash
# export-workflows.sh
WORKFLOW_ID="AbCdEf123456XyZ"
WORKFLOW_NAME="websearchstack"
HOST_REPO="/home/user/gitpath/repopath"

docker exec n8n mkdir -p /home/node/workflows
docker exec n8n n8n export:workflow --id="$WORKFLOW_ID" --output=/home/node/workflows/"$WORKFLOW_NAME".json --pretty
docker cp n8n:/home/node/workflows/"$WORKFLOW_NAME".json "$HOST_REPO"/workflows/

