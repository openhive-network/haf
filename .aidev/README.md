# HAF under AIDEV

AIDEV verifies changes to this repository through the slots in `project.yaml`,
integrates them into `aidev/integration`, and people merge that into `develop`
through merge requests (as in hive/HAfAH and hive/haf_api_node). GitLab CI doesn't run
for AIDEV branches (`ai/*`, `session/*`, pushes to `aidev/integration`); see
`.gitlab-ci.yml` `workflow:`. `develop` requires a successful pipeline, so start one on
`aidev/integration` (web or API) before merging its MR.

## Suites

`.aidev/run-checks.sh <suite> <step>...` runs the named steps and writes
`test-results/<suite>/junit.xml`, one test case per step, plus
`test-results/<suite>/hfm-functional.xml`, one case per functional test.

| Step | What |
|---|---|
| `hfm-smoke` | the functional tests under `hive_fork_manager/context_rewind/` and `hive_fork_manager/app_api/` (194) |
| `hfm-functional` | every `hive_fork_manager` and `query_supervisor` functional test ctest registers (421); `RUN_SERIAL` tests run alone after the rest |
| `cxx-scope` | a skipped case naming the candidate's changed C++/CMake/`hive` files, which these checks do not verify |

How the functional tests run (`.aidev/hfm-functional.sh`): inside the HAF image, as the
maintenance script of `/home/hived/docker_entrypoint.sh` (which starts PostgreSQL), the
way CI's `hfm_functional_tests` runs `scripts/maintenance-scripts/run_hfm_functional_tests.sh`.
It installs the candidate's extension SQL as `Dockerfile.sql-overlay` does
(`scripts/generate_extension_sql.sh`, then `libhfm-<version>.so` pointed at the image's own
`libhfm`), reads the test list from the `ADD_SQL_FUNCTIONAL_TEST` lines and `RUN_SERIAL`
properties of `tests/integration/functional/{hive_fork_manager,query_supervisor}/CMakeLists.txt`,
and runs each through `tools/test.sh` (8 at a time; `HFM_TEST_JOBS`), so no CMake configure
and no `hive` submodule checkout is needed. The entrypoint needs the image's
sudo-capable `hived` user, uid 1000 — the uid AIDEV's pull hosts and workers run as;
`run-checks.sh` fails with that reason under any other uid.

| Slot | Steps |
|---|---|
| quick, coverage | hfm-smoke (+ cxx-scope on quick) |
| full, canary | hfm-functional, cxx-scope |
| baseline | hfm-functional |

Not covered yet: the C++ build and unit tests, `test.functional.update.*` (needs the
built update-script generator), replay, system, forking and application tests, and
shellcheck (`scripts/` has 8 error-severity findings today). They stay in GitLab CI.

To run by hand:

```bash
docker run --rm --network none --user 1000:1000 -v "$PWD:/work" -w /work \
    "$(grep -o 'registry[^"]*aidev-tests@sha256:[0-9a-f]*' .aidev/project.yaml)" \
    .aidev/run-checks.sh full hfm-functional
```

## The test runtime image (`runtime/`)

The HAF image `hive/haf:8de693b2` with its entrypoint cleared, pinned by digest. A C++
change reaches these checks only through a new base: when one lands on `develop`,
re-pin the `FROM` to that commit's `hive/haf:<commit>` image, rebuild and re-pin **in
the same commit**:

```bash
.aidev/runtime/build.sh --push   # registry digest if aidev-<input hash> exists, else build + push
# put the printed repo@sha256:<digest> into project.yaml environment.image
```

`AIDEV_IMAGE_CACHE_BY_REGION` (`region=host:port` pairs) builds through a pull-through
registry cache near the build host; unset, it builds straight from
`registry.gitlab.syncad.com`.
