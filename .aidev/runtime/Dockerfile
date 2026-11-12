# The image AIDEV runs this project's checks in (`environment.image` in
# .aidev/project.yaml): the HAF image itself, so the functional tests run against
# the PostgreSQL, extension layout and libhfm the project ships. Only the
# entrypoint is cleared, so AIDEV's argv (.aidev/run-checks.sh …) runs as given;
# run-checks.sh starts PostgreSQL through /home/hived/docker_entrypoint.sh.
#
# Base: hive/haf:6f476cfd — the CI image of develop 46558ea2e (tagged by source
# digest; its libhfm carries the L2 C functions l2_transaction_digest /
# l2_pubkey_to_bytea, hive/haf#370). Re-pin when the base should follow develop (a
# C++ change only reaches these checks through a new base). Build with
# .aidev/runtime/build.sh.
FROM registry.gitlab.syncad.com/hive/haf@sha256:e96bd83188067dc1214ad6c8d29d62d422c20b8908d32eb21e0eff1fe014daaa

ENTRYPOINT []
CMD ["bash"]
