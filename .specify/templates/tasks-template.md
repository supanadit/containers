# Container Tasks: [CONTAINER_NAME]

**Input**: Container design documents from `/specs/[###-container-name]/`
**Prerequisites**: plan.md (required), research.md, dockerfile-design.md, configuration.md

## Container Execution Flow (main)
```
1. Load plan.md from container directory
   → If not found: ERROR "No container implementation plan found"
   → Extract: container type, base image, runtime, structure
2. Load container design documents:
   → dockerfile-design.md: Extract build stages → Dockerfile tasks
   → configuration.md: Extract config templates → configuration tasks
   → research.md: Extract base image decisions → setup tasks
3. Generate container tasks by category:
   → Foundation: directory structure, base image setup, user creation
   → Build: multi-stage Dockerfile, dependency installation, optimization
   → Runtime: entrypoint scripts, configuration templates, health checks
   → Testing: build validation, security scanning, functionality tests
   → Integration: layer caching, volume mounting, network configuration
   → Validation: performance testing, documentation, cleanup
4. Apply container task rules:
   → Different files = mark [P] for parallel
   → Same Dockerfile stage = sequential (no [P])
   → Build stages before runtime scripts
   → Implementation before testing
5. Number tasks sequentially (C001, C002...)
6. Generate container dependency graph
7. Create parallel build examples
8. Validate container task completeness:
   → All Dockerfile stages have build tasks?
   → All runtime requirements have scripts?
   → All container functionality tested?
   → All security requirements addressed?
9. Return: SUCCESS (container tasks ready for execution)
```

## Format: `[C-ID] [P?] Container Task Description`
- **[P]**: Can run in parallel (different files, no container dependencies)
- Include exact container file paths in descriptions
- Use C### numbering for container tasks (C001, C002, etc.)

## Container Path Conventions
- **Single container**: `docker/[container-name]/`
- **Multi-container**: `docker/container1/`, `docker/container2/`, etc.
- **Shared utilities**: `docker/shared/scripts/` for common container utilities
- **Container structure**: Following established patterns from existing containers
- Paths shown below assume single container - adjust based on plan.md container structure

## Phase 3.1: Container Foundation
- [ ] C001 Create container directory structure per container implementation plan
- [ ] C002 Create non-root user and group configuration
- [ ] C003 [P] Setup base image validation and security scanning

## Phase 3.2: Multi-stage Dockerfile Build
- [ ] C004 Create Dockerfile with multi-stage build structure
- [ ] C005 Implement build stage with dependency installation
- [ ] C006 Implement runtime stage with minimal footprint
- [ ] C007 Configure layer caching optimization
- [ ] C008 Add security hardening (non-root, minimal packages)

## Phase 3.3: Container Scripts
- [ ] C009 [P] Create setup.sh orchestrator script in docker/[container]/setup.sh
- [ ] C010 [P] Create build-time setup scripts in docker/[container]/setup/scripts/
- [ ] C011 [P] Create entrypoint.sh runtime initialization in docker/[container]/entrypoint.sh
- [ ] C012 [P] Create runtime scripts in docker/[container]/entrypoint.d/scripts/
- [ ] C013 [P] Create utility scripts for maintenance and debugging

## Phase 3.4: Container Configuration
- [ ] C014 [P] Create configuration templates in docker/[container]/config/
- [ ] C015 [P] Implement environment variable handling with defaults
- [ ] C016 [P] Configure volume mount points and data persistence
- [ ] C017 [P] Setup logging configuration and output destinations
- [ ] C018 Implement health check endpoint/command

## Phase 3.5: Container Testing
- [ ] C019 [P] Create container build test in docker/[container]/tests/build_test.sh
- [ ] C020 [P] Create security validation test in docker/[container]/tests/security_test.sh
- [ ] C021 [P] Create functionality test in docker/[container]/tests/integration_test.sh
- [ ] C022 [P] Create performance test in docker/[container]/tests/performance_test.sh
- [ ] C023 [P] Create health check validation test

