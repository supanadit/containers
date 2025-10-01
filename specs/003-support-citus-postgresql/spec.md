# Container Specification: PostgreSQL

**Container Branch**: `003-support-citus-postgresql`  
**Created**: October 1, 2025  
**Status**: Draft  
**Input**: Container description: "Support Citus PostgreSQL, user should able to use Citus as Standalone or running citus alongside with Patroni"

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
The PostgreSQL container must support the Citus extension to enable distributed database capabilities, allowing users to deploy Citus either as a standalone single-node instance for development and testing or integrated with Patroni for production high-availability multi-node clusters.

### Deployment Scenarios
1. **Given** standalone deployment without Patroni, **When** CITUS_ENABLE=true environment variable is set, **Then** container initializes Citus as a single-node distributed database ready for horizontal scaling.
2. **Given** deployment with Patroni cluster, **When** CITUS_ENABLE=true and PATRONI_ENABLE=true are set, **Then** container participates in Citus distributed cluster with automatic failover and leader election.
3. **Given** multi-node Citus cluster setup, **When** containers are deployed with coordinator and worker roles, **Then** Citus distributes data across worker nodes while maintaining transactional consistency.

### Container Edge Cases
- What happens when Citus is enabled but Patroni is not properly configured?
- How does container handle Citus worker node failures in a distributed setup?
- What occurs during graceful shutdown of Citus coordinator node?
- How does container behave when Citus extension conflicts with existing PostgreSQL configurations?
- What happens during network partitions in Citus distributed clusters?

## Container Requirements *(mandatory)*

### Functional Requirements
- **CR-001**: Container MUST enable Citus extension when CITUS_ENABLE=true environment variable is set
- **CR-002**: Container MUST support standalone Citus mode without Patroni dependency
- **CR-003**: Container MUST integrate Citus with Patroni for high-availability distributed clusters
- **CR-004**: Container MUST allow configuration of Citus coordinator and worker roles
- **CR-005**: Container MUST expose PostgreSQL port 5432 for Citus distributed communication (no additional ports required)
- **CR-006**: Container MUST initialize Citus metadata tables on first startup
- **CR-007**: Container MUST support Citus distributed table creation and management

### Performance Requirements
- **PR-001**: Container MUST start Citus-enabled instance within 60 seconds
- **PR-002**: Container MUST maintain PostgreSQL performance baseline when Citus is enabled
- **PR-003**: Container MUST handle Citus distributed queries with acceptable latency
- **PR-004**: Container MUST support Citus horizontal scaling up to Citus-documented limits

### Security Requirements
- **SR-001**: Container MUST secure Citus inter-node communication
- **SR-002**: Container MUST maintain existing PostgreSQL security when Citus is enabled
- **SR-003**: Container MUST restrict Citus administrative access to authorized users

*Example of marking unclear container requirements:*
- **CR-006**: Container MUST persist data via [NEEDS CLARIFICATION: volume type not specified - named volume, bind mount, or tmpfs?]
- **CR-007**: Container MUST scale to [NEEDS CLARIFICATION: scaling target not specified - how many instances?]

### Container Resources *(include if container manages data or configurations)*
- **[Configuration Files]**: Citus configuration parameters, distributed database metadata
- **[Data Volumes]**: Citus distributed tables data, shared across coordinator and worker nodes

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

## Clarifications

### Session 2025-10-01
- Q: What is the maximum number of Citus worker nodes the container should support for horizontal scaling? → A: The maximum number are based on Citus itself
- Q: What additional ports, if any, does Citus require for inter-node communication beyond the standard PostgreSQL port? → A: No
