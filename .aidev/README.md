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
`test-results/<suite>/hfm-functional.xml`, one case per functional test
(`hfm-functional::<folder>/<test>`). A step whose failing tests
`hfm-functional.xml` records is reported skipped in `junit.xml`, pointing there, so
each failure is reported once, under the test's own id; a step that fails with no
failing test recorded (a crash, a broken setup) fails as itself.

`.aidev/run-checks.sh <suite> <step>... --rerun <id>...` re-runs only the named
functional tests, through the listed step that owns them, and reports to
`test-results/<suite>/rerun/<n>/`, leaving the original run's reports in place.
That is under the slot's declared `artifacts:` path, so aidev's causality check
reads a re-run on the base tree: an id its report does not name is absent on
base, a new test, not a pre-existing failure. aidev reads only reports written
after the run it grades started, and reads and keeps a run's reports before
re-running its failures, so a re-run never adds to the run it re-runs; the suite's
next run (`rm -rf test-results/<suite>`) removes it.
An argument is a reported id, a test's `.sql` path, or a Perl regex over the
names (`HFM_TEST_FILTER`); a literal id that names no test fails the re-run.
The gate slots declare this as their `rerun:` (aidev's isolation re-run and
same-SHA flake detection) and `honor_quarantine: true`: a failing test listed in
`known_failures.txt` (`aidev test quarantine <id> --reason "see #N"`) is pardoned.

| Step | What |
|---|---|
| `hfm-smoke` | the functional tests under `hive_fork_manager/context_rewind/` and `hive_fork_manager/app_api/` (200) |
| `hfm-functional` | every `hive_fork_manager` and `query_supervisor` functional test ctest registers (441) and `hive_fork_manager/test_update_script`; `RUN_SERIAL` tests run alone after the rest, `test_update_script` last |
| `cxx-scope` | a skipped case naming the candidate's changed C++/CMake/`hive` files other than libhfm's (`src/hive_fork_manager/shared_lib/`) and libquery_supervisor's (`src/query_supervisor/`), which these checks do not verify |

How the functional tests run (`.aidev/hfm-functional.sh`): inside the HAF image, as the
maintenance script of `/home/hived/docker_entrypoint.sh` (which starts PostgreSQL), the
way CI's `hfm_functional_tests` runs `scripts/maintenance-scripts/run_hfm_functional_tests.sh`.
It installs the candidate's extension SQL as `Dockerfile.sql-overlay` does
(`scripts/generate_extension_sql.sh`, then `libhfm-<version>.so` pointed at the image's own
`libhfm`). If that SQL declares a C function the image's `libhfm` does not export
(`.aidev/missing_c_symbols.py`), it records a single failing case `hfm/libhfm-symbols`
naming the symbols and runs no test: the image's libhfm was not built from these sources,
see *The test runtime image*.
Otherwise it reads the test list from the `ADD_SQL_FUNCTIONAL_TEST` lines and `RUN_SERIAL`
properties of `tests/integration/functional/{hive_fork_manager,query_supervisor}/CMakeLists.txt`,
and runs each through `tools/test.sh` (8 at a time; `HFM_TEST_JOBS`), so no CMake configure
and no `hive` submodule checkout is needed. The entrypoint needs the image's
sudo-capable `hived` user, uid 1000 — the uid AIDEV's pull hosts and workers run as;
`run-checks.sh` fails with that reason under any other uid.

When `hive_fork_manager/CMakeLists.txt` registers `test_update_script` (CI's ctest runs it
after the functional tests), `hfm-functional` runs `test_update_script.sh` too, alone after
every other test, as `hfm-functional::hive_fork_manager/test_update_script`: it updates the
extension the step installed (about 2 minutes), with the update-script generator
`generate_extension_sql.sh` writes from the candidate's
`hive_fork_manager_update_script_generator.sh.in`. So every `full`, `canary` and `baseline`
run covers the update path, whatever the candidate changed; `quick` does not. To run it alone
(`full` has two suites, so pass-through arguments name one with `--suite`):

```bash
aidev test run --slot full --suite hfm_functional -- --rerun hfm-functional::hive_fork_manager/test_update_script
```

| Slot | Suites: steps |
|---|---|
| quick, coverage | hfm-smoke (+ cxx-scope on quick) |
| full | `hfm_functional`: hfm-functional, cxx-scope; `haf_system`: the HAF system tests the change selects (*The haf-system suite*) |
| canary | hfm-functional, cxx-scope |
| baseline | hfm-functional |

Not covered yet: hived's C++ build (only libhfm and libquery_supervisor are built), the C++ unit tests, `test.functional.update.*` (each functional
test re-run on a database updated by the generator; CI runs them on develop and master only), replay, forking and application tests, the system
tests no change selects (and all of them on `canary` and `baseline`), and shellcheck (`scripts/` has 8 error-severity findings today). They stay in
GitLab CI.

To run by hand:

```bash
docker run --rm --network none --user 1000:1000 -v "$PWD:/work" -w /work \
    "$(grep -o 'registry[^"]*aidev-tests@sha256:[0-9a-f]*' .aidev/project.yaml)" \
    .aidev/run-checks.sh full hfm-functional
```

## The haf-system suite (`verification.full`, `haf_system`)

The HAF system tests (`tests/integration/system/haf/`) drive a testnet hived
(`BUILD_HIVE_TESTNET`) that feeds a HAF database; CI runs them as `haf_system_tests`
in the `haf_image_build_testnet` image. The `full` slot's `haf_system` suite runs
the ones the candidate's change selects, in an image of its own (the suite's
`image:`; aidev `docs/architecture/verification-slots.md`, *A suite may run in its
own image*), which AIDEV pulls through the region cache before the slot is timed:
an image it cannot obtain refuses the slot as a retriable infrastructure failure,
not a red.

**Change-scoped.** `.aidev/haf-system-select.sh` is the suite's `select`, and
`.aidev/run-haf-system.sh` runs it again for the list. It reads the change from
`AIDEV_CHANGED_FILES_FILE` (else `git diff` from `AIDEV_BASE_REF`):

| The change touches | Tests run |
|---|---|
| `tests/integration/system/haf/test_<x>.py` (still present) | that module |
| any other path under `tests/integration/system/haf/` or `tests/integration/haf-local-tools/`, `src/hive_fork_manager/hived_api.sql`, `src/sql_serializer/` | the core modules in `.aidev/haf-system-tests.txt` (about 5 minutes, 4 at a time; `HAF_SYSTEM_JOBS`) |
| none of these | none: the select exits 77 and the suite is reported skipped, its reason `the change touches none of …` |
| unknown (no changed-files list or base ref, e.g. a by-hand run) | the core modules |

A changed module is run whole, under the image's testnet hived, as CI's job runs it
(`-m "not mirrornet"`, its binaries and `HELPY_*` settings, `PG_ACCESS` trusting
127.0.0.1).

**The candidate's SQL.** `.aidev/haf-system.sh`, the entrypoint's maintenance script,
installs the candidate's hive_fork_manager SQL with `.aidev/install-candidate-hfm.sh`
(the same install `hfm-functional` does) and then recreates `haf_block_log` with
the candidate's `scripts/setup_db.sh`. Every `HafNode` database is a copy of
`haf_block_log` (`create_database(…, template="haf_block_log")`), so the hived of
every test connects to the candidate's `hive.connect()` and the rest of its SQL.

