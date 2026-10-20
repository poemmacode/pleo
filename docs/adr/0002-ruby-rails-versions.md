# ADR 0002 — Version pins caused by Ruby 3.3.0

Date: 2026-10-16 · Status: accepted, review pending

## Context

Ruby 3.3.0 (the installed version) has a parser bug with anonymous parameters used inside blocks, fixed in 3.3.1. It affects `connection_pool` 3.x (a Sidekiq dependency) and Rails 8.1's Action View. In addition, `json` 3.x removed options that ActiveSupport 8.0.5 still passes (`quirks_mode`).

Brakeman warns that support for Rails 8.0 ends on **2026-11-07**.

## Decision

- Rails 8.0.5.1, `connection_pool ~> 2.5`, `json ~> 2.10`.
- CI runs Brakeman with `--except EOLRails`; any other warning breaks the build.

## Pending (before 2026-11-07)

1. Install Ruby ≥ 3.3.1 (3.4.x recommended) and update `.tool-versions` and CI.
2. Upgrade to Rails 8.1 (`load_defaults 8.1`) and drop the three pins.
3. Remove `--except EOLRails` from CI.
