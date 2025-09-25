# Implementation Plan: Support Native High Availability

**Branch**: `003-support-native-ha` | **Date**: 2025-09-25 | **Spec**: [specs/003-support-native-ha/spec.md](specs/003-support-native-ha/spec.md)
**Input**: Feature specification from `/home/supanadit/Workspaces/Personal/Docker/containers/specs/003-support-native-ha/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (single=one container, multi=multiple containers)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
This plan outlines the implementation of a native high-availability (HA) mode for the PostgreSQL container using its built-in streaming replication. The feature will be enabled via the `HA_MODE=native` environment variable, with roles defined as `primary` or `replica`. The implementation will focus on modifying existing entrypoint scripts to handle configuration, validation, and initialization for both roles, ensuring a seamless and robust user experience that is mutually exclusive with Patroni and Citus.

## Technical Context
**Language/Version**: Bash 5.1
**Primary Dependencies**: PostgreSQL 13.5
**Storage**: PostgreSQL
**Testing**: BATS, shellcheck
**Target Platform**: Linux x86_64, ARM64, multi-arch
**Project Type**: single-container
**Performance Goals**: Startup time should not be significantly impacted. Replica setup via `pg_basebackup` depends on database size and network speed.
**Constraints**: This feature is incompatible with `USE_PATRONI=true` and `USE_CITUS=true`. Automatic replica promotion is out of scope.
**Scale/Scope**: Supports a single primary and multiple replicas.

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Code Quality Standards**: The plan adheres to existing standards. No new images are created.
**Testing Standards**: New BATS tests will be required to validate the primary and replica roles and the failure conditions.
**User Experience Consistency**: The use of environment variables is consistent with the existing configuration model. Error messages will be clear and explicit.
**Security First**: A dedicated replication user is used. The `REPLICATION_PASSWORD` will be handled as a secret.
**Performance Optimization**: The impact on performance is expected to be minimal for the primary. Replica startup is dominated by `pg_basebackup`.
**Build Efficiency**: No changes to the Dockerfile are planned, so build efficiency is not affected.

## Project Structure

### Documentation (this feature)
```
specs/003-support-native-ha/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
│   ├── configuration.md
│   └── script-interfaces.md
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 1: Single container (DEFAULT)
docker/
└── postgresql/
    ├── entrypoint.d/
    │   └── scripts/
    │       ├── init/
    │       │   ├── 02-database.sh
    │       │   ├── 03-config.sh
    │       │   └── 04-replication.sh (new)
    │       └── utils/
    │           └── validation.sh
    └── test/
        └── integration/
            └── test_native_ha.bats (new)
```

**Structure Decision**: Option 1: Single container. The changes will be applied to the existing `postgresql` container.

## Progress Tracking
- [X] Initial Constitution Check
- [X] Phase 0: Research
- [X] Phase 1: Design Artifacts
- [ ] Phase 2: Task Generation (Ready for /tasks)

## Phase 2: Task Generation Approach
The next step is to generate a detailed task list using the `/tasks` command. The tasks will be derived from the `data-model.md` and `contracts/` documents. The main work items will be:
1.  Implement the `validate_ha_configuration` function in `validation.sh`.
2.  Modify `setup_database` in `02-database.sh` to include the `pg_basebackup` logic for replicas.
3.  Modify `configure_postgresql` in `03-config.sh` to configure the primary for replication.
4.  Create the new `04-replication.sh` script to handle the replication user creation.
5.  Create a new BATS test file (`test_native_ha.bats`) to provide integration testing for the new functionality.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each entity → model creation task [P] 
- Each contract → implementation task
- Each contract → contract test task [P]
- Each user story → integration test task

**Ordering Strategy**:
- Implementation first: Implementation tasks before test tasks
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [ ] Phase 0: Research complete (/plan command)
- [ ] Phase 1: Design complete (/plan command)
- [ ] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [ ] Initial Constitution Check: PASS
- [ ] Post-Design Constitution Check: PASS
- [ ] All NEEDS CLARIFICATION resolved
- [ ] Complexity deviations documented

---
*Based on Constitution v1.0.0 - See `/memory/constitution.md`*