**Reports.** `test-results/haf-system/junit.xml`: one case per test, its id
`haf-system::<module>.py::<test>[<param>]` (pytest's node id under the suite's name),
so `known_failures.txt` can pardon one (`honor_quarantine`) and the flake layers
re-run one by node id (`rerun:`, `run-haf-system.sh --rerun <id>...`, reporting to
`test-results/haf-system/rerun/<n>/`). A failed setup is one failing case of its own:
`haf-system/environment` (the image's venv was built from another `poetry.lock`),
`haf-system/libhfm-symbols` (the candidate's SQL declares a C function the image's
libhfm lacks), `haf-system/install` or `haf-system/setup_db`; a run that failed with no
failing test recorded is `haf-system/run`. test_tools' node directories
(`generated_during_<module>/`) are moved into `test-results/haf-system/generated/`,
kept with a failing run's artifacts. To run one test:

```bash
aidev test run --slot full --suite haf_system -- --rerun haf-system::test_replay_restart_over_populated_db.py::test_force_replay_over_populated_database_is_refused
```

**The image** (`runtime/Dockerfile.system`, `registry.gitlab.syncad.com/hive/haf/aidev-system-tests`):
`hive/haf/testnet:v-l2-6f476cfd`, the testnet image of develop 46558ea2e — the same
commit as the mainnet base — pinned by digest, plus a venv holding
`tests/integration/haf-local-tools`' locked dependencies (`poetry install --no-root`).
AIDEV runs a suite container with no network, so nothing is installed at run time,
unlike CI's `run_haf_system_tests.sh`; `haf_local_tools` itself is imported from the
candidate's tree. hived and libhfm are the image's: a candidate's C++ change to
`src/sql_serializer/` selects the core tests but runs them under the pinned hived
(`cxx-scope` names it), and a C function its SQL newly needs is
`haf-system/libhfm-symbols`. Re-pin the image with the mainnet base, and rebuild it
**in the same commit** as any change to haf-local-tools' `pyproject.toml` or
`poetry.lock` (until then the suite fails as `haf-system/environment`):

```bash
.aidev/runtime/build.sh --system --push   # registry digest if aidev-<input hash> exists, else build + push
# put the printed repo@sha256:<digest> into project.yaml's haf_system `image:`
```

To run it by hand (all the core tests; mount a changed-files list at
`/aidev-artifacts/changed-files.txt` and set `AIDEV_CHANGED_FILES_FILE` to scope it):

```bash
docker run --rm --network none --user 1000:1000 -v "$PWD:/work" -w /work \
    "$(grep -o 'registry[^"]*aidev-system-tests@sha256:[0-9a-f]*' .aidev/project.yaml)" \
    .aidev/run-haf-system.sh
```

## The test runtime image (`runtime/`)

AIDEV picks the image each slot runs in from the tree's native sources
(`environment.source_image`; aidev `docs/operations/project-source-image.md`). It
finds the newest commit that changed `source_image.paths` (outside `exclude`), then:

1. **CI built it**: the registry holds `hive/haf:<commit[:8]>`. That image runs,
   entrypoint cleared, and nothing is built.
2. **CI did not**: the usual case, since CI runs no pipeline for `ai/*`,
   `session/*` or `aidev/integration` pushes. AIDEV builds
   `runtime/Dockerfile.source` from the candidate's checkout, handing it the pinned
   `environment.image` as `BASE_IMAGE`, pushes it to its runtime registry as
   `aidev-runtime/haf-source:<commit[:8]>-<recipe digest>`, and runs it. The phase
   log's runtime line names it `aidev-built`. A later slot or attempt on the same
   source commit and recipe reuses that tag rather than building again (on the
   same host, with AIDEV's default host-local registry).
3. **No commit touched the paths**: the pinned `environment.image` runs.

`Dockerfile.source` compiles only what the functional suites load from C++:
libhfm (`src/hive_fork_manager/shared_lib`) and libquery_supervisor
(`src/query_supervisor`), with what they link from `hive` (hive_protocol, fc). Its
builder is the `ci-base-image` stage of `Dockerfile` (the CI toolchain image pinned
by digest, plus `scripts/setup_ubuntu.sh --dev`), configured as CI's
`scripts/build.sh` does (Release, Ninja, mainnet). The final stage is the pinned
image with both libraries overwritten in place, keeping the base's file names so
the base's extension files still load them, and its entrypoint cleared. hived and
the rest of the image stay the pinned base's.

Because the image is reused by source commit, the recipe reads only source paths:
`CMakeLists.txt`, `cmake/`, `common_includes/`, `src/`, `hive/` and the two
`setup_ubuntu.sh` scripts. It installs no extension SQL (`*.sql` is excluded; the
suites install the candidate's own). The root `CMakeLists.txt` adds `tests/`, which
is not a source path, so the build configures with an empty stand-in. The `hive`
submodule reaches the context because AIDEV checks out a candidate worktree with
its submodules; the build fails at once, as the candidate's build failure, when
`hive/` is empty. A step that fails on the candidate's sources is
`source_image_build_failed` and goes to a fix round; a build that cannot run at all
(daemon, registry, the 3600 s build bound outside a `RUN`/`COPY` step) is
`unverifiable_runtime`.

Build time, against aidev's 3600 s bound on `docker build`: on steem-11 (32 cores),
with both `FROM` images already pulled, 177 s with no layer cache (84 s for
`setup_ubuntu.sh --dev`, 90 s to configure and compile the two libraries); about
90 s once the toolchain layer is cached, since any source change reruns the
compile; 1 s when nothing changed. A host that has neither image first pulls the
3.6 GB toolchain image and the pinned base.

To build it by hand:

```bash
docker build --build-arg BASE_IMAGE="$(grep -o 'registry[^"]*aidev-tests@sha256:[0-9a-f]*' .aidev/project.yaml)" \
    -f .aidev/runtime/Dockerfile.source -t haf-source .
```

### The pinned base (`environment.image`)

The HAF image `hive/haf:6f476cfd` (develop 46558ea2e) with its entrypoint cleared,
pinned by digest: what case 3 runs, the base case 2 builds on, and what the by-hand
run above uses. Its hived, PostgreSQL and extension layout reach every slot, so
re-pin it when those should follow `develop` (and when the base's Ubuntu or
PostgreSQL changes, re-pin the builder `FROM` in `Dockerfile.source` with it, so the
libraries are built against the same system): re-pin the `FROM` to that commit's
`hive/haf:<commit>` image, rebuild and re-pin **in the same commit** (and the
`haf_system` image's `FROM` to the same commit's `hive/haf/testnet` image, *The
haf-system suite*):

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
and implemented in `shared-haf/`. A dedicated session, `haf-shared`, hosts it; the
service runs on that session's host (`aidev session list`; currently
steem-3.syncad.com):

```bash
aidev session create haf-shared --host <ZFS 2.4+ host> --remote git@gitlab.syncad.com:hive/haf.git \
    --target-branch aidev/integration --shared-service haf
```

Consumers declare `sandbox.external: [{name: haf, provider: "haf/haf"}]`, connect
to `$AIDEV_EXTERNAL_HAF_HOST:$AIDEV_EXTERNAL_HAF_PORT` as `haf_shared_consumer`
(no password, no secret), and per run:

```sql
-- in database haf_shared
select haf_shared.clone_run_database('<run id>');   -- returns run_<run id>; connect to it
select haf_shared.drop_run_database('<run id>');    -- when done
select * from haf_shared.health();                  -- HAF commit, template head block, live clones
```

A run id is 1-48 of `[a-z0-9_-]`. The clone is owned by the consumer, who is a
`hive_applications_owner_group` member inside it.

**Access.** Over TCP only `haf_shared_consumer` can log in, only to `haf_shared`
and `run_*` databases, and only from fleet addresses, where it is trusted
without a password: `192.168.3.0/24`, `192.168.5.0/24` and `192.168.6.0/24`
(the sites' LANs), `100.64.0.0/10` (the inter-site VPN: it carries only fleet
traffic between the site gateways, so a consumer at another site, e.g. a PL
pull host reaching a US provider, arrives with a source address in it), and
`172.16.0.0/12` (connections from the provider host itself arrive through
docker's NAT). The data is public chain data, so the VPN is trusted like the
LANs; what either can do is create and drop clones. The rules are the `haf`
service's `PG_ACCESS`, which replaces the image's own trust rule; the shared
hivemind service (hive/hivemind) keeps a copy of the same list, so a range
added here is added there too.

**App roles.** Installing a HAF app creates cluster-wide roles, which the
consumer may not do (PostgreSQL checks `CREATEROLE` before noticing the role
exists). The provider creates them instead: `shared-haf/app-roles/` holds one
SQL file per consumer app, which `serve.sh` applies as `postgres` on every start,
before serving. Each creates the app's roles idempotently and makes
`haf_shared_consumer` (and `haf_admin`) a member of the app's owner role, so they
survive a reseed or a new version. Every run shares them; an app's roles are the
same across its versions:

- `app-roles/hafah.sql`: HAfAH's `hafah_owner` and `hafah_user`;
- `app-roles/btracker.sql`: balance_tracker's `btracker_owner` and `btracker_user`;
- `app-roles/reptracker.sql`: reputation_tracker's `reptracker_owner` and
  `reptracker_user`;
- `app-roles/l2_framework.sql`: l2_framework's `l2_framework_owner` and
  `l2_framework_user`;
- `app-roles/hafbe.sql`: haf_block_explorer's `hafbe_owner` and `hafbe_user`,
  members of hafah's, btracker's and reptracker's owner and user roles above,
  and `hafbe_user` also of `l2_framework_user`;
- `app-roles/haf_stats.sql`: haf_stats' `haf_stats_owner` and `haf_stats_user`
  (NOINHERIT, in no HAF group);
- `app-roles/haf_fyp.sql`: haf_fyp's `haf_fyp_owner` and `haf_fyp_user` (in no
  HAF group, which haf_fyp's install asserts).

An app's roles may be members of another app's, so `serve.sh` applies the files
in the explicit order of its `app_roles` list (hafbe after hafah, btracker,
reptracker and l2_framework), and refuses to serve when `app-roles/` or
`app-grants/` holds a file that list does not name.

An app whose user role is NOINHERIT (or in no HAF group) gets no HAF data through
group membership: its install grants the role its reads per database, which the
consumer cannot do in a clone, as it holds no grant option on `hafd` and `hive`.
`shared-haf/app-grants/` holds those per-database grants, one SQL file per app
that needs them, which `serve.sh` applies as `postgres` in `haf_template` on every
start, after the freeze (briefly allowing connections to it), so every later clone
of any version carries them; clones made before stay as they are:

- `app-grants/haf_stats.sql`: `USAGE` on `hafd` and `hive`, `SELECT` on all their
  tables and `EXECUTE` on all functions in `hive`, to `haf_stats_owner` and
  `haf_stats_user` (the `hafd`/`hive` block of haf_stats' `db/builtin_roles.sql`). To install an app in its clone, the consumer (the clone's owner) first
grants the app's roles the database:

```sql
-- in run_<run id>, as haf_shared_consumer
-- HAfAH:
grant create, connect on database run_<run id> to hafah_owner, hafah_user;
-- haf_block_explorer (with balance_tracker, reputation_tracker and l2_framework):
grant create, connect on database run_<run id> to hafbe_owner, hafbe_user, btracker_owner, btracker_user, reptracker_owner, reptracker_user, l2_framework_owner, l2_framework_user;
-- haf_stats:
grant create, connect on database run_<run id> to haf_stats_owner, haf_stats_user;
-- haf_fyp:
grant create, connect on database run_<run id> to haf_fyp_owner, haf_fyp_user;
```

then runs the app's install as the consumer, skipping its own role-creation step
(HAfAH: `scripts/install_app.sh` without `db/builtin_roles.sql`;
haf_block_explorer: `scripts/install_app.sh` without the `db/builtin_roles.sql`
of itself, balance_tracker, reputation_tracker and l2_framework, installing
l2_framework's `l2` schema as `l2_framework_owner`; haf_stats and haf_fyp: their
`db/builtin_roles.sql` also makes per-database grants and assertions, so their
installs need a step the consumer can run in place of it; haf_stats' grants are in
`app-grants/`). A new consumer app
adds its file to `app-roles/` (and, if it needs per-database grants, to
`app-grants/`) and to `serve.sh`'s `app_roles`, after the apps whose roles
it depends on, and restarts the service.

**How it works.** Both services run the plain `hive/haf` image of the served
version, pinned by digest (`HAF_IMAGE`); `HAF_VERSION`, its full HAF commit,
names the version's directory in the data root. The one-shot `seed` service
(`seed.sh`) refuses a data root that is not ZFS and, on the first start of a
version, builds the cluster by replaying the first 5,000,000 blocks of
`$HAF_SHARED_DATA_ROOT/block_log_5m/block_log` in that image, as CI's
`prepare_haf_data` does (`docker/config_5M.ini`, `--replay-blockchain
--stop-at-block=5000000`). It works in `<version>.partial` on a copy of the
block log (a free block clone; the block log itself is never written), checks
that PostgreSQL shut down cleanly and that `haf_block_log` is at head block
5,000,000, relinks the tablespace relative to `pgdata` (`../../tablespace`, as in
CI's replay caches), keeps only `haf_db_store` and only then moves it to
`$HAF_SHARED_DATA_ROOT/<version>/haf_db_store`. An interrupted replay leaves only
the partial directory, which the next start removes and redoes. Later starts
find the cluster and exit at once; with neither the cluster nor the block log
`seed` fails, naming the missing path. `haf` starts only once `seed` has
succeeded, with that directory bind-mounted directly at the image's
`/home/hived/datadir/haf_db_store`. It must not be a symlink: the image's
`setup_postgres.sh` compares the tablespace's resolved location with the
unresolved expected path, aborting when they differ. `start.sh` (the `haf` entrypoint) checks the
mount, sets `file_copy_method = clone` and runs the HAF entrypoint with
`serve.sh` as its maintenance script. `serve.sh` installs
`admin.sql` into the `haf_shared` database, applies `app-roles/`, and once per version freezes
`haf_template`, a clone of `haf_block_log` with its head block recorded, that
no one may connect to. `haf_block_log` itself stays connectable because the
entrypoint checks and updates the extension in it on every start. Clones are
`CREATE DATABASE run_<id> TEMPLATE haf_template STRATEGY FILE_COPY` through a
`dblink` loopback (CREATE/DROP DATABASE cannot run in a function). Every 5 minutes
a reaper drops clones older than `HAF_SHARED_RUN_TTL` (6 hours), and `run_*`
databases no run is registered for. A drop (by a consumer or the reaper)
first terminates the clone's connections and gives up after 2 minutes, raising
`object_in_use` with the backends that may block it: DROP DATABASE waits for
every backend of the cluster, and one waiting for a vanished client inside COPY
FROM STDIN never answers. The server's TCP keepalives (`shared-haf/postgresql.conf`)
end such a backend within about a minute.

AIDEV runs `docker compose` inside the session's worker container against the
host's docker daemon, which resolves bind sources on the host. The `shared-haf/`
bind therefore reads the checkout through `${AIDEV_HOST_CHECKOUT}` (the checkout's
path as the daemon sees it), not a relative `./shared-haf`, which would name a
worker-side path the daemon would create as an empty directory. With
`AIDEV_HOST_CHECKOUT` unset the compose file refuses to resolve.

**Host setup (once, on the `haf-shared` session's host).** The data root must be
a dataset on a pool with `feature@block_cloning`, which needs ZFS 2.4+
(steem-9/steem-17's 2.2.2 cannot clone); that is what qualifies a host. The pool
may be a file vdev. The data root also holds the 5M block log every version is
replayed from (1,684,661,073 bytes). No credential is provisioned: consumers are
trusted by source address (above).

```bash
sudo zfs create <pool>/aidev-shared-haf              # steem-3: tank/aidev-shared-haf, mounted at /haf-pool/aidev-shared-haf
sudo mkdir -p <data root>/block_log_5m
sudo curl -o <data root>/block_log_5m/block_log https://gtg.openhive.network/get/blockchain/block_log.5M
```

**Finding the running service.** Live changes, such as applying an `app-roles/`
or `app-grants/` file without a restart, need the `haf` container. On the
session's host it is the `hive/haf` container whose name ends in `-haf-1`
(other stacks there may run the same image):

```bash
aidev session list | grep haf-shared                 # the host
ssh <host> 'docker ps --format "{{.Names}} {{.Image}}" | grep "hive/haf:"'
# e.g. aidev-devstack-2b7c74563c165c01-haf-1 registry.gitlab.syncad.com/hive/haf:<tag>@sha256:<digest>
ssh <host> 'docker exec -i -u postgres <container> psql -X -v ON_ERROR_STOP=1 -d postgres' < shared-haf/app-roles/<app>.sql
```

An `app-grants/` file goes to `haf_template` instead, which refuses connections:
allow them around it as `serve.sh` does.

**Changing the served version.** Set `HAF_IMAGE` in `project.yaml` to the
`registry.gitlab.syncad.com/hive/haf:<tag>@sha256:<digest>` image of the version,
pinned by digest (the registry deletes old tags, so the digest is what keeps it
pullable), and `HAF_VERSION` to the full HAF commit that image was built from
(the pipeline's `HAF_COMMIT`). AIDEV keeps the hosting session's service checkout
fixed, so a push does not restart a running service: restart it to switch. The
new version is replayed beside the old one, whose directory can be destroyed once
nothing uses it.

The replay fits inside `readiness_timeout` (1800 s, AIDEV's ceiling): on session24.pl
(32 cores, ZFS on NVMe) the whole seed of 17c8606f took about 6 minutes. A slower host
can seed the version by hand first, with the service's own script, image and mounts;
the service then finds it seeded:

```bash
docker run --rm --entrypoint /aidev/shared-haf/seed.sh \
    -e HAF_VERSION=<version> -e HAF_SHARED_ROOT=/haf-shared -e PG_ACCESS= \
    -v <data root>:/haf-shared \
    -v <checkout>/.aidev/shared-haf:/aidev/shared-haf:ro \
    -v <checkout>/docker/config_5M.ini:/aidev/config_5M.ini:ro \
    <HAF_IMAGE>
```

To serve two versions at once,
add a second service of the same shape with its own port name.
