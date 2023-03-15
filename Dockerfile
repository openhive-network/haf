# Base docker file having defined environment for build and run of HAF instance.
# docker build --target=ci-base-image -t registry.gitlab.syncad.com/hive/haf/ci-base-image:ubuntu20.04-xxx -f Dockerfile .
# To be started from cloned haf source directory.
ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/haf/
ARG CI_IMAGE_TAG=:ubuntu22.04-2

ARG BUILD_IMAGE_TAG

FROM registry.gitlab.syncad.com/hive/hive/ci-base-image:ubuntu22.04-1 AS ci-base-image

ENV PATH="/home/haf_admin/.local/bin:$PATH"

SHELL ["/bin/bash", "-c"]

USER root
WORKDIR /usr/local/src
COPY ./hive/scripts/setup_ubuntu.sh /usr/local/src/hive/scripts/
COPY ./scripts/setup_ubuntu.sh /usr/local/src/scripts/

# Install development packages and create required accounts
RUN ./scripts/setup_ubuntu.sh --dev --haf-admin-account="haf_admin" --hived-account="hived" \ 
  && rm -rf /var/lib/apt/lists/*

USER haf_admin
WORKDIR /home/haf_admin

# Install additionally packages located in user directory
RUN /usr/local/src/scripts/setup_ubuntu.sh --user

#docker build --target=ci-base-image-5m -t registry.gitlab.syncad.com/hive/haf/ci-base-image-5m:ubuntu20.04-xxx -f Dockerfile .
FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG AS ci-base-image-5m

USER hived
RUN  mkdir -p /home/hived/datadir/blockchain && \
  wget -c https://gtg.openhive.network/get/blockchain/block_log.5M --output-document=/home/hived/datadir/blockchain/block_log
USER haf_admin

FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG AS build

ARG BUILD_HIVE_TESTNET=OFF
ENV BUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}

ARG ENABLE_SMT_SUPPORT=OFF
ENV ENABLE_SMT_SUPPORT=${ENABLE_SMT_SUPPORT}

ARG HIVE_CONVERTER_BUILD=OFF
ENV HIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}

ARG HIVE_LINT=OFF
ENV HIVE_LINT=${HIVE_LINT}

USER haf_admin
WORKDIR /home/haf_admin

SHELL ["/bin/bash", "-c"]

# Get everything from cwd as sources to be built.
COPY --chown=haf_admin:users . /home/haf_admin/haf

RUN \
  ./haf/scripts/build.sh --haf-source-dir="./haf" --haf-binaries-dir="./build" \
  --cmake-arg="-DBUILD_HIVE_TESTNET=${BUILD_HIVE_TESTNET}" \
  --cmake-arg="-DENABLE_SMT_SUPPORT=${ENABLE_SMT_SUPPORT}" \
  --cmake-arg="-DHIVE_CONVERTER_BUILD=${HIVE_CONVERTER_BUILD}" \
  --cmake-arg="-DHIVE_LINT=${HIVE_LINT}" \
  hived cli_wallet compress_block_log extension.hive_fork_manager && \
  cd ./build && \
  find . -name *.o  -type f -delete && \
  find . -name *.a  -type f -delete

# Here we could use a smaller image without packages specific to build requirements
FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG as base_instance

ENV BUILD_IMAGE_TAG=${BUILD_IMAGE_TAG:-:ubuntu20.04-5}

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}

ARG WS_PORT=8091
ENV WS_PORT=${WS_PORT}

ARG HTTP_PORT=8090
ENV HTTP_PORT=${HTTP_PORT}

# Environment variable which allows to override default postgres access specification in pg_hba.conf
ENV PG_ACCESS="host    haf_block_log     haf_app_admin    172.0.0.0/8    trust\nhost    all     pghero    172.0.0.0/8    trust"

SHELL ["/bin/bash", "-c"]

USER hived
WORKDIR /home/hived

RUN mkdir -p /home/hived/bin && \
    mkdir /home/hived/shm_dir && \
    mkdir /home/hived/datadir && \
    chown -Rc hived:users /home/hived/

COPY --from=build --chown=hived:users \
  /home/haf_admin/build/hive/programs/hived/hived \
  /home/haf_admin/build/hive/programs/cli_wallet/cli_wallet \
  /home/haf_admin/build/hive/programs/util/compress_block_log \
  /home/haf_admin/build/hive/programs/util/get_dev_key \
  /home/haf_admin/build/hive/programs/blockchain_converter/blockchain_converter* \
  /home/hived/bin/

USER haf_admin
WORKDIR /home/haf_admin

COPY --from=build --chown=haf_admin:users /home/haf_admin/build /home/haf_admin/build/
COPY --from=build --chown=haf_admin:users /home/haf_admin/haf /home/haf_admin/haf/

ENV POSTGRES_VERSION=14
COPY --chown=haf_admin:users ./docker/docker_entrypoint.sh .
COPY --chown=postgres:postgres ./docker/postgresql.conf /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
COPY --chown=postgres:postgres ./docker/pg_hba.conf /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf.default

VOLUME [ "/home/hived/datadir", "/home/hived/shm_dir" ]

ENV DATADIR=/home/hived/datadir
ENV SHM_DIR=/home/hived/shm_dir

STOPSIGNAL SIGINT

# JSON rpc service
EXPOSE ${HTTP_PORT}

ENTRYPOINT [ "/home/haf_admin/docker_entrypoint.sh" ]

FROM ${CI_REGISTRY_IMAGE}base_instance:base_instance-${BUILD_IMAGE_TAG} as instance

# Embedded postgres service
EXPOSE 5432

EXPOSE ${P2P_PORT}
# websocket service
EXPOSE ${WS_PORT}
# JSON rpc service
EXPOSE ${HTTP_PORT}

FROM ${CI_REGISTRY_IMAGE}ci-base-image-5m$CI_IMAGE_TAG AS block_log_5m_source

FROM ${CI_REGISTRY_IMAGE}base_instance:base_instance-$BUILD_IMAGE_TAG as data

COPY --from=block_log_5m_source --chown=hived:users /home/hived/datadir /home/hived/datadir 
ADD --chown=hived:users ./docker/config_5M.ini /home/hived/datadir/config.ini

RUN "/home/haf_admin/docker_entrypoint.sh" --force-replay --stop-replay-at-block=5000000 --exit-before-sync

ENTRYPOINT [ "/home/haf_admin/docker_entrypoint.sh" ]

# default command line to be passed for this version (which should be stopped at 5M)
CMD ["--replay-blockchain", "--stop-replay-at-block=5000000"]

# Embedded postgres service
EXPOSE 5432

