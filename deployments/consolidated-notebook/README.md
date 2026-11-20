# Consolidated Notebook Image

This image is a single-Dockerfile flattening of the
`docker-stacks-foundation` -> `base-notebook` -> `minimal-notebook`
inheritance chain **plus** the shared science-platform-images layer that used
to be built separately as `notebook-common` from
`science-platform-images/deployments/common`. Everything those images
contribute (OS packages, the Micromamba/Conda installation,
JupyterLab/Notebook/NBClassic/JupyterHub packages, startup scripts, hooks,
config, healthcheck, STScI shell setup, `common-scripts`, `common-env`, and
`tools`) is built in one image.

Deployments built on top of this image (`FROM consolidated-notebook:latest`)
no longer need the separate `notebook-common` build step in the pipeline.

## Consolidation decisions

- `sudo` is never installed (the common layer removed it as a security risk),
  so the docker-stacks sudoers edits were dropped and `start.sh` guards its
  sudoers manipulation for images without sudo.
- The AWS CLI download (`awscliv2.zip` from `https://awscli.amazonaws.com`)
  was replaced by the conda-forge `awscli` package in `requirements.mamba`:
  fewer external build-time URLs, and the package is covered by the lockable
  conda transaction.
- The dead nb-wrangler installer block (and the `nbw-wrangler-spec.yaml` file
  it required) was dropped; each deployment still carries its own
  `environments/nbw-wrangler-spec.yaml`, which the deployment-layer Dockerfile
  installs the same way as before.
- Apt package lists were deduplicated (single `vim`, `openssh-server`
  replacing the `ssh` metapackage, shared `curl`/`git`/`wget`/`locales`/...).
- All conda packages live in `requirements.mamba` and are installed by the
  single conda transaction in the Dockerfile; all apt packages live in
  `requirements.apt` and are installed by the single apt transaction.

## Building

The directory is self-contained; `make` works from inside it:

```bash
cd deployments/consolidated-notebook
make build
```

Or with plain Docker from this directory:

```bash
DOCKER_BUILDKIT=1 docker build -t consolidated-notebook:latest .
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
