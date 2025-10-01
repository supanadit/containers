# Container Tasks: Support Citus PostgreSQL

**Input**: Container design documents from `/home/supanadit/Workspace/Personal/Docker/containers/specs/003-support-citus-postgresql/`
**Prerequisites**: plan.md (required), research.md, dockerfile-design.md, configuration.md, contracts/, quickstart.md

## Container Execution Flow (main)
```
1. Load plan.md from container directory
   → If not found: ERROR "No container implementation plan found"
   → Extract: container type, base image, runtime, structure
2. Load container design documents:
   → dockerfile-design.md: Extract build stages → Dockerfile tasks
   → configuration.md: Extract config templates → configuration tasks
   → research.md: Extract base image decisions → setup tasks
   → contracts/: Extract SQL API contracts → test tasks
   → quickstart.md: Extract usage scenarios → integration test tasks
3. Generate container tasks by category:
   → Setup: Environment variables, configuration updates
   → Core: Entrypoint modifications, Citus enablement scripts
   → Integration: Patroni compatibility, cluster coordination
   → Testing: Standalone mode, cluster mode, SQL API validation
   → Polish: Documentation updates, performance validation
4. Apply container task rules:
   → Different files = mark [P] for parallel
   → Same file modifications = sequential (no [P])
   → Setup before core implementation
   → Core before integration features
   → Implementation before testing
   → Testing before polish/validation
5. Number tasks sequentially (T001, T002...)
6. Generate container dependency graph
7. Create parallel build examples
8. Validate container task completeness:
   → All Citus enablement logic implemented?
   → All configuration scenarios covered?
   → All usage modes tested?
   → Security and performance validated?
9. Return: SUCCESS (container tasks ready for execution)
```

## Format: `[T-ID] [P?] Container Task Description`
- **[P]**: Can run in parallel (different files, no shared dependencies)
- Include exact container file paths in descriptions
- Use T### numbering for container tasks (T001, T002, etc.)

## Container Path Conventions
- **Container root**: `docker/postgresql/`
- **Existing structure**: Following established PostgreSQL container patterns
- **New files**: Place in appropriate subdirectories per container conventions

## Phase 3.1: Container Setup
- [x] T001 Update Dockerfile to add Citus environment variables in runtime stage
- [x] T002 Validate Citus installation in existing setup scripts

## Phase 3.2: Core Citus Implementation
- [x] T003 Modify entrypoint.d/scripts/init/03-config.sh to enable Citus extension when CITUS_ENABLE=true
- [x] T004 Add Citus configuration parameters to postgresql.conf based on CITUS_ROLE
- [x] T005 Create Citus initialization script for metadata setup and role configuration
- [x] T006 Update entrypoint.d/scripts/runtime/healthcheck.sh to validate Citus functionality

## Phase 3.3: Integration Features
- [x] T007 Add Patroni integration for Citus coordinator/worker role management
- [x] T008 Implement Citus metadata persistence across Patroni failovers
- [x] T009 Configure Citus worker auto-discovery in Patroni clusters

## Phase 3.4: Container Testing
- [x] T010 [P] Create Citus standalone mode test in tests/integration_test.sh
- [x] T011 [P] Create Citus cluster mode test in tests/integration_test.sh
- [x] T012 [P] Create Citus SQL API contract validation test in tests/unit_test.sh
- [x] T013 [P] Create Patroni + Citus integration test in tests/integration_test.sh
- [x] T014 [P] Create Citus security validation test in tests/security_test.sh

## Phase 3.5: Container Polish & Validation
- [x] T015 Update README.md with Citus usage examples and configuration options
- [x] T016 Update TROUBLESHOOTING.md with Citus-specific issues and solutions
- [ ] T017 [P] Create Citus performance benchmark test in tests/performance_test.sh
- [ ] T018 [P] Validate Citus startup time meets <60s requirement
- [ ] T019 [P] Run final Citus integration test suite
- [ ] T020 Update container labels and metadata for Citus support

## Container Dependencies
- Setup (T001-T002) before core implementation (T003-T006)
- Core (T003-T006) before integration features (T007-T009)
- Implementation (T001-T009) before testing (T010-T014)
- Testing (T010-T014) before polish/validation (T015-T020)
- T003 (config script) blocks T004 (postgresql.conf), T005 (init script)
- T007 (Patroni integration) blocks T008 (metadata persistence), T009 (auto-discovery)
- Parallel tests (T010-T014) can run after T009 completion
- Documentation updates (T015-T016) can run in parallel with performance tests (T017-T019)

## Parallel Execution Examples
```bash
# Run parallel tests after implementation complete
task T010 & task T011 & task T012 & task T013 & task T014

# Run polish tasks in parallel
task T017 & task T018 & task T019
```

## Container Task Validation Checklist
- [x] Citus extension enablement implemented in entrypoint scripts?
- [x] All CITUS_* environment variables documented and handled?
- [x] Standalone and cluster modes fully supported?
- [x] Patroni integration handles Citus roles correctly?
- [x] SQL API contracts validated through automated tests?
- [ ] Performance requirements (<60s startup, <500MB image) maintained?
- [ ] Security hardening preserved with Citus additions?
- [x] Documentation updated with Citus usage examples?
- [ ] All edge cases from spec addressed (failover, network partitions)?