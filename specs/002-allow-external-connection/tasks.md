# Container Tasks: PostgreSQL

**Input**: Container design documents from `/specs/002-allow-external-connection/`
**Prerequisites**: plan.md (required), research.md, dockerfile-design.md, configuration.md, quickstart.md

## Container Execution Flow (main)
```
1. Load plan.md from container directory
   → Extract: PostgreSQL container with external access feature
2. Load container design documents:
   → dockerfile-design.md: No changes needed
   → configuration.md: Extract env vars → config tasks
   → research.md: External access decisions → implementation tasks
   → quickstart.md: Usage scenarios → test tasks
3. Generate container tasks by category:
   → Testing: Unit tests for env var handling, integration for connections
   → Implementation: Modify init scripts for pg_hba.conf updates
   → Documentation: Update config and README with new env vars
4. Apply container task rules:
   → Different test files = mark [P] for parallel
   → Same init script = sequential (no [P])
   → Tests before implementation (TDD approach)
5. Number tasks sequentially (T001, T002...)
6. Generate container dependency graph
7. Create parallel build examples
8. Validate container task completeness:
   → All env vars have parsing logic?
   → pg_hba.conf updated correctly?
   → External connections testable?
   → Documentation updated?
9. Return: SUCCESS (container tasks ready for execution)
```

## Format: `[T-ID] [P?] Container Task Description`
- **[P]**: Can run in parallel (different files, no container dependencies)
- Include exact container file paths in descriptions
- Use T### numbering for container tasks (T001, T002, etc.)

## Container Path Conventions
- **Container**: `docker/postgresql/`
- **Scripts**: `docker/postgresql/entrypoint.d/scripts/`
- **Tests**: `docker/postgresql/tests/`
- **Config**: `docker/postgresql/config/`
- **Docs**: `docker/postgresql/README.md`

## Phase 3.1: Container Testing (TDD First)
- [X] T001 [P] Create unit test for EXTERNAL_ACCESS_ENABLE=true default behavior in docker/postgresql/tests/unit_test.sh
- [X] T002 [P] Create unit test for EXTERNAL_ACCESS_ENABLE=false in docker/postgresql/tests/unit_test.sh
- [X] T003 [P] Create unit test for invalid EXTERNAL_ACCESS_METHOD fallback in docker/postgresql/tests/unit_test.sh

## Phase 3.2: Container Implementation
- [X] T004 Modify docker/postgresql/entrypoint.d/scripts/init/03-config.sh to parse EXTERNAL_ACCESS_ENABLE and EXTERNAL_ACCESS_METHOD env vars
- [X] T005 Modify docker/postgresql/entrypoint.d/scripts/init/03-config.sh to update pg_hba.conf with external access rules based on env vars

## Phase 3.3: Container Documentation
- [X] T006 [P] Update docker/postgresql/config/configuration.md with EXTERNAL_ACCESS_ENABLE and EXTERNAL_ACCESS_METHOD env vars
- [X] T007 [P] Update docker/postgresql/README.md with external access configuration section

## Phase 3.4: Container Integration & Validation
- [X] T008 Create integration test for external connections in docker/postgresql/tests/integration_test.sh
- [X] T009 Run complete container integration tests for external access scenarios

## Container Dependencies
- Testing (T001-T003) before implementation (T004-T005) [TDD]
- Implementation (T004-T005) before documentation (T006-T007)
- Documentation (T006-T007) before integration (T008-T009)
- T004 blocks T005 (same config script file)
- T006 and T007 can be parallel (different files)
- T001-T003 can be parallel (same test file, but different test functions)

## Container Parallel Execution Example
```
# Launch T001-T003 together (unit tests in same file):
Task: "Create unit test for EXTERNAL_ACCESS_ENABLE=true default behavior in docker/postgresql/tests/unit_test.sh"
Task: "Create unit test for EXTERNAL_ACCESS_ENABLE=false in docker/postgresql/tests/unit_test.sh"
Task: "Create unit test for invalid EXTERNAL_ACCESS_METHOD fallback in docker/postgresql/tests/unit_test.sh"

# Launch T006-T007 together (different doc files):
Task: "Update docker/postgresql/config/configuration.md with EXTERNAL_ACCESS_ENABLE and EXTERNAL_ACCESS_METHOD env vars"
Task: "Update docker/postgresql/README.md with external access configuration section"
```

## Container Task Notes
- [P] tasks = different container files, no build dependencies
- Commit after each container task completion
- Follow established container patterns from existing PostgreSQL container
- Avoid: vague container tasks, script conflicts, same file modifications
- Container tasks must follow Docker and OCI best practices
- Ensure env var parsing is secure and validated
- pg_hba.conf modifications must be secure and follow PostgreSQL best practices
- All changes must maintain backward compatibility
- Security scanning required for modified scripts

## Container Task Generation Rules
*Applied during main() execution*

1. **From Container Configuration**:
   - Each new env var → parsing logic task
   - Each config file update → modification task
   
2. **From Container Runtime Requirements**:
   - Each env var handling → init script task
   - Each pg_hba.conf rule → config update task

3. **From Container Test Scenarios**:
   - Each env var scenario → unit test task [P]
   - Each connection scenario → integration test task
   - Each error case → validation test task

4. **Container Ordering Rules**:
   - Testing → Implementation → Documentation → Integration
   - Same file modifications sequential
   - Different files can be parallel

## Container Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All env vars have parsing and validation logic
- [ ] pg_hba.conf updated securely for external access
- [ ] External connections work when enabled
- [ ] Access denied when disabled
- [ ] Invalid methods fall back gracefully
- [ ] Documentation updated with new env vars
- [ ] Tests cover all scenarios from quickstart
- [ ] No security vulnerabilities introduced
- [ ] Backward compatibility maintained
- [ ] Constitution principles followed