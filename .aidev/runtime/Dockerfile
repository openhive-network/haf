# The image AIDEV runs this project's checks in (`environment.image` in
# .aidev/project.yaml): the HAF image itself, so the functional tests run against
# the PostgreSQL, extension layout and libhfm the project ships. Only the
# entrypoint is cleared, so AIDEV's argv (.aidev/run-checks.sh …) runs as given;
# run-checks.sh starts PostgreSQL through /home/hived/docker_entrypoint.sh.
#
# Base: hive/haf:8de693b2 — the HAF commit at develop/aidev/integration when this
# was pinned. Re-pin when the base should follow develop (a C++ change only reaches
# these checks through a new base). Build with .aidev/runtime/build.sh.
FROM registry.gitlab.syncad.com/hive/haf@sha256:4948ddfd4c5e4bca1d312361a2124ac616db15811d03bce94ba3f0151b440b38

ENTRYPOINT []
CMD ["bash"]
