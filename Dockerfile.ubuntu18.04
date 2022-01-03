# docker build -f Dockerfile.postgres13  -t psql-tools13 .
FROM phusion/baseimage:0.11

ENV LANG=en_US.UTF-8

RUN \
    apt-get update \
    && apt-get install -y wget \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/postgresql-pgdg.list > /dev/null \
    && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null \
    && apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"

RUN \
    apt-get update \
    && apt-get install -y \
            systemd \
            autoconf \
            postgresql-12 \
            postgresql-contrib-12 \
            build-essential \
            cmake \
            libboost-all-dev \
            postgresql-server-dev-12 \
            git \
            python3-pip \
            libssl-dev \
            libreadline-dev \
            libsnappy-dev \
    && \
        apt-get clean

RUN \
    python3 -mpip install \
        pexpect \
        psycopg2 \
        sqlalchemy \
        jinja2



ADD . /usr/local/src
WORKDIR /usr/local/src

USER postgres
RUN  /etc/init.d/postgresql start \
     && psql --command "CREATE USER root WITH SUPERUSER CREATEDB;"

USER root