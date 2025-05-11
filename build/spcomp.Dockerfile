# dockerfiles/spcomp.Dockerfile
FROM --platform=linux/amd64 ubuntu:22.04
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
      wget unzip ca-certificates \
      libc6:i386 libstdc++6:i386 zlib1g:i386 && \
    wget -qO- https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git6960-linux.tar.gz \
      | tar -xzC /opt && \
    ln -s /opt/addons/sourcemod/scripting/spcomp /usr/local/bin/spcomp
ENTRYPOINT ["spcomp"]