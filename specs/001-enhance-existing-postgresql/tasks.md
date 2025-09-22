# Tasks: Enhance PostgreSQL Container Maintainability

**Input**: Design documents from `/specs/001-enhance-existing-postgresql/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Container project**: `containers/docker/postgresql/entrypoint.d/scripts/` for runtime scripts
- **Build-time scripts**: `containers/docker/postgresql/setup/scripts/` for installation
- **Tests**: `containers/docker/postgresql/entrypoint.d/scripts/test/` for container tests

## Phase 3.1: Setup
- [ ] T001 Create entrypoint.d/scripts directory structure in containers/docker/postgresql/
- [ ] T002 [P] Create utils/ subdirectory and template files
- [ ] T003 [P] Create init/ subdirectory and template files
- [ ] T004 [P] Create runtime/ subdirectory and template files
- [ ] T005 [P] Create test/ subdirectory and template files

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T006 [P] Contract test for script interfaces in containers/docker/postgresql/entrypoint.d/scripts/test/unit/test_script_interfaces.bats
- [ ] T007 [P] Contract test for configuration management in containers/docker/postgresql/entrypoint.d/scripts/test/unit/test_config_management.bats
- [ ] T008 [P] Integration test for container startup scenarios in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_startup.bats
- [ ] T009 [P] Integration test for graceful shutdown in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_shutdown.bats
- [ ] T010 [P] Integration test for configuration handling in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_config.bats
- [ ] T011 [P] Integration test for Patroni mode in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_patroni.bats

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T012 [P] Implement logging.sh utility in containers/docker/postgresql/entrypoint.d/scripts/utils/logging.sh
- [ ] T013 [P] Implement validation.sh utility in containers/docker/postgresql/entrypoint.d/scripts/utils/validation.sh
- [ ] T014 [P] Implement security.sh utility in containers/docker/postgresql/entrypoint.d/scripts/utils/security.sh
- [ ] T015 [P] Implement 01-directories.sh init script in containers/docker/postgresql/entrypoint.d/scripts/init/01-directories.sh
- [ ] T016 [P] Implement 02-database.sh init script in containers/docker/postgresql/entrypoint.d/scripts/init/02-database.sh
- [ ] T017 [P] Implement 03-config.sh init script in containers/docker/postgresql/entrypoint.d/scripts/init/03-config.sh
- [ ] T018 [P] Implement 04-backup.sh init script in containers/docker/postgresql/entrypoint.d/scripts/init/04-backup.sh
- [ ] T019 [P] Implement startup.sh runtime script in containers/docker/postgresql/entrypoint.d/scripts/runtime/startup.sh
- [ ] T020 [P] Implement shutdown.sh runtime script in containers/docker/postgresql/entrypoint.d/scripts/runtime/shutdown.sh
- [ ] T021 [P] Implement healthcheck.sh runtime script in containers/docker/postgresql/entrypoint.d/scripts/runtime/healthcheck.sh

## Phase 3.4: Integration
- [ ] T022 Create main entrypoint.sh orchestrator in containers/docker/postgresql/entrypoint.d/entrypoint.sh
- [ ] T023 Integrate modular scripts with existing setup.sh build process
- [ ] T024 Update Dockerfile to use new entrypoint.d structure
- [ ] T025 Test backward compatibility with existing container behavior
- [ ] T026 Validate configuration file handling across all scenarios

## Phase 3.5: Polish
- [ ] T027 [P] Create run_tests.sh test runner in containers/docker/postgresql/entrypoint.d/scripts/test/run_tests.sh
- [ ] T028 [P] Install and configure BATS testing framework
- [ ] T029 [P] Create test fixtures and mock data in containers/docker/postgresql/entrypoint.d/scripts/test/fixtures/
- [ ] T030 [P] Performance test startup time (<30 seconds) in containers/docker/postgresql/entrypoint.d/scripts/test/performance/test_startup_time.bats
- [ ] T031 [P] Performance test shutdown time (<30 seconds) in containers/docker/postgresql/entrypoint.d/scripts/test/performance/test_shutdown_time.bats
- [ ] T032 [P] Update container documentation in containers/docker/postgresql/README.md
- [ ] T033 [P] Create troubleshooting guide for new modular structure

## Dependencies
- Tests (T006-T011) before implementation (T012-T021)
- T001-T005 before all other tasks
- T022-T026 after T012-T021 (integration after core implementation)
- T027-T033 after T022-T026 (polish after integration)
- T012-T014 (utils) can be parallel with T015-T018 (init scripts)
- T019-T021 (runtime) depend on T012-T014 (utils)

## Parallel Example
```
# Launch T006-T011 together (all contract and integration tests):
Task: "Contract test for script interfaces in containers/docker/postgresql/entrypoint.d/scripts/test/unit/test_script_interfaces.bats"
Task: "Contract test for configuration management in containers/docker/postgresql/entrypoint.d/scripts/test/unit/test_config_management.bats"
Task: "Integration test for container startup scenarios in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_startup.bats"
Task: "Integration test for graceful shutdown in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_shutdown.bats"
Task: "Integration test for configuration handling in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_config.bats"
Task: "Integration test for Patroni mode in containers/docker/postgresql/entrypoint.d/scripts/test/integration/test_patroni.bats"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing (TDD principle)
- Commit after each task completion
- All scripts must follow POSIX standards and include proper error handling
- Maintain backward compatibility with existing container behavior
- Focus on security, maintainability, and comprehensive testing

## Task Generation Rules Applied
- Each contract file → contract test task marked [P] (T006-T007)
- Each script module from data-model → implementation task marked [P] (T012-T021)
- Each user scenario from spec → integration test marked [P] (T008-T011)
- Different files = marked [P] for parallel execution
- Tests before implementation following TDD principles
- Dependencies clearly defined to prevent conflicts