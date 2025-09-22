# Tasks: Optimize PostgreSQL Build Process

**Input**: Design documents from `/specs/002-reduce-build-time/`
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
   → Setup: container structure, base image selection, dependencies
   → Tests: container build tests, functionality tests, security scans
   → Core: Dockerfiles, entrypoint scripts, configuration files
   → Integration: multi-stage builds, layer optimization, orchestration
   → Polish: documentation, cleanup, performance validation
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All container specs have tests?
   → All build requirements have tasks?
   → All functionality implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single container**: `docker/postgresql/` with Dockerfile, entrypoint.sh, setup scripts
- Paths shown below assume single container - adjust based on plan.md structure

## Phase 3.1: Setup
- [x] T001 Create optimized directory structure for build layers in docker/postgresql/
- [x] T002 Select and validate base image for multi-stage build compatibility
- [x] T003 [P] Install build dependencies and validate PostgreSQL version compatibility

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [x] T004 [P] Script interface contract test in docker/postgresql/test/script_interface_test.sh
- [x] T005 [P] Build interface contract test in docker/postgresql/test/build_interface_test.sh
- [x] T006 [P] Build time optimization integration test in docker/postgresql/test/build_time_test.sh
- [x] T007 [P] Cache effectiveness validation test in docker/postgresql/test/cache_test.sh

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [x] T008 [P] Setup Layer entity implementation in docker/postgresql/Dockerfile (stable dependencies)
- [x] T009 [P] Entrypoint Layer entity implementation in docker/postgresql/Dockerfile (volatile scripts)
- [x] T010 [P] Cache Boundary entity implementation in docker/postgresql/Dockerfile (layer separation)
- [x] T011 Dockerfile restructuring with ordered COPY commands
- [x] T012 .dockerignore optimization for build context
- [x] T013 BuildKit configuration for advanced caching

## Phase 3.4: Integration
- [x] T014 Multi-stage build setup with setup and runtime stages
- [x] T015 Layer caching optimization for entrypoint changes
- [x] T016 Security hardening (non-root user, permissions) in Dockerfile
- [x] T017 Health check implementation with proper endpoints
- [x] T018 Environment variable handling and validation

## Phase 3.5: Polish
- [x] T019 [P] Performance validation (<30s startup, build time optimization)
- [x] T020 [P] Update container documentation with build optimization notes
- [x] T021 Build context optimization and cleanup
- [x] T022 Run integration tests and validate cache effectiveness
- [x] T023 Final security audit and vulnerability scanning

## Dependencies
- Tests (T004-T007) before implementation (T008-T013)
- T008 blocks T014, T015
- T009 blocks T016, T017
- T010 blocks T014, T015
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T007 together:
Task: "Script interface contract test in docker/postgresql/test/script_interface_test.sh"
Task: "Build interface contract test in docker/postgresql/test/build_interface_test.sh"
Task: "Build time optimization integration test in docker/postgresql/test/build_time_test.sh"
Task: "Cache effectiveness validation test in docker/postgresql/test/cache_test.sh"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts
- Container tasks should follow Docker best practices
- Ensure layer caching optimization in build tasks