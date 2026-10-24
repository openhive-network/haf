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
FROM registry.gitlab.syncad.com/hive/haf@sha256:3b84d25f22081eea5f7f567b02783a76a43d5c8ce8ef3b6c1394010f78895e52

ENTRYPOINT []
CMD ["bash"]
