---
created: 2026-02-26T23:46:10.402Z
title: Clean up compiler and build warnings
area: general
files: []
---

## Problem

The project has accumulated compiler and build warnings that should be audited and resolved. This includes Elixir/mix compile warnings, JavaScript/esbuild warnings, and any runtime warnings visible in the server console.

Warnings create noise that masks real issues and make it harder to spot new problems as they appear.

## Solution

1. Run `mix compile --warnings-as-errors` to identify Elixir warnings
2. Check JS build output for asset pipeline warnings
3. Review server console output during runtime for deprecation or runtime warnings
4. Fix or suppress each warning as appropriate
