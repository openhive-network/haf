#! /bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$SCRIPT_DIR/.."

set -euo pipefail

# This script installs all packages required to build and run a HAF instance.
# After changing it, please also update and push to the registry a docker image defined in https://gitlab.syncad.com/hive/haf/-/blob/develop/Dockerfile
# The updated docker image must also be explicitly referenced on line https://gitlab.syncad.com/hive/haf/-/blob/develop/.gitlab-ci.yml#L7

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Setup this machine for HAF installation."
    echo "OPTIONS:"
    echo "  --dev                     Install packages required to build and run a HAF server."
    echo "  --ai                      Install pgai"
    echo "  --user                    Install packages to a subdirectory of the user's home directory."
    echo "  --haf-admin-account=NAME  Specify the unix account name to be used for HAF administration (will be associated with the PostgreSQL role)."
    echo "  --hived-account=NAME      Specify the unix account name to be used for hived (will be associated with the PostgreSQL role)."
    echo "  --help                    Display this help screen and exit."
    echo
}

haf_admin_unix_account="haf_admin"
hived_unix_account="hived"

assert_is_root() {
  if [ "$EUID" -ne 0 ]
    then echo "Please run as root."
    exit 1
  fi
}

install_ai_packages() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
    python3.12 python3.12-venv python3.12-dev python3-pip \
    postgresql-17-pgvector postgresql-plpython3-17 \
    curl

  # required by Hivesense as pgai
    python3.12 -m pip install --break-system-packages langchain

    pushd /tmp
      git clone https://github.com/timescale/pgai.git --branch extension-0.8.0
      pushd pgai
        python3.12 -m venv venv/
        # shellcheck disable=SC1091
        . venv/bin/activate
        python3.12 -m pip install --upgrade pip
        projects/extension/build.py install
        deactivate
      popd
      rm -r pgai
    popd

    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -rf /root/.cache ~/.cache /tmp/* /var/tmp/*
    find / -type d -name '__pycache__' -exec rm -rf {} +
    rm -rf  /usr/local/lib/pgai/0.8.0/google
    rm -rf  /usr/local/lib/pgai/0.8.0/litellm

    rm -rf /usr/local/lib/pgai/0.4.0
    rm -rf /usr/local/lib/pgai/0.4.1
    rm -rf /usr/local/lib/pgai/0.5.0
    rm -rf /usr/local/lib/pgai/0.6.0
    rm -rf /usr/local/lib/pgai/0.7.0
    rm -rf /usr/local/lib/pgai/0.8.0/pyarrow

}

install_all_dev_packages() {
  echo "Attempting to install all dev packages..."
  assert_is_root

  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --runtime --dev

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
          systemd \
          libpq-dev \
          tox \
          joe \
          postgresql-common

  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-17 postgresql-server-dev-17 postgresql-17-cron \
    netcat-openbsd \
    git python3.12 python3.12-venv python3.12-dev python3-pip postgresql-17-pgvector postgresql-plpython3-17 curl # for hivesense

  apt-get clean
  rm -rf /var/lib/apt/lists/*

  sudo usermod -a -G users -c "PostgreSQL daemon account" postgres

  pushd /tmp
  git clone --depth 1 --branch 7.8.1 https://github.com/jtv/libpqxx.git
  pushd libpqxx
  mkdir build
  pushd build
  cmake -DCMAKE_BUILD_TYPE=Release -GNinja -DBUILD_TEST=OFF ..
  ninja install
  popd
  popd
  rm -r libpqxx
  popd
}

install_user_packages() {
  echo "Attempting to install user packages..."

  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --user
}

create_haf_admin_account() {
  echo "Attempting to create $haf_admin_unix_account account..."
  assert_is_root

  # Unfortunately haf_admin must be able to su as root, because it must be able to write into /usr/share/postgresql/17/extension directory, being owned by root (it could be owned by postgres)
  if id "$haf_admin_unix_account" &>/dev/null; then
      echo "Account $haf_admin_unix_account already exists. Creation skipped."
  else
      useradd -ms /bin/bash -c "HAF admin account" -u 4000 -U "$haf_admin_unix_account" && echo "$haf_admin_unix_account ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
      usermod -a -G users "$haf_admin_unix_account"
      chown -Rc "$haf_admin_unix_account":users "/home/$haf_admin_unix_account"
  fi
}

create_maintenance_account() {
  echo "Attempting to create haf_maintainer account..."
  useradd -r -s /usr/sbin/nologin -b /nonexistent -c "HAF maintenance service account" -U haf_maintainer
}

create_hived_account() {
  echo "Attempting to create $hived_unix_account account..."
  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --hived-account="$hived_unix_account"
  sudo -n chown -Rc "$hived_unix_account":users "/home/$hived_unix_account"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dev)
        install_all_dev_packages
        install_ai_packages
        create_maintenance_account
        ;;
    --ai)
        install_ai_packages
        ;;
    --user)
        install_user_packages
        ;;
    --haf-admin-account=*)
        haf_admin_unix_account="${1#*=}"
        create_haf_admin_account
        ;;
    --hived-account=*)
        hived_unix_account="${1#*=}"
        create_hived_account
        ;;
    --help)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option."
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument."
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done
