# Container Specification: [CONTAINER_NAME]

**Container Branch**: `[###-container-name]`  
**Created**: [DATE]  
**Status**: Draft  
**Input**: Container description: "$ARGUMENTS"

## Container Execution Flow (main)
```
1. Parse container description from Input
   → If empty: ERROR "No container description provided"
2. Extract key container concepts from description
   → Identify: application/service, runtime requirements, data persistence, network needs
3. For each unclear containerization aspect:
   → Mark with [NEEDS CLARIFICATION: specific container question]
4. Fill Container Usage & Deployment section
   → If no clear deployment scenario: ERROR "Cannot determine container usage"
5. Generate Container Requirements
   → Each requirement must be testable and container-specific
   → Mark ambiguous containerization requirements
6. Identify Container Resources (if applicable)
7. Run Container Review Checklist
   → If any [NEEDS CLARIFICATION]: WARN "Container spec has uncertainties"
   → If implementation details found: ERROR "Remove tech implementation details"
8. Return: SUCCESS (container spec ready for planning)
```

---

## ⚡ Container Guidelines
- ✅ Focus on WHAT the container should provide and WHY it's needed
- ❌ Avoid HOW to implement (no Dockerfile details, specific base images, build commands)
- � Written for DevOps/platform stakeholders, not container implementation details

### Container Section Requirements
- **Mandatory sections**: Must be completed for every container
- **Optional sections**: Include only when relevant to the container type
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For Container AI Generation
When creating this container spec from a user prompt:
1. **Mark all containerization ambiguities**: Use [NEEDS CLARIFICATION: specific container question] for any assumption you'd need to make
2. **Don't guess container details**: If the prompt doesn't specify something (e.g., "database container" without persistence requirements), mark it
3. **Think like a container tester**: Every vague requirement should fail the "testable and unambiguous" checklist item
4. **Common underspecified container areas**:
   - Resource requirements (CPU, memory, storage)
   - Data persistence and volume requirements
   - Network exposure and port requirements
   - Security and access control needs
   - Performance targets (startup time, throughput, latency)
   - Integration with other containers/services
   - Configuration and environment variable needs
   - Health check and monitoring requirements
   - Scaling and orchestration needs

---

## Container Usage & Deployment *(mandatory)*

### Primary Container Purpose
[Describe what service/application this container provides and why it's needed]

### Deployment Scenarios
1. **Given** [infrastructure state], **When** [container deployed], **Then** [expected service availability]
2. **Given** [runtime conditions], **When** [container receives requests], **Then** [expected behavior]
3. **Given** [scaling needs], **When** [multiple instances deployed], **Then** [expected load distribution]

### Container Edge Cases
- What happens when [resource limits exceeded]?
- How does container handle [dependency unavailability]?
- What occurs during [graceful shutdown scenarios]?
- How does container behave during [network partitions]?

## Container Requirements *(mandatory)*

### Functional Requirements
- **CR-001**: Container MUST [specific service capability, e.g., "serve HTTP requests on port 80"]
- **CR-002**: Container MUST [startup behavior, e.g., "initialize within 30 seconds"]  
- **CR-003**: Container MUST [data handling, e.g., "persist configuration changes"]
- **CR-004**: Container MUST [integration capability, e.g., "connect to external database"]
- **CR-005**: Container MUST [monitoring behavior, e.g., "expose health check endpoint"]

### Performance Requirements
- **PR-001**: Container MUST [startup performance, e.g., "start within 10 seconds"]
- **PR-002**: Container MUST [resource usage, e.g., "use less than 512MB RAM"]
- **PR-003**: Container MUST [throughput, e.g., "handle 100 concurrent connections"]
- **PR-004**: Container MUST [image size, e.g., "final image under 200MB"]

### Security Requirements
- **SR-001**: Container MUST [user security, e.g., "run as non-root user"]
- **SR-002**: Container MUST [access control, e.g., "restrict file system access"]
- **SR-003**: Container MUST [network security, e.g., "only expose necessary ports"]

*Example of marking unclear container requirements:*
- **CR-006**: Container MUST persist data via [NEEDS CLARIFICATION: volume type not specified - named volume, bind mount, or tmpfs?]
- **CR-007**: Container MUST scale to [NEEDS CLARIFICATION: scaling target not specified - how many instances?]

### Container Resources *(include if container manages data or configurations)*
- **[Configuration Files]**: [What config files are managed, their purpose without implementation details]
- **[Data Volumes]**: [What data is persisted, relationships to other containers]
- **[Network Interfaces]**: [What network exposure is required, integration points]

---

## Container Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Container Content Quality
- [ ] No container implementation details (Dockerfile instructions, specific base images, build commands)
- [ ] Focused on container service value and operational needs
- [ ] Written for DevOps/platform stakeholders
- [ ] All mandatory container sections completed

### Container Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Container requirements are testable and unambiguous  
- [ ] Performance criteria are measurable (startup time, resource usage, throughput)
- [ ] Container scope is clearly bounded (what it does and doesn't provide)
- [ ] Container dependencies and integration points identified
- [ ] Resource requirements specified (CPU, memory, storage, network)
- [ ] Security requirements defined (user, permissions, network exposure)
- [ ] Data persistence requirements clarified (volumes, configuration)
- [ ] Health check and monitoring requirements specified

---

## Container Execution Status
*Updated by main() during processing*

- [ ] Container description parsed
- [ ] Key container concepts extracted
- [ ] Container ambiguities marked
- [ ] Container usage scenarios defined
- [ ] Container requirements generated
- [ ] Container resources identified
- [ ] Container review checklist passed

---
