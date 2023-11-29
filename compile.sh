docker cp addons/sourcemod/scripting/mgeme.sp ff3:/home/tf2/hlserver/tf2/tf/addons/sourcemod/scripting
docker exec -u 0 -it ff3 tf2/tf/addons/sourcemod/scripting/compile.sh
