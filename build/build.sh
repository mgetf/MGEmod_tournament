set -e

docker build -t spcomp:1.12 -f spcomp.Dockerfile .
docker run --rm \
  -v "$PWD/..":/src \
  spcomp:1.12 \
  -i /opt/addons/sourcemod/scripting/include/ \
  /src/addons/sourcemod/scripting/ladder.sp \
  -o /src/addons/sourcemod/plugins/ladder.smx