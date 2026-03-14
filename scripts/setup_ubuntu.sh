#! /bin/bash

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SRC_DIR="$SCRIPT_DIR/.."

set -euo pipefail

POSTGRES_VERSION="${POSTGRES_VERSION:-17}"

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
    echo "  --hived-account=NAME      Specify the unix account name to be used for hived (UID 1000, with sudo)."
    echo "  --help                    Display this help screen and exit."
    echo
}

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
    postgresql-plpython3-${POSTGRES_VERSION} \
    curl \
    python3-bs4 python3-lxml

  apt-get clean
  rm -rf /var/lib/apt/lists/*
  rm -rf /root/.cache ~/.cache /tmp/* /var/tmp/*
  find / -type d -name '__pycache__' -exec rm -rf {} +

  pip3 install --break-system-packages tokenizers base58

  mkdir -p /home/hived/tokenizer-files
  cat << EOF > /tmp/download-tokenizer-files.py
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="intfloat/multilingual-e5-base",
    local_dir="/home/hived/tokenizer-files/e5-base",
    allow_patterns=[
      "tokenizer.json",
      "tokenizer_config.json",
      "special_tokens_map.json",
      "sentencepiece.bpe.model",
    ]
)
EOF
  python3 /tmp/download-tokenizer-files.py
  rm /tmp/download-tokenizer-files.py
  chown -R hived.users /home/hived/tokenizer-files
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

  if [ "${POSTGRES_VERSION}" -ge 18 ]; then
    sed -i -e 's/Suites: noble-pgdg/Suites: noble-pgdg-snapshot/' \
           -e "s/Components: main/Components: main ${POSTGRES_VERSION}/" \
           /etc/apt/sources.list.d/pgdg.sources
    echo 'Package: *' > /etc/apt/preferences.d/pgdg.pref
    echo 'Pin: origin apt.postgresql.org' >> /etc/apt/preferences.d/pgdg.pref
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/pgdg.pref
  fi

  apt-get update

  DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-${POSTGRES_VERSION} postgresql-server-dev-${POSTGRES_VERSION} \
  netcat-openbsd \
  git python3.12 python3.12-venv python3.12-dev python3-pip postgresql-plpython3-${POSTGRES_VERSION} curl # for hivesense

  apt-get clean
  rm -rf /var/lib/apt/lists/*

  pushd /tmp
  git clone https://github.com/citusdata/pg_cron.git
  cd pg_cron

  make && make install
  cd ..
  rm -r pg_cron
  popd

  sudo usermod -a -G users -c "PostgreSQL daemon account" postgres

  # Note: libpqxx is now pre-installed in ci-base-image (ubuntu24.04-py3.14-7+)
}

install_user_packages() {
  echo "Attempting to install user packages..."

  "$SRC_DIR/hive/scripts/setup_ubuntu.sh" --user
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
        echo "Warning: --haf-admin-account is deprecated and ignored. Use --hived-account instead."
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
