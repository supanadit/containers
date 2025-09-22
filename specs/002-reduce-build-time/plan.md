# Implementation Plan: Optimize PostgreSQL Build Process

**Branch**: `002-reduce-build-time` | **Date**: September 22, 2025 | **Spec**: /specs/002-reduce-build-time/spec.md
**Input**: Feature specification from /specs/002-reduce-build-time/spec.md

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
Optimize Docker build process for PostgreSQL container to leverage layer caching, separating setup scripts (infrequent changes) from entrypoint scripts (frequent changes) to reduce rebuild time when modifying entrypoint.d files.

## Technical Context
**Language/Version**: Bash 5.1 (scripts), Dockerfile  
**Primary Dependencies**: PostgreSQL 13.5, Patroni v3.0.2, pgBackRest 2.56.0, Citus 11.3.1, pg_stat_monitor 2.2.0, decoderbufs  
**Storage**: PostgreSQL database  
**Testing**: BATS testing framework, shellcheck  
**Target Platform**: Linux x86_64  
**Project Type**: single-container  
**Performance Goals**: Reduce build time by >50% for entrypoint changes, maintain <30s startup time  
**Constraints**: <1GB RAM, <10GB disk, security compliance, non-root execution  
**Scale/Scope**: Single PostgreSQL container with HA capabilities

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Code Quality Standards**: Yes - Plan includes multi-stage Docker builds and security scanning via industry-standard tools.
**Testing Standards**: Yes - Comprehensive tests planned including BATS for functionality, shellcheck for scripts, and performance benchmarks.
**User Experience Consistency**: Yes - Maintains consistent configuration interfaces, logging formats, and health check endpoints.
**Security First**: Yes - Implements non-root execution, secure defaults, and secrets management best practices.
**Performance Optimization**: Yes - Performance goals defined (<30s startup), optimization strategies planned for size and resource usage.
**Build Efficiency**: Yes - Optimizes Docker layer caching by separating setup and entrypoint layers to avoid unnecessary rebuilds.

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 1: Single container (DEFAULT)
docker/
├── Dockerfile
├── entrypoint.sh
├── setup.sh
├── setup/
│   └── scripts/
├── entrypoint.d/
│   └── scripts/
└── config/

# Option 2: Multi-container project (when multiple containers detected)
docker/
├── container1/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── setup.sh
│   ├── setup/
│   │   └── scripts/
│   ├── entrypoint.d/
│   │   └── scripts/
│   └── config/
├── container2/
│   └── [same structure as container1]
└── shared/
    └── scripts/
```

**Structure Decision**: [DEFAULT to Option 1 unless multiple containers detected]

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
   - Tests must fail (no implementation yet)

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

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P] (script interface validation, build interface validation)
- Each entity → model creation task [P] (setup layer implementation, entrypoint layer implementation)
- Each user story → integration test task (build time optimization validation, cache effectiveness testing)
- Implementation tasks to make tests pass (Dockerfile restructuring, script reorganization)

**Ordering Strategy**:
- TDD order: Tests before implementation 
- Dependency order: Setup layer before entrypoint layer, stable files before volatile files
- Mark [P] for parallel execution (independent script validations, contract tests)

**Estimated Output**: 15-20 numbered, ordered tasks in tasks.md

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
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---
*Based on Constitution v1.0.0 - See `/memory/constitution.md`*
