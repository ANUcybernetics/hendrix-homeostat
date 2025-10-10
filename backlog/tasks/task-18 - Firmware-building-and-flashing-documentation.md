---
id: task-18
title: Firmware building and flashing documentation
status: To Do
assignee: []
created_date: '2025-10-10 10:34'
labels:
  - documentation
  - nerves
  - deployment
dependencies:
  - task-1
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document the complete procedure for building firmware and flashing to SD card for deployment. Include both macOS and Linux (Ubuntu) workflows, troubleshooting common issues, and verification steps after flashing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Documentation created at docs/deployment.md
- [ ] #2 Documents firmware build process on macOS (if supported) and Ubuntu
- [ ] #3 Includes commands for mix deps.get, mix firmware, mix burn
- [ ] #4 Documents MIX_TARGET=rpi5 environment variable requirement
- [ ] #5 Includes troubleshooting section for common build errors
- [ ] #6 Documents SD card preparation and burning procedure
- [ ] #7 Includes first-boot verification steps (SSH access, IEx.pry, module checks)
- [ ] #8 Documents how to update running firmware without full rebuild
<!-- AC:END -->
