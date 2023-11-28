# Base docker file having defined environment for build and run of HAF instance.
# docker buildx build --progress=plain --target=ci-base-image --tag registry.gitlab.syncad.com/hive/haf/ci-base-image$CI_IMAGE_TAG --file Dockerfile .
# To be started from cloned haf source directory.
ARG CI_REGISTRY_IMAGE=registry.gitlab.syncad.com/hive/haf/
ARG CI_IMAGE_TAG=:ubuntu22.04-6

ARG BUILD_IMAGE_TAG

FROM registry.gitlab.syncad.com/hive/hive/ci-base-image:ubuntu22.04-9 AS ci-base-image

ENV PATH="/home/haf_admin/.local/bin:$PATH"

SHELL ["/bin/bash", "-c"]

USER root
WORKDIR /usr/local/src
COPY ./hive/scripts/openssl.conf /usr/local/src/hive/scripts/openssl.conf
COPY ./hive/scripts/setup_ubuntu.sh /usr/local/src/hive/scripts/
COPY ./scripts/setup_ubuntu.sh /usr/local/src/scripts/

# Install development packages and create required accounts
RUN ./scripts/setup_ubuntu.sh --dev --haf-admin-account="haf_admin" --hived-account="hived" \
  && rm -rf /var/lib/apt/lists/*

USER haf_admin
WORKDIR /home/haf_admin

# Install additionally packages located in user directory
RUN /usr/local/src/scripts/setup_ubuntu.sh --user

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
  && \
  cd ./build && \
  find . -name *.o  -type f -delete && \
  find . -name *.a  -type f -delete

# Here we could use a smaller image without packages specific to build requirements
FROM ${CI_REGISTRY_IMAGE}ci-base-image$CI_IMAGE_TAG as base_instance

ENV BUILD_IMAGE_TAG=${BUILD_IMAGE_TAG:-:ubuntu22.04-6}

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}

ARG WS_PORT=8090
ENV WS_PORT=${WS_PORT}

ARG HTTP_PORT=8091
ENV HTTP_PORT=${HTTP_PORT}

# Environment variable which allows to override default postgres access specification in pg_hba.conf
ENV PG_ACCESS="host    haf_block_log     haf_app_admin    172.0.0.0/8    trust\nhost    all     pghero    172.0.0.0/8    trust"

# Always define default value of HIVED_UID variable to make possible direct spawn of docker image (without run_hived_img.sh wrapper)
ENV HIVED_UID=1000

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
  /home/haf_admin/build/hive/programs/util/* \
  /home/haf_admin/build/hive/programs/blockchain_converter/blockchain_converter* \
  /home/haf_admin/build/tests/unit/* \
  /home/hived/bin/

USER haf_admin
WORKDIR /home/haf_admin

COPY --from=build --chown=haf_admin:users /home/haf_admin/build /home/haf_admin/build/
COPY --from=build --chown=haf_admin:users /home/haf_admin/haf /home/haf_admin/haf/

ENV POSTGRES_VERSION=14
COPY --chown=haf_admin:users ./docker/docker_entrypoint.sh .
COPY --chown=postgres:postgres ./docker/postgresql.conf /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
COPY --chown=postgres:postgres ./docker/pg_hba.conf /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf.default

ENV DATADIR=/home/hived/datadir
# Use default location (inside datadir) of shm file. If SHM should be placed on some different device, then set it to mapped volume `/home/hived/shm_dir` and map it in docker run
ENV SHM_DIR=${DATADIR}/blockchain

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
