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

## The shared HAF service (`sandbox.shared.haf`)

A persistent PostgreSQL that holds the 5M replay of a HAF version and gives each
test run, from any session, its own copy-on-write clone of it. It is declared
under `sandbox.shared.haf` in `project.yaml`, defined in `shared-haf.compose.yml`
and implemented in `shared-haf/`. A dedicated session hosts it:

```bash
aidev session create haf-shared --host steem-13 --remote git@gitlab.syncad.com:hive/haf.git \
    --target-branch aidev/integration --shared-service haf
```

Consumers declare `sandbox.external: [{name: haf, provider: "haf/haf"}]` and the
`HAF_PG_PASSWORD` secret, connect to `$AIDEV_EXTERNAL_HAF_HOST:$AIDEV_EXTERNAL_HAF_PORT`
as `haf_shared_consumer`, and per run:

```sql
-- in database haf_shared
select haf_shared.clone_run_database('<run id>');   -- returns run_<run id>; connect to it
select haf_shared.drop_run_database('<run id>');    -- when done
select * from haf_shared.health();                  -- HAF commit, template head block, live clones
```

A run id is 1-48 of `[a-z0-9_-]`. The clone is owned by the consumer, who is a
`hive_applications_owner_group` member inside it. Over TCP that role can reach
only `haf_shared` and `run_*` databases, with a password; no other role can log
in over TCP.

**How it works.** Both services run the `hive/haf/fixture-5m:<commit>` image
CI's `build_haf_fixture_image` publishes. The one-shot `seed` service
(`seed.sh`) refuses a data root that is not ZFS and, on the first start of a
version, copies the image's replayed cluster to
`$HAF_SHARED_DATA_ROOT/<commit>/haf_db_store`; later starts find it there and
exit at once. `haf` starts only once `seed` has succeeded, with that directory
bind-mounted directly at the image's `/home/hived/datadir/haf_db_store`. It must
not be a symlink: the cluster's tablespace link is relative, and the image's
`setup_postgres.sh` compares its resolved location with the unresolved expected
path, aborting when they differ. `start.sh` (the `haf` entrypoint) checks the
mount, sets `file_copy_method = clone` and runs the HAF entrypoint with
`serve.sh` as its maintenance script. `serve.sh` installs
`admin.sql` into the `haf_shared` database, and once per version freezes
`haf_template`, a clone of `haf_block_log` with its head block recorded, that
no one may connect to. `haf_block_log` itself stays connectable because the
entrypoint checks and updates the extension in it on every start. Clones are
`CREATE DATABASE run_<id> TEMPLATE haf_template STRATEGY FILE_COPY` through a
`dblink` loopback (CREATE/DROP DATABASE cannot run in a function). Every 5 minutes
a reaper drops clones older than `HAF_SHARED_RUN_TTL` (6 hours), and `run_*`
databases no run is registered for.

AIDEV runs `docker compose` inside the session's worker container against the
host's docker daemon, which resolves bind sources on the host. The `shared-haf/`
bind therefore reads the checkout through `${AIDEV_HOST_CHECKOUT}` (the checkout's
path as the daemon sees it), not a relative `./shared-haf`, which would name a
worker-side path the daemon would create as an empty directory. With
`AIDEV_HOST_CHECKOUT` unset the compose file refuses to resolve.

**Host setup (once, on steem-13).** The data root must be a dataset on a pool
with `feature@block_cloning` (ZFS 2.4+; steem-9/steem-17's 2.2.2 cannot clone),
and must hold the consumer password: the value of the fleet's `HAF_PG_PASSWORD`
secret, 16-128 characters of `[A-Za-z0-9._~+/=-]`. The service exits without it.

```bash
sudo zfs create haf-pool/aidev-shared-haf            # mounted at /haf-pool/aidev-shared-haf
sudo install -m 600 /dev/null /haf-pool/aidev-shared-haf/consumer.password
echo -n "$HAF_PG_PASSWORD" | sudo tee /haf-pool/aidev-shared-haf/consumer.password >/dev/null
```

**Changing the served version.** Set `HAF_FIXTURE_COMMIT` and `HAF_FIXTURE_DIGEST`
in `project.yaml` to a `fixture-5m` image whose full-commit tag exists (the tag
means CI started it). AIDEV keeps the hosting session's service checkout fixed,
so a push does not restart a running service: restart it to switch. The new version is seeded beside the old one, whose
directory can be destroyed once nothing uses it. To serve two versions at once,
add a second service of the same shape with its own port name.
