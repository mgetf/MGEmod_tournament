set -e

docker build -t spcomp:1.12 -f spcomp.Dockerfile .
docker run --rm \
  -v "$PWD/..":/src \
  spcomp:1.12 \
  -i /opt/addons/sourcemod/scripting/include/ \
  -i /src/addons/sourcemod/scripting/include/ \
  /src/addons/sourcemod/scripting/ladder.sp \
  -o /src/addons/sourcemod/plugins/ladder.smx

scp ../addons/sourcemod/plugins/ladder.smx  root@108.61.178.103:/tmp/
ssh root@108.61.178.103 '
  docker cp /tmp/ladder.smx tf2_ladder_service:/home/tf2/server/tf/addons/sourcemod/plugins &&
  docker exec tf2_ladder_service ./rcon -H 127.0.0.1 -p 27000 -P 123456 sm plugins unload ladder &&
  docker exec tf2_ladder_service ./rcon -H 127.0.0.1 -p 27000 -P 123456 sm plugins load ladder
'
