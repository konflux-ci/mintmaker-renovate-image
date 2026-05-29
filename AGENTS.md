# AGENTS.md

## Project overview

This repository hosts the custom Renovate container image for MintMaker. It is automatically built and pushed via Konflux CI. The main difference between this image and the upstream Renovate image is the inclusion of the custom `rpm` manager.

**Docs:** root README.md (read before making changes)

*Note: The file `.github/renovate.json` is used to configure dependency updates in this repository. The global base Renovate configuration used by the image is stored in a different repository.*

## Commands

- **Build**: `podman build --ulimit nofile=65535:65535 . -t custom-renovate`
- **Run**: `podman run --rm <additional args> custom-renovate renovate`

*Note: You can replace podman with docker in the commands above depending on the available local container engine.*

## Agent Directives

- **Commits**: Do NOT commit unless asked. Use conventional commits (e.g., `feat:`, `fix:`, `chore:`). Explain what and why was changed in the commit message.
- **Documentation**: Update the corresponding parts of documentation (root README.md) to reflect changes made when applicable.
- **Scope**: Prefer minimal diffs. Typical PRs touch `Dockerfile` only.
- **Secrets**: NEVER commit credentials or tokens.
- **Prohibitions**: Do NOT modify `.github/workflows/`, `.tekton/` or `CODEOWNERS` unless explicitly commanded.
