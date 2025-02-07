ARG POSTGRES_MAJOR_VERSION="17"

FROM ubuntu:22.04 AS fixuid-downloader
RUN apt-get update && apt-get -y install curl
RUN curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf -

FROM ubuntu:22.04 AS hived

STOPSIGNAL SIGINT

ARG P2P_PORT=2001
ENV P2P_PORT=${P2P_PORT}

ARG WS_PORT=8090
ENV WS_PORT=${WS_PORT}

ARG HTTP_PORT=8091
ENV HTTP_PORT=${HTTP_PORT}

RUN apt-get update && apt-get -y install --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid 2001 hived && \
    useradd --create-home --shell /bin/bash --uid 2001 --gid hived --comment "Hived daemon account" hived && \
    mkdir -p /home/hived/bin && \
    chown hived:hived /home/hived/bin

COPY --from=fixuid-downloader --chown=root:root /usr/local/bin/fixuid /usr/local/bin/fixuid
RUN USER=hived && \
    GROUP=hived && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml

COPY --chown=hived:hived hived_docker_entrypoint.sh /docker_entrypoint.sh

COPY --from=registry.gitlab.syncad.com/hive/haf/instance:instance-local-rc-separate --chown=hived:hived \
  /home/hived/bin/hived \
  /usr/local/bin

USER hived:hived

ENTRYPOINT [ "/docker_entrypoint.sh" ]


##################################################################################################################################
FROM ubuntu:22.04 AS suid_builder
ARG POSTGRES_MAJOR_VERSION

RUN apt-get update && apt-get -y install --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*

COPY update-hive-fork-manager-extension.c /
RUN gcc -DPOSTGRES_MAJOR_VERSION=${POSTGRES_MAJOR_VERSION} -o update-hive-fork-manager-extension update-hive-fork-manager-extension.c

##################################################################################################################################

FROM postgres:${POSTGRES_MAJOR_VERSION} AS postgres
ARG POSTGRES_MAJOR_VERSION

RUN apt-get update && apt-get -y install --no-install-recommends \
      libboost-chrono1.74.0 \
      libboost-context1.74.0 \
      libboost-filesystem1.74.0 \
      libboost-thread1.74.0 \
      postgresql-${POSTGRES_MAJOR_VERSION}-cron && \
    rm -rf /var/lib/apt/lists/*

# The installation for pg_cron requires these settings exist during the initdb step,
# we'll remove them after initdb and apply them using files in the conf.d  directory
RUN echo "shared_preload_libraries='pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name='haf_block_log'" >> /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /docker-entrypoint-always-initdb.d
COPY postgres_docker_entrypoint.sh /usr/local/bin/docker-entrypoint-for-haf.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-for-haf.sh"]
CMD ["postgres"]

# Add hive_fork_manager
COPY --from=registry.gitlab.syncad.com/hive/haf/instance:instance-local-rc-separate \
  /home/haf_admin/build/extensions/hive_fork_manager/* \
  /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension
COPY --from=registry.gitlab.syncad.com/hive/haf/instance:instance-local-rc-separate \
  /home/haf_admin/build/lib/libhfm-* \
  /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib

# Add query_supervisor
COPY --from=registry.gitlab.syncad.com/hive/haf/instance:instance-local-rc-separate \
  /home/haf_admin/build/lib/libquery_supervisor.so \
  /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib

COPY docker-entrypoint-initdb.d /docker-entrypoint-initdb.d
COPY --from=registry.gitlab.syncad.com/hive/haf/instance:instance-local-rc-separate \
  /home/haf_admin/source/scripts/haf_builtin_roles.sql /docker-entrypoint-initdb.d/010-haf-builtin-roles.sql

COPY docker-entrypoint-always-initdb.d /docker-entrypoint-always-initdb.d
COPY --from=suid_builder --chown=root:postgres /update-hive-fork-manager-extension /docker-entrypoint-always-initdb.d/100-update-hive-fork-manager-extension.sh
RUN chmod 4755 /docker-entrypoint-always-initdb.d/100-update-hive-fork-manager-extension.sh

# Install config
COPY postgresql-conf.d /etc/postgresql/conf.d

# Create directory for bind-mounted config
RUN mkdir -p /etc/postgresql/haf_api_node_conf.d
