# Container Implementation Plan: [CONTAINER_NAME]

**Branch**: `[###-container-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Container specification from `/specs/[###-container-name]/spec.md`

## Execution Flow (/plan command scope)
```
1. Load container spec from Input path
   → If not found: ERROR "No container spec at {path}"
2. Fill Container Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Container Type from context (service, database, proxy, tool, etc.)
   → Set Base Image Strategy (FROM decision)
   → Determine Multi-stage Build Requirements
3. Fill the Constitution Check section based on the container constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → dockerfile-design.md, configuration.md, quickstart.md, agent-specific template file
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe container build/test task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 8. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
[Extract from container spec: primary service/application + containerization approach from research]

## Container Technical Context
**Container Type**: [e.g., web-service, database, message-queue, proxy, cli-tool or NEEDS CLARIFICATION]
**Base Image Strategy**: [e.g., alpine:3.18, ubuntu:22.04, scratch, distroless or NEEDS CLARIFICATION]
**Application Runtime**: [e.g., Python 3.11, Node.js 18, Go 1.21, Java 17, nginx 1.24 or NEEDS CLARIFICATION]
**Primary Dependencies**: [e.g., PostgreSQL 15, Redis 7, nginx, systemd or NEEDS CLARIFICATION]
**Build Requirements**: [e.g., gcc, make, npm, pip, go mod, maven or NEEDS CLARIFICATION]
**Configuration Method**: [e.g., env vars, config files, secrets, init scripts or NEEDS CLARIFICATION]
**Data Persistence**: [e.g., volumes, bind mounts, tmpfs, none or NEEDS CLARIFICATION]
**Network Requirements**: [e.g., exposed ports, internal only, host network or NEEDS CLARIFICATION]
**Security Profile**: [e.g., non-root user, read-only filesystem, capability drops or NEEDS CLARIFICATION]
**Health Monitoring**: [e.g., health check endpoint, process monitoring, log patterns or NEEDS CLARIFICATION]
**Target Architecture**: [e.g., amd64, arm64, multi-arch or NEEDS CLARIFICATION]
**Image Size Goals**: [e.g., <100MB, <500MB, <1GB or NEEDS CLARIFICATION]
**Startup Performance**: [e.g., <10s cold start, <30s with dependencies or NEEDS CLARIFICATION]
**Resource Constraints**: [e.g., <512MB RAM, <1GB disk, <1 CPU core or NEEDS CLARIFICATION]
**Deployment Scale**: [e.g., single instance, horizontal scaling, HA cluster or NEEDS CLARIFICATION]

## Container Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Multi-stage Build Efficiency**: Does the plan use multi-stage builds to minimize final image size?
**Security Hardening**: Are non-root users, minimal attack surface, and secure defaults implemented?
**Configuration Management**: Is configuration handled via environment variables with sensible defaults?
**Health & Observability**: Are health checks, logging, and monitoring endpoints properly defined?
**Resource Optimization**: Are memory, CPU, and storage requirements clearly defined and optimized?
**Build Reproducibility**: Does the build process use pinned versions and layer caching optimization?
**Container Standards**: Does the design follow OCI standards and best practices for the container type?

## Container Project Structure

### Documentation (this container)
```
specs/[###-container-name]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── dockerfile-design.md # Phase 1 output (/plan command)
├── configuration.md     # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Container Source Structure (repository root)
```
docker/[container-name]/
├── Dockerfile           # Multi-stage container build
├── entrypoint.sh        # Container initialization script
├── setup.sh             # Build-time setup orchestrator
├── README.md            # Container-specific documentation
├── config/              # Default configuration files
│   ├── [app-config]     # Application configuration templates
│   └── [monitoring]     # Health check and monitoring configs
├── setup/               # Build-time setup scripts
│   └── scripts/
│       ├── 01-install-dependencies.sh
│       ├── 02-install-[primary-app].sh
│       ├── 03-configure-[app].sh
│       └── 99-cleanup.sh
├── entrypoint.d/        # Runtime initialization scripts
│   └── scripts/
│       ├── init/        # Pre-startup initialization
│       ├── runtime/     # Runtime management scripts
│       └── utils/       # Helper utilities
└── tests/               # Container testing
    ├── Dockerfile.test  # Test environment
    ├── integration/     # Integration tests
    └── security/        # Security validation tests
```

**Structure Decision**: Single container per directory following established patterns

## Phase 0: Container Research & Analysis
1. **Extract unknowns from Container Technical Context** above:
   - For each NEEDS CLARIFICATION → containerization research task
   - For each base image decision → security and size analysis
   - For each runtime dependency → installation and optimization patterns
   - For each configuration method → best practices research

2. **Generate and dispatch container research agents**:
   ```
   For each unknown in Container Technical Context:
     Task: "Research {unknown} for containerization of {app/service}"
     Focus: Docker best practices, security, performance, size optimization
   For each base image option:
     Task: "Analyze {base-image} for {app-type} containers"
     Focus: Security updates, size, compatibility, ecosystem support
   For each deployment pattern:
     Task: "Research {deployment-pattern} for {container-type}"
     Focus: Orchestration compatibility, scaling, resource management
   ```

3. **Consolidate container findings** in `research.md` using format:
   - **Base Image Decision**: [chosen base image and version]
   - **Build Strategy**: [multi-stage approach and optimization techniques]
   - **Security Approach**: [hardening measures and user configuration]
   - **Configuration Strategy**: [env vars, volumes, secrets management]
   - **Monitoring & Health**: [health check implementation and logging]
   - **Alternatives Considered**: [what else was evaluated and why rejected]

**Output**: research.md with all containerization NEEDS CLARIFICATION resolved

## Phase 1: Container Design & Architecture
*Prerequisites: research.md complete*

1. **Design Dockerfile architecture** → `dockerfile-design.md`:
   - Multi-stage build strategy with stage purposes
   - Base image justification and security considerations
   - Build dependencies vs runtime dependencies
   - Layer optimization and caching strategy
   - User creation and permission model
   - Working directory and file system layout

2. **Design container configuration** → `configuration.md`:
   - Environment variables with defaults and validation
   - Volume mount points and data persistence strategy
   - Port exposure and network requirements
   - Health check implementation (endpoint, command, or script)
   - Logging configuration and output destinations
   - Signal handling and graceful shutdown
   - Resource limits and requirements

3. **Design container lifecycle scripts**:
   - Setup script structure for build-time installation
   - Entrypoint script for runtime initialization
   - Init scripts for service preparation
   - Utility scripts for maintenance and debugging

4. **Generate container test scenarios** from requirements:
   - Build test: Multi-stage build validation
   - Security test: Non-root user, file permissions, CVE scanning
   - Integration test: Service functionality within container
   - Performance test: Startup time, resource usage, throughput
   - Health test: Health check endpoint validation

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh copilot`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW container tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: dockerfile-design.md, configuration.md, quickstart.md, agent-specific file

## Phase 2: Container Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Container Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (dockerfile-design, configuration, quickstart)
- Each Dockerfile stage → build task with optimization [P]
- Each setup script → installation and configuration task
- Each entrypoint script → runtime initialization task
- Each configuration template → environment setup task [P]
- Each test scenario → container validation task [P]

**Container Ordering Strategy**:
- Foundation first: Base image setup before application installation
- Build order: Dependencies → application → configuration → optimization
- Script dependency: Setup scripts before entrypoint scripts
- Testing last: Build tests, then integration tests, then security tests
- Mark [P] for parallel execution (independent file creation)

**Container-Specific Task Categories**:
1. **Build Tasks**: Dockerfile creation, multi-stage optimization
2. **Script Tasks**: Setup scripts, entrypoint scripts, utility scripts
3. **Configuration Tasks**: Config templates, environment setup
4. **Testing Tasks**: Container tests, security validation, performance tests
5. **Documentation Tasks**: README, usage examples, troubleshooting

**Estimated Output**: 15-25 numbered, container-focused tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Container Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Container task execution (/tasks command creates tasks.md)  
**Phase 4**: Container implementation (execute tasks.md following container constitutional principles)  
**Phase 5**: Container validation (build tests, run quickstart.md, security scanning, performance validation)

## Container Complexity Tracking
*Fill ONLY if Container Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., Ubuntu base instead of Alpine] | [specific compatibility requirement] | [why Alpine insufficient for this use case] |
| [e.g., Root user required] | [legacy application constraint] | [why non-root user breaks functionality] |
| [e.g., Multiple processes in container] | [tightly coupled services] | [why separate containers not feasible] |


## Container Progress Tracking
*This checklist is updated during execution flow*

**Container Phase Status**:
- [ ] Phase 0: Container research complete (/plan command)
- [ ] Phase 1: Container design complete (/plan command)
- [ ] Phase 2: Container task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Container tasks generated (/tasks command)
- [ ] Phase 4: Container implementation complete
- [ ] Phase 5: Container validation passed

**Container Gate Status**:
- [ ] Initial Container Constitution Check: PASS
- [ ] Post-Design Container Constitution Check: PASS
- [ ] All containerization NEEDS CLARIFICATION resolved
- [ ] Container complexity deviations documented
- [ ] Multi-stage build validated
- [ ] Security hardening verified
- [ ] Resource optimization confirmed

---
*Based on Container Constitution v1.0.0 - See `/memory/container-constitution.md`*
