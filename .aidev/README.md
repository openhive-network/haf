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
`libhfm`). If that SQL declares a C function the image's `libhfm` does not export
(`.aidev/missing_c_symbols.py`), it records a single failing case `hfm/libhfm-symbols`
naming the symbols and runs no test: the image is stale, see *The test runtime image*.
Otherwise it reads the test list from the `ADD_SQL_FUNCTIONAL_TEST` lines and `RUN_SERIAL`
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

The HAF image `hive/haf:6f476cfd` (develop 46558ea2e) with its entrypoint cleared, pinned by digest. A C++
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
- `app-roles/hafbe.sql`: haf_block_explorer's `hafbe_owner` and `hafbe_user`,
  members of the three apps' owner and user roles above;
- `app-roles/haf_stats.sql`: haf_stats' `haf_stats_owner` and `haf_stats_user`
  (NOINHERIT, in no HAF group);
- `app-roles/haf_fyp.sql`: haf_fyp's `haf_fyp_owner` and `haf_fyp_user` (in no
  HAF group, which haf_fyp's install asserts).

An app's roles may be members of another app's, so `serve.sh` applies the files
in the explicit order of its `app_roles` list (hafbe after hafah, btracker and
reptracker), and refuses to serve when `app-roles/` or `app-grants/` holds a file
that list does not name.

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
-- haf_block_explorer (with balance_tracker and reputation_tracker):
grant create, connect on database run_<run id> to hafbe_owner, hafbe_user, btracker_owner, btracker_user, reptracker_owner, reptracker_user;
-- haf_stats:
grant create, connect on database run_<run id> to haf_stats_owner, haf_stats_user;
-- haf_fyp:
grant create, connect on database run_<run id> to haf_fyp_owner, haf_fyp_user;
```

then runs the app's install as the consumer, skipping its own role-creation step
(HAfAH: `scripts/install_app.sh` without `db/builtin_roles.sql`;
haf_block_explorer: `scripts/install_app.sh` without the `db/builtin_roles.sql`
of itself, balance_tracker and reputation_tracker; haf_stats and haf_fyp: their
`db/builtin_roles.sql` also makes per-database grants and assertions, so their
installs need a step the consumer can run in place of it; haf_stats' grants are in
`app-grants/`). A new consumer app
adds its file to `app-roles/` (and, if it needs per-database grants, to
`app-grants/`) and to `serve.sh`'s `app_roles`, after the apps whose roles
it depends on, and restarts the service.

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
`admin.sql` into the `haf_shared` database, applies `app-roles/`, and once per version freezes
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

**Host setup (once, on the `haf-shared` session's host).** The data root must be
a dataset on a pool with `feature@block_cloning` (ZFS 2.4+; steem-9/steem-17's
2.2.2 cannot clone); that is what qualifies a host. No credential is provisioned:
consumers are trusted by source address (above).

```bash
sudo zfs create <pool>/aidev-shared-haf              # steem-3: tank/aidev-shared-haf, mounted at /haf-pool/aidev-shared-haf
```

**Finding the running service.** Live changes, such as applying an `app-roles/`
or `app-grants/` file without a restart, need the `haf` container. On the
session's host it is the `fixture-5m` container whose name ends in `-haf-1`
(other stacks there may run the same image):

```bash
aidev session list | grep haf-shared                 # the host
ssh <host> 'docker ps --format "{{.Names}} {{.Image}}" | grep fixture-5m'
# e.g. aidev-devstack-2b7c74563c165c01-haf-1 registry.gitlab.syncad.com/hive/haf/fixture-5m:<commit>
ssh <host> 'docker exec -i -u postgres <container> psql -X -v ON_ERROR_STOP=1 -d postgres' < shared-haf/app-roles/<app>.sql
```

An `app-grants/` file goes to `haf_template` instead, which refuses connections:
allow them around it as `serve.sh` does.

**Changing the served version.** Set `HAF_FIXTURE_COMMIT` and `HAF_FIXTURE_DIGEST`
in `project.yaml` to a `fixture-5m` image whose full-commit tag exists (the tag
means CI started it). AIDEV keeps the hosting session's service checkout fixed,
so a push does not restart a running service: restart it to switch. The new version is seeded beside the old one, whose
directory can be destroyed once nothing uses it. To serve two versions at once,
add a second service of the same shape with its own port name.
