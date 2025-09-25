# Feature Specification: Support Native High Availability

**Feature Branch**: `003-support-native-ha`  
**Created**: 2025-09-25
**Status**: Draft  
**Input**: User description: "Support native HA, user can run the container as primary, or replicas, native HA only works when user not using patroni or citus. But it should also support flexibility for user changing HA method whenever they want."

---

## User Scenarios & Testing *(mandatory)*

### Primary User Story
As a database administrator, I want to run the PostgreSQL container in a high-availability (HA) configuration using its native streaming replication, so that I can have a simple and robust primary-replica setup without external dependencies like Patroni. I need the flexibility to designate one container as the primary and others as replicas, and I also want to be able to easily switch between native HA, Patroni-based HA, and a standalone instance as my operational needs change.

### Acceptance Scenarios
1. **Given** a user wants to run a primary instance with native HA, **When** they start a container with `HA_MODE=native` and `REPLICATION_ROLE=primary`, **Then** the container MUST start successfully as a primary PostgreSQL server configured for streaming replication.
2. **Given** a primary instance is running in native HA mode, **When** a user starts a second container with `HA_MODE=native`, `REPLICATION_ROLE=replica`, and configuration pointing to the primary, **Then** the container MUST start as a replica, connect to the primary, and begin replication.
3. **Given** a user has a running native HA cluster, **When** they restart the containers with `USE_PATRONI=true` and remove the native HA variables, **Then** the system MUST reconfigure itself to operate under Patroni's management.
4. **Given** a user has a running native HA cluster, **When** they restart the containers without any HA-related environment variables, **Then** the containers MUST start as independent, standalone PostgreSQL instances.

### Edge Cases
- **Scenario**: A user sets both `USE_PATRONI=true` and `HA_MODE=native`.
  - **Expected Behavior**: The container MUST fail to start and output a clear error message indicating that only one HA method can be active at a time.
- **Scenario**: A user sets both `USE_CITUS=true` and `HA_MODE=native`.
  - **Expected Behavior**: The container MUST fail to start and output a clear error message indicating that native HA is not compatible with Citus.
- **Scenario**: A replica container is started before the primary is ready.
  - **Expected Behavior**: The replica container MUST wait and periodically retry connecting to the primary for a configurable amount of time before timing out.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: The system MUST provide a native high-availability mode using PostgreSQL's built-in streaming replication.
- **FR-002**: The native HA mode MUST be enabled by setting an environment variable `HA_MODE` to `native`.
- **FR-003**: When `HA_MODE` is `native`, the user MUST specify the instance's role by setting a `REPLICATION_ROLE` environment variable to either `primary` or `replica`.
- **FR-004**: The system MUST enforce that native HA and Patroni are mutually exclusive. If `HA_MODE=native` and `USE_PATRONI=true` are both set, the container MUST fail validation and exit with an error.
- **FR-005**: The system MUST enforce that native HA and Citus are mutually exclusive. If `HA_MODE=native` and `USE_CITUS=true` are both set, the container MUST fail validation and exit with an error.
- **FR-006**: The system MUST allow a seamless transition between HA methods (native, Patroni) and a standalone mode, configurable via environment variables upon container restart.
- **FR-007**: Replica instances in native HA mode MUST be configurable to find and connect to the primary instance. [NEEDS CLARIFICATION: How will the replica discover the primary's address? Recommend using a `PRIMARY_HOST` environment variable.]
- **FR-008**: If `HA_MODE` is `native` and `REPLICATION_ROLE` is not set or has an invalid value, the container MUST fail validation and exit with an error.

---

## Review & Acceptance Checklist
*GATE: Automated checks run during main() execution*

### Content Quality
- [ ] No implementation details (languages, frameworks, APIs)
- [ ] Focused on user value and business needs
- [ ] Written for non-technical stakeholders
- [ ] All mandatory sections completed

### Requirement Completeness
- [ ] No [NEEDS CLARIFICATION] markers remain
- [ ] Requirements are testable and unambiguous  
- [ ] Success criteria are measurable
- [ ] Scope is clearly bounded
- [ ] Dependencies and assumptions identified

---

## Execution Status
*Updated by main() during processing*

- [ ] User description parsed
- [ ] Key concepts extracted
- [ ] Ambiguities marked
- [ ] User scenarios defined
- [ ] Requirements generated
- [ ] Entities identified
- [ ] Review checklist passed

---
