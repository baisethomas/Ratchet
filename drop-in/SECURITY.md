# Security

## Supported versions

Ratchet is a set of drop-in files and a Claude Code plugin, installed from this repository's `main` branch. Only the current `main` is supported; there are no maintained release lines.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting for this repository: https://github.com/baisethomas/Ratchet/security/advisories/new

Please do not open a public issue for anything that could let a destructive command past the guard, let a hook or script write outside the repository, or expose secrets through project memory. Include the exact command or file that reproduces it; every guard finding to date has been fixed test-first, and a reproduction is what makes that possible.

## What the guard is and is not

`drop-in/hooks/guard-destructive.sh` matches command text; bash decides what runs. It stops destructive commands from running by accident or momentum. It is not a security boundary against a caller who already has the user's permissions and is trying to get around it, and no denylist over shell text can be. For an actual boundary use something the model cannot reach: permission policy, a command allowlist, or a sandbox. The scripts fail closed where they can (no parser, no awk, unbalanced quoting, oversized input) so that a broken environment over-blocks rather than under-blocks.
