# Consolidated Jupyter Stack

This image is a single-Dockerfile flattening of the
`docker-stacks-foundation` -> `base-notebook` -> `minimal-notebook`
inheritance chain. Everything the three images contribute (OS packages, the
Micromamba/Conda installation, JupyterLab/Notebook/NBClassic/JupyterHub
packages, startup scripts, hooks, config, and healthcheck) is installed in one
build instead of three stacked layers of inherited images.

## Building

The directory is self-contained; `make` works from inside it:

```bash
cd images/consolidated-notebook
make build
```

Or with plain Docker from the repo root:

```bash
DOCKER_BUILDKIT=1 docker build -t consolidated-notebook:latest images/consolidated-notebook
```

## Lock-readiness (future work)

The current Dockerfile is the *unlocked* source: conda packages are solved
from live channels at build time. The structure is arranged so a locked,
reproducible variant is a small, well-scoped change:

- Both external inputs are digest-pinned build stages: the Ubuntu root image
  and the `mambaorg/micromamba` image (which supplies the pinned solver
  binary via a bind mount).
- All conda packages are listed in `requirements.mamba` and installed in a
  single `micromamba install` transaction, and all apt packages listed in
  `requirements.apt` in one `apt-get` transaction, so lockfiles generated from
  those package lists fully pin the Python side.
- The locked variant would replace the installs with an offline install
  (`--offline` / `--use-only-tarball`) against a checked-in lockfile and a
  directory of downloaded, hash-pinned `.conda` packages.
