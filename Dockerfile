# Base docker file having defined environment for build and run of HAF instance.
# docker build -t registry.gitlab.syncad.com/hive/haf/ci-base-image:ubuntu20.04-xxx -f Dockerfile .
# To be started from cloned haf source directory.
ARG CI_REGISTRY_IMAGE
ARG IMAGE_TAG=:ubuntu20.04-2 

FROM phusion/baseimage:focal-1.0.0 AS ci-base-image

ENV LANG=en_US.UTF-8

SHELL ["/bin/bash", "-c"] 

USER root
WORKDIR /usr/local/src
ADD ./scripts /usr/local/src/scripts

RUN ./scripts/setup_ubuntu.sh --haf-admin-account="haf_admin" --hived-account="hived"

USER haf_admin

WORKDIR /home/haf_admin

FROM $CI_REGISTRY_IMAGE/ci-base-image$IMAGE_TAG AS build
ARG BRANCH=master
ENV BRANCH=${BRANCH:-master}

USER haf_admin
WORKDIR /home/haf_admin
SHELL ["/bin/bash", "-c"] 

ADD ./scripts /home/haf_admin/scripts

RUN LOG_FILE=build.log source ./scripts/common.sh && do_clone "$BRANCH" ./haf https://gitlab.syncad.com/hive/haf.git && \
  ./haf/scripts/build.sh --haf-source-dir="./haf" --haf-binaries-dir="./build" hived cli_wallet truncate_block_log extension.hive_fork_manager && \
  cd ./build && \
  find . -name *.o  -type f -delete && \
  find . -name *.a  -type f -delete

FROM $CI_REGISTRY_IMAGE/build$IMAGE_TAG AS built_binaries
# Here we could use a smaller image without packages specific to build requirements
FROM built_binaries as instance

SHELL ["/bin/bash", "-c"] 

USER hived
WORKDIR /home/hived

RUN mkdir -p /home/hived/bin && mkdir -p /home/hived/datadir 

COPY --from=built_binaries /home/haf_admin/build/hive/programs/hived/hived /home/haf_admin/build/hive/programs/cli_wallet/cli_wallet /home/haf_admin/build/hive/programs/util/truncate_block_log /home/hived/bin/

COPY --from=built_binaries /home/haf_admin/build/src/hive_fork_manager ./hive_fork_manager

USER haf_admin
WORKDIR /home/haf_admin

RUN sudo -n ./haf/scripts/setup_postgres.sh --haf-admin-account=haf_admin --haf-binaries-dir="/home/hived/hive_fork_manager" --haf-database-store="/home/hived/datadir"

USER hived
WORKDIR /home/hived

VOLUME /home/hived/datadir

ENTRYPOINT ["/bin/bash", "-c"]
CMD ['"ls -laR /home/haf_admin/"']

