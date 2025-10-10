---
id: task-17
title: Patch bank configuration and mapping
status: To Do
assignee: []
created_date: '2025-10-10 10:34'
labels:
  - configuration
  - midi
dependencies:
  - task-14
  - task-15
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Define and configure the three patch banks (boost, dampen, random) with appropriate RC-600 memory numbers. Each bank should contain memories configured with effects/settings suitable for its purpose. Document the mapping and configuration of each memory.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Boost bank configured in config.exs with list of RC-600 memory numbers (e.g., memories 1-10)
- [ ] #2 Dampen bank configured in config.exs with list of RC-600 memory numbers (e.g., memories 11-20)
- [ ] #3 Random bank configured in config.exs with list of RC-600 memory numbers (e.g., memories 21-99)
- [ ] #4 Documentation created at docs/patch_banks.md describing purpose and contents of each bank
- [ ] #5 RC-600 memories configured with appropriate effects for each bank purpose
- [ ] #6 ControlLoop verified to select from correct banks based on control state
- [ ] #7 Patch changes verified to produce expected sonic results
<!-- AC:END -->