## Phase 3.6: Container Integration & Validation
- [ ] C024 Optimize build context and .dockerignore
- [ ] C025 Validate multi-architecture build support
- [ ] C026 Configure signal handling and graceful shutdown
- [ ] C027 Run complete container integration tests
- [ ] C028 [P] Create container documentation in docker/[container]/README.md
- [ ] C029 Final container security audit and CVE scanning
- [ ] C030 Performance validation (startup time, memory usage, image size)

## Container Dependencies
- Foundation (C001-C003) before all other phases
- Dockerfile (C004-C008) before scripts (C009-C013)
- Scripts (C009-C013) before configuration (C014-C018)
- Configuration (C014-C018) before testing (C019-C023)
- Core implementation (C001-C018) before integration (C024-C030)
- C004 (Dockerfile) blocks C007 (layer caching), C008 (security hardening)
- C011 (entrypoint.sh) blocks C018 (health check), C026 (signal handling)
- All implementation before validation (C027-C030)

## Container Parallel Execution Example
```
# Launch C009-C013 together (different script files):
Task: "Create setup.sh orchestrator script in docker/[container]/setup.sh"
Task: "Create build-time setup scripts in docker/[container]/setup/scripts/"
Task: "Create entrypoint.sh runtime initialization in docker/[container]/entrypoint.sh"
Task: "Create runtime scripts in docker/[container]/entrypoint.d/scripts/"
Task: "Create utility scripts for maintenance and debugging"

# Launch C014-C017 together (different config files):
Task: "Create configuration templates in docker/[container]/config/"
Task: "Implement environment variable handling with defaults"
Task: "Configure volume mount points and data persistence"
Task: "Setup logging configuration and output destinations"

# Launch C019-C023 together (independent test files):
Task: "Create container build test in docker/[container]/tests/build_test.sh"
Task: "Create security validation test in docker/[container]/tests/security_test.sh"
Task: "Create functionality test in docker/[container]/tests/integration_test.sh"
Task: "Create performance test in docker/[container]/tests/performance_test.sh"
Task: "Create health check validation test"
```

## Container Task Notes
- [P] tasks = different container files, no build dependencies
- Commit after each container task completion
- Follow established container patterns from existing containers in repository
- Avoid: vague container tasks, Dockerfile stage conflicts, same script file modifications
- Container tasks must follow Docker and OCI best practices
- Ensure multi-stage build optimization and layer caching in all build tasks
- Non-root user required unless specifically justified in complexity tracking
- All containers must have health checks and proper signal handling
- Security scanning and CVE validation required for all containers

## Container Task Generation Rules
*Applied during main() execution*

1. **From Container Dockerfile Design**:
   - Each build stage → Dockerfile build task
   - Each dependency layer → installation task [P]
   - Each optimization → build optimization task
   
2. **From Container Configuration**:
   - Each config template → configuration file task [P]
   - Each environment variable → env handling task
   - Each volume mount → persistence task [P]
   
3. **From Container Runtime Requirements**:
   - Each initialization step → entrypoint script task [P]
   - Each runtime service → runtime script task [P]
   - Each maintenance operation → utility script task [P]

4. **From Container Test Scenarios**:
   - Each build validation → build test script [P]
   - Each security requirement → security test script [P]
   - Each functionality → integration test script [P]
   - Each performance goal → performance test script [P]

5. **Container Ordering Rules**:
   - Foundation → Dockerfile → Scripts → Configuration → Testing → Integration → Validation
   - Multi-stage dependencies block parallel execution within Dockerfile
   - Script dependencies block parallel execution within same script category

## Container Validation Checklist
*GATE: Checked by main() before returning*

- [ ] All container specifications have corresponding build tasks
- [ ] All Dockerfile stages have implementation tasks
- [ ] All runtime requirements have script tasks
- [ ] All configuration needs have template tasks
- [ ] All container functionality has test tasks
- [ ] All security requirements have validation tasks
- [ ] All performance goals have measurement tasks
- [ ] Multi-stage build dependencies correctly sequenced  
- [ ] Container implementation comes before container testing
- [ ] Parallel container tasks truly independent (different files)
- [ ] Each container task specifies exact file path within container structure
- [ ] No container task modifies same file as another [P] task
- [ ] Non-root user configuration included unless justified
- [ ] Health check implementation included
- [ ] Security scanning tasks included
- [ ] Layer caching optimization tasks included