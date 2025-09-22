# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
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
- **Single container**: `docker/` with Dockerfile, entrypoint.sh, setup scripts
- **Multi-container**: `docker/container1/`, `docker/container2/`, etc.
- **Shared scripts**: `docker/shared/` for common utilities
- Paths shown below assume single container - adjust based on plan.md structure

## Phase 3.1: Setup
- [ ] T001 Create container directory structure per implementation plan
- [ ] T002 Select and validate base image compatibility
- [ ] T003 [P] Install system dependencies and packages

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T004 [P] Container build test in docker/test/build_test.sh
- [ ] T005 [P] Entrypoint functionality test in docker/test/entrypoint_test.sh
- [ ] T006 [P] Health check validation test in docker/test/health_test.sh
- [ ] T007 [P] Security scan test in docker/test/security_test.sh

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T008 [P] Dockerfile creation in docker/Dockerfile
- [ ] T009 [P] Entrypoint script in docker/entrypoint.sh
- [ ] T010 [P] Setup scripts in docker/setup.sh and docker/setup/scripts/
- [ ] T011 Container configuration files
- [ ] T012 Runtime scripts in docker/entrypoint.d/scripts/
- [ ] T013 Logging and monitoring setup

## Phase 3.4: Integration
- [ ] T014 Multi-stage build optimization
- [ ] T015 Layer caching configuration
- [ ] T016 Security hardening (non-root user, permissions)
- [ ] T017 Health check implementation
- [ ] T018 Environment variable handling

## Phase 3.5: Polish
- [ ] T019 [P] Performance validation (<30s startup, <500MB image)
- [ ] T020 [P] Update container documentation
- [ ] T021 Build context optimization
- [ ] T022 Run integration tests
- [ ] T023 Final security audit

## Dependencies
- Tests (T004-T007) before implementation (T008-T013)
- T008 blocks T014, T015
- T009 blocks T016, T017
- Implementation before polish (T019-T023)

## Parallel Example
```
# Launch T004-T007 together:
Task: "Container build test in docker/test/build_test.sh"
Task: "Entrypoint functionality test in docker/test/entrypoint_test.sh"
Task: "Health check validation test in docker/test/health_test.sh"
Task: "Security scan test in docker/test/security_test.sh"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts
- Container tasks should follow Docker best practices
- Ensure layer caching optimization in build tasks

## Task Generation Rules
*Applied during main() execution*

1. **From Container Specs**:
   - Each container requirement → build/setup task [P]
   - Each service component → configuration task
   
2. **From Build Requirements**:
   - Each dependency → installation task [P]
   - Each optimization → build task
   
3. **From Test Scenarios**:
   - Each functionality test → test script [P]
   - Each integration scenario → validation task

4. **Ordering**:
   - Setup → Tests → Core Implementation → Integration → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All container specs have corresponding tests
- [ ] All build requirements have tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task