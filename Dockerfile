# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/haf/ci-base-image:ubuntu20.04-xxx -f Dockerfile .
# To be started from cloned haf source directory.
ARG CI_REGISTRY_IMAGE
ARG CI_IMAGE_TAG=:ubuntu20.04-3 

FROM phusion/baseimage:focal-1.0.0 AS ci-base-image

ENV LANG=en_US.UTF-8

SHELL ["/bin/bash", "-c"] 

USER root
WORKDIR /usr/local/src
ADD ./scripts/setup_ubuntu.sh /usr/local/src/scripts/

RUN ./scripts/setup_ubuntu.sh --haf-admin-account="haf_admin" --hived-account="hived" 

USER haf_admin

WORKDIR /home/haf_admin

FROM $CI_REGISTRY_IMAGE/ci-base-image$CI_IMAGE_TAG AS build
ARG BRANCH=master
ENV BRANCH=${BRANCH:-master}

ARG COMMIT
ENV COMMIT=${COMMIT:-""}

USER haf_admin
WORKDIR /home/haf_admin
SHELL ["/bin/bash", "-c"] 

ADD ./scripts /home/haf_admin/scripts

RUN LOG_FILE=build.log source ./scripts/common.sh && do_clone "$BRANCH" ./haf https://gitlab.syncad.com/hive/haf.git "$COMMIT" && \
  ./haf/scripts/build.sh --haf-source-dir="./haf" --haf-binaries-dir="./build" hived cli_wallet truncate_block_log extension.hive_fork_manager && \
  cd ./build && \
  find . -name *.o  -type f -delete && \
  find . -name *.a  -type f -delete

# Here we could use a smaller image without packages specific to build requirements
FROM $CI_REGISTRY_IMAGE/ci-base-image$CI_IMAGE_TAG as instance

ARG BUILD_IMAGE_TAG
ENV BUILD_IMAGE_TAG=${BUILD_IMAGE_TAG:-:ubuntu20.04-3}

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}

ARG WS_PORT=8090
ENV WS_PORT=${WS_PORT}

ARG HTTP_PORT=8090
ENV HTTP_PORT=${HTTP_PORT}

ENV HAF_DB_STORE=/home/hived/datadir/haf_db_store
ENV PGDATA=/home/hived/datadir/haf_db_store/pgdata

SHELL ["/bin/bash", "-c"] 

USER hived
WORKDIR /home/hived

COPY --from=build /home/haf_admin/build/hive/programs/hived/hived /home/haf_admin/build/hive/programs/cli_wallet/cli_wallet /home/haf_admin/build/hive/programs/util/truncate_block_log /home/hived/bin/

COPY --from=build /home/haf_admin/build/src/hive_fork_manager ./hive_fork_manager

USER haf_admin
WORKDIR /home/haf_admin

COPY --from=build /home/haf_admin/build /home/haf_admin/build/
COPY --from=build /home/haf_admin/haf /home/haf_admin/haf/

ADD ./docker/docker_entrypoint.sh .
ADD --chown=postgres:postgres ./docker/postgresql.conf /etc/postgresql/12/main/postgresql.conf
ADD --chown=postgres:postgres ./docker/pg_hba.conf /etc/postgresql/12/main/pg_hba.conf

RUN sudo -n mkdir -p /home/hived/bin && sudo -n mkdir -p /home/hived/shm_dir && \
  sudo -n mkdir -p /home/hived/datadir && sudo -n chown -Rc hived:hived /home/hived/

VOLUME [/home/hived/datadir, /home/hived/shm_dir]

#p2p service
EXPOSE ${P2P_PORT}
# websocket service
EXPOSE ${WS_PORT}
# JSON rpc service
EXPOSE ${HTTP_PORT}

# Embedded postgres service
EXPOSE 5432

STOPSIGNAL SIGINT 

ENTRYPOINT [ "/home/haf_admin/docker_entrypoint.sh" ]

