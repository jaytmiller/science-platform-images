# Consolidated Notebook Image

This image is a single-Dockerfile flattening of the
`docker-stacks-foundation` -> `base-notebook` -> `minimal-notebook`
inheritance chain, the shared science-platform-images layer that used to be
built separately as `notebook-common` from `deployments/common`, **and** the
wrangler (generic-base) deployment from `deployments/wrangler`. Everything
those layers contribute (OS packages, the Micromamba/Conda installation,
JupyterLab/Notebook/NBClassic/JupyterHub packages, startup scripts, hooks,
config, healthcheck, STScI shell setup, `common-scripts`, `tools`, the
nb-wrangler tool, and the wrangler notebook content/spec) is built in one
image, from Ubuntu to a runnable JupyterHub single-user deployment, with no
intermediate images.

The wrangler mission environment *is* the base environment (kernel `python3`),
so there is no second conda environment: all mission packages were merged into
the consolidated requirements files.

## Consolidation decisions

- `sudo` is never installed (the common layer removed it as a security risk),
  so the docker-stacks sudoers edits were dropped and `start.sh` guards its
  sudoers manipulation for images without sudo.
- The AWS CLI download (`awscliv2.zip` from `https://awscli.amazonaws.com`)
  was replaced by the conda-forge `awscli` package in `requirements.mamba`:
  fewer external build-time URLs, and the package is covered by the lockable
  conda transaction.
- The dead nb-wrangler installer block in the common layer (and the
  `nbw-wrangler-spec.yaml` file it required) was dropped.
- The wrangler layer's *dynamic* flow (nbw curation at build time:
  `install-common` + `nbw --reinstall` resolving the spec and compiling pinned
  requirements inside the image) was replaced by *static*, checked-in package
  lists: everything those steps installed now lives in `requirements.mamba`
  (base + mission conda packages) and `requirements.pip` (common-env pip lists
  + the spec's `common_pip_packages`, including nb-wrangler itself via a pinned
  git URL). `/opt/common-env` no longer exists; `environments/nbw-exports.sh`
  is the static equivalent of the old `nbw --data-print` output.
- At runtime `nbw` still works unchanged: `global_bashrc`, `post-start-hook`,
  and `test` use the installed `nbw` command and `/opt/environments/nbw-wrangler-spec.yaml`.
- Apt package lists were deduplicated (single `vim`, `openssh-server`
  replacing the `ssh` metapackage, shared `curl`/`git`/`wget`/`locales`/... ,
  and the wrangler GL/mesa packages for jdaviz).

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
  single `micromamba install` transaction, all apt packages listed in
  `requirements.apt` in one `apt-get` transaction, and all Python packages in
  one `pip install -r requirements.pip` transaction, so lockfiles generated
  from those package lists fully pin the Python side.
- The locked variant would replace the installs with an offline install
  (`--offline` / `--use-only-tarball`) against a checked-in lockfile and a
  directory of downloaded, hash-pinned `.conda` packages (and pinned/`--no-deps
  wheelhouse installs for the pip list); `env-frozen/` holds the historical
  pinned exports for reference.
