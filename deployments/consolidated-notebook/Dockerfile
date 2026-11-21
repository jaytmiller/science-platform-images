# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Consolidated image: a single Dockerfile that flattens the
#   docker-stacks-foundation -> base-notebook -> minimal-notebook
# inheritance chain, the science-platform-images shared layer
# (deployments/common), AND the wrangler (generic-base) deployment
# (deployments/wrangler) into one build.
#
# All layers, packages, scripts, and configs from the source images are
# preserved in build order. The two pinned build stages (root OS and Micromamba)
# carry the digest pinning forward from docker-stacks-foundation.
#
# External dependencies and dynamic mechanisms were minimized during
# consolidation:
#   * sudo is never installed (the common layer removed it as a security risk),
#     so the sudoers edits from the foundation layer were dropped.
#   * The AWS CLI zip download from https://awscli.amazonaws.com was replaced
#     by the conda-forge `awscli` package in requirements.mamba.
#   * The dead nb-wrangler install block and its /tmp/nbw-wrangler-spec.yaml
#     copy were dropped from the common layer.
#   * The wrangler deployment's dynamic curation flow (install-common reading
#     common-env/*.conda|.pip plus `nbw --reinstall` resolving the spec at
#     build time) was flattened into the static, checked-in
#     `requirements.mamba`/`requirements.pip` package lists; /opt/common-env no
#     longer exists. nb-wrangler itself is installed from the pinned git URL
#     listed in requirements.pip so the runtime `nbw` command (used by
#     global_bashrc, post-start-hook, and the test scripts) works unchanged.
#
# Lock-readiness notes (for a future "locked" variant of this image):
#   * Both root inputs are digest-pinned (Ubuntu and the Micromamba image), so
#     the solver and the base OS are byte-reproducible.
#   * Every conda package is listed in `requirements.mamba` and installed in a
#     single `micromamba install` transaction targeting ${CONDA_DIR}. To
#     produce a locked variant, generate a lockfile (e.g. conda-lock) from that
#     package list and swap the install for an offline install against a
#     directory of pre-downloaded, hash-pinned packages; nothing else about the
#     layer order needs to change.
#   * All apt packages (docker-stacks + common) are collapsed into a single apt
#     RUN driven by `requirements.apt`, so the unlocked source is one apt
#     transaction and one conda transaction.

# This build arg allows building the image based on a different root image
ARG ROOT_IMAGE=default_root_image

# Ubuntu 26.04 (resolute)
# https://hub.docker.com/_/ubuntu/tags?page=1&name=resolute
# Referenced as a build stage, so dependabot is able to keep the version and digest up to date
FROM ubuntu:26.04@sha256:065aa8626841f16057b78b027b464cd59c4fac36c204c72dcbf48d66f5fa8a96 AS default_root_image

# Micromamba is taken from the official image, pinned by digest for integrity
# Dependabot keeps this version and digest up to date (`docker` ecosystem covers this directory)
# The binary is bind-mounted into the install RUN below, so it is not added to any image layer
FROM mambaorg/micromamba:2.10.0@sha256:e1476182cd40eb1f7c0cfae4adec9bfd78f3d7f05c61368306abfdc8939c1198 AS micromamba

FROM $ROOT_IMAGE

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"
LABEL maintainer="Science Platforms <dmd_octarine@stsci.edu>"
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Install all OS dependencies in a single transaction using the package list
# in `requirements.apt` (the deduplicated union of the docker-stacks image
# package sets and the common layer tool chains; package metadata comments
# live in that file)
ENV DEBIAN_FRONTEND=noninteractive
COPY requirements.apt /tmp/requirements.apt
RUN apt-get update --yes && \
    # - `apt-get upgrade` is run to patch known vulnerabilities in system packages
    #   as the Ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    # Strip comments from `requirements.apt` and install the package list in
    # one transaction; `xargs` splits the remaining whitespace-separated names
    sed 's/#.*//' /tmp/requirements.apt | xargs --no-run-if-empty \
        apt-get install --yes --no-install-recommends && \
    rm -f /tmp/requirements.apt && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # - The Ubuntu 26.04 image ships Canonical's Pebble service manager as a bare
    #   /usr/bin/pebble, owned by no package, so `apt-get upgrade` cannot patch it.
    #   The images start with tini and never run it, so remove it
    rm -rf /usr/bin/pebble /var/lib/pebble && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    echo "C.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen

# Create alternative for nano -> nano-tiny
RUN update-alternatives --install /usr/bin/nano nano /bin/nano-tiny 10

# Configure environment
# (NB_UID/NB_GID are exported here once; the common layer re-exported them
#  after its base image, which is unnecessary now that there is one Dockerfile)
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8
ENV PATH="${CONDA_DIR}/bin:${PATH}" \
    HOME="/home/${NB_USER}"

# Configure the environment added by the common layer
ENV MKL_THREADING_LAYER="GNU"
ENV CFLAGS="-fcommon -fpic"
ENV PIP_TOOLS_CACHE_DIR="${HOME}/.cache/pip"
ARG TZ='America/New_York'
ARG USE_FROZEN=1
ENV USE_FROZEN=${USE_FROZEN}
ARG PIP_SWITCHES=""
ENV PIP_SWITCHES=${PIP_SWITCHES}
# Enable easy swap of conda with e.g. mamba
ARG CONDA_VER=mamba
ENV CONDA_VER=${CONDA_VER}
ARG MAMBA_ROOT_PREFIX=/opt/conda
ENV MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX}
ARG USER_CACHE_DIRS=""
ENV USER_CACHE_DIRS="${USER_CACHE_DIRS}"
ENV KERNEL_SHELL=bash

# Make sure user cache directories exist (empty by default; deployments can
# point these at RUN-cache mount points)
RUN for DIR in ${USER_CACHE_DIRS}; do mkdir -p ${DIR}; chown -R ${NB_UID}:${NB_GID} ${DIR}; done

# Copy a script that we will use to correct permissions after running certain commands
COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
# hadolint ignore=SC2016
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
    # More information in: https://github.com/jupyter/docker-stacks/pull/2047
    # and docs: https://docs.conda.io/projects/conda/en/latest/dev-guide/deep-dives/activation.html
    echo 'eval "$(conda shell.bash hook)"' >> /etc/skel/.bashrc

# Delete existing user with UID="${NB_UID}" if it exists
RUN if id -un "${NB_UID}" >/dev/null 2>&1; then \
        userdel --remove "$(id -un "${NB_UID}")"; \
    fi

# Create "${NB_USER}" user (`jovyan` by default) with UID="${NB_UID}" (`1000` by default) and in the 'users' group
# and make sure these dirs are writable by the `users` group.
# (the common layer disabled the admin/sudo groups in /etc/sudoers; since sudo
#  is never installed, there is no sudoers file to edit)
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" --no-user-group "${NB_USER}" && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${NB_USER}:${NB_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Pre-create the cache dir owned by the user, macOS Rosetta junk can then only appear inside it
RUN rm -rf "/home/${NB_USER}/.cache/" && \
    mkdir -p "/home/${NB_USER}/.cache" && \
    chown "${NB_USER}:${NB_GID}" "/home/${NB_USER}/.cache"

USER ${NB_UID}

# Pin the Python version here, or set it to "default"
ARG PYTHON_VERSION=3.13

# Setup work directory for backward-compatibility
RUN mkdir "/home/${NB_USER}/work" && \
    fix-permissions "/home/${NB_USER}"

# Install the Conda prefix using Micromamba from the digest-pinned official image (see top of this file).
#   <https://github.com/mamba-org/mamba#micromamba>
#   Similar projects using Micromamba:
#     - Micromamba-Docker: <https://github.com/mamba-org/micromamba-docker>
#     - repo2docker: <https://github.com/jupyterhub/repo2docker>
# Install the packages listed in `requirements.mamba` (Python and Mamba and
# jupyter_core from docker-stacks-foundation; JupyterHub, JupyterLab, NBClassic
# and Jupyter Notebook from base-notebook; awscli replacing the common layer's
# awscliv2.zip download), with the placeholder tokens in that file replaced
# with the pinned micromamba version and the PYTHON_VERSION arg.
# Generate a Jupyter Server config.
# Cleanup temporary files.
# Correct permissions.
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change.
# This is the single package transaction that a lockfile would pin down.
COPY --chown="${NB_UID}:${NB_GID}" initial-condarc "${CONDA_DIR}/.condarc"
COPY requirements.mamba /tmp/requirements.mamba
WORKDIR /tmp
RUN --mount=type=bind,from=micromamba,source=/bin/micromamba,target=/usr/local/bin/micromamba \
    set -x && \
    PYTHON_SUFFIX="=${PYTHON_VERSION}" && \
    if [ "${PYTHON_VERSION}" = "default" ]; then PYTHON_SUFFIX=""; fi && \
    # Replace the `@MAMBA_VERSION@` token with the version of the pinned
    # micromamba binary and the `@PYTHON@` token with the Python version
    # constraint, then strip comments and collapse the list to a single
    # whitespace-separated line for the install
    PKGS="$(sed -e "s/@MAMBA_VERSION@/$(micromamba --version)/" -e "s/@PYTHON@/${PYTHON_SUFFIX}/" /tmp/requirements.mamba | sed 's/#.*//' | tr -s '[:space:]' ' ')" && \
    # Install the packages in one transaction targeting ${CONDA_DIR}
    micromamba install \
        --root-prefix="${CONDA_DIR}" \
        --prefix="${CONDA_DIR}" \
        --yes \
        ${PKGS} && \
    # rm -f /tmp/requirements.mamba && \
    # Pin major.minor version of python
    # https://conda.io/projects/conda/en/latest/user-guide/tasks/manage-pkgs.html#preventing-packages-from-updating-pinning
    mamba list --full-name 'python' | awk 'END{sub("[^.]*$", "*", $2); print $1 " " $2}' >> "${CONDA_DIR}/conda-meta/pinned" && \
    jupyter server --generate-config && \
    mamba clean --all -f -y && \
    jupyter lab clean && \
    rm -rf "/home/${NB_USER}/.cache/yarn" && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# Copy local files as late as possible to avoid cache busting
COPY _docker_stacks_log.sh run-hooks.sh start.sh /usr/local/bin/
COPY start-notebook.py start-notebook.sh start-singleuser.py start-singleuser.sh /usr/local/bin/
COPY jupyter_server_config.py docker_healthcheck.py /etc/jupyter/

# Configure container entrypoint and startup
ENTRYPOINT ["tini", "-g", "--", "start.sh"]
CMD ["start-notebook.py"]

ENV JUPYTER_PORT=8888
EXPOSE $JUPYTER_PORT

# HEALTHCHECK documentation: https://docs.docker.com/engine/reference/builder/#healthcheck
# This healtcheck works well for `lab`, `notebook`, `nbclassic`, `server`, and `retro` jupyter commands
# https://github.com/jupyter/docker-stacks/issues/915#issuecomment-1068528799
HEALTHCHECK --interval=3s --timeout=1s --start-period=3s --retries=3 \
    CMD ["/etc/jupyter/docker_healthcheck.py"]

USER root

# Create dirs for startup hooks
RUN mkdir /usr/local/bin/start-notebook.d && \
    mkdir /usr/local/bin/before-notebook.d

COPY 10activate-conda-env.sh /usr/local/bin/before-notebook.d/

# Fix permissions on /etc/jupyter as root
RUN fix-permissions /etc/jupyter/

# Add an R mimetype option to specify how the plot returns from R to the browser
COPY --chown=${NB_UID}:${NB_GID} Rprofile.site /opt/conda/lib/R/etc/

# Add setup scripts that may be used by downstream images or inherited images
COPY setup-scripts/ /opt/setup-scripts/

# =========================================================================
# Content added by the science-platform-images common layer
# (deployments/common/Dockerfile), merged in above ordering.

# Match the common layer's login-shell behavior for downstream scripts
SHELL ["/bin/bash", "--login", "-c"]

# For ENV_BASH definition for non-login shells
COPY bash.env /etc/bash.env
ENV BASH_ENV=/etc/bash.env

# System-wide .bashrc for non-login bash shells (sources the base environment
# and puts /opt/tools user utilities on PATH)
COPY bash.bashrc /tmp/bash.bashrc
RUN cat /tmp/bash.bashrc >> /etc/bash.bashrc && rm -f /tmp/bash.bashrc

# nb-wrangler configuration for installation under the base environment
COPY nb-wrangler.rc /etc/nb-wrangler.rc

# ----------------------------------------------------------------------
# Set up the nb-wrangler pantry and root, will be further augmented by
# specific deployments

RUN source /etc/nb-wrangler.rc && \
    mkdir -p ${NBW_ROOT} ${NBW_ROOT}/temps && \
    chown -R ${NB_UID}:${NB_GID} ${NBW_ROOT} ${NBW_ROOT}/temps && \
    chmod -R 775 ${NBW_ROOT} ${NBW_ROOT}/temps && \
    chmod -R g+s ${NBW_ROOT} ${NBW_ROOT}/temps

# ----------------------------------------------------------------------

USER ${NB_UID}:${NB_GID}
COPY --chown=${NB_UID}:${NB_GID} common-scripts/ /opt/common-scripts
COPY --chown=${NB_UID}:${NB_GID} default-home-contents/ /etc/default-home-contents
COPY --chown=${NB_UID}:${NB_GID} tools/ /opt/tools/
COPY --chown=${NB_UID}:${NB_GID} VERSION /opt
COPY --chown=${NB_UID}:${NB_GID} HASH /opt

# ----------------------------------------------------------------------

USER root
RUN chown -R ${NB_UID}:${NB_GID} $HOME /opt/conda && \
    fix-permissions $HOME /opt/conda

# =========================================================================
# Content added by the wrangler (generic-base) deployment layer
# (deployments/wrangler), merged in above ordering. The wrangler mission
# environment *is* the base environment (kernel python3), so no second conda
# environment is created: the mission packages from the spec were merged into
# `requirements.mamba`/`requirements.pip`, and the nb-wrangler bootstrap step
# is just the nb-wrangler entry in `requirements.pip`.

# Remove the base-environment conda-meta lock owned by root so the base
# environment remains updatable
RUN chown ${NB_UID}:${NB_GID} /opt/conda/conda-meta && \
    rm -f /opt/conda/conda-meta/conda-meta.lock

# Suppress tensorflow warnings by default, ERROR and up only
ENV TF_CPP_MIN_LOG_LEVEL=2

# Notebook content and the wrangler spec (source of the kernel name, app
# launcher items, environment variables, and notebook tests), plus the frozen
# environment records kept for provenance
COPY --chown=${NB_UID}:${NB_GID} environments/ /opt/environments/
COPY --chown=${NB_UID}:${NB_GID} env-frozen/ /opt/env-frozen/
COPY --chown=${NB_UID}:${NB_GID} MISSION_VERSION /opt/MISSION_VERSION
COPY --chown=${NB_UID}:${NB_GID} MISSION_HASH /opt/MISSION_HASH

# Jupyter server extension allowing the notebook server to be stopped from the
# Lab GUI (/srv/jupyter is on PYTHONPATH via /opt/environments/nbw-exports.sh)
COPY stop_server_ext.json /etc/jupyter/jupyter_server_config.d/stop_server_ext.json
RUN mkdir -p /srv/jupyter
COPY --chown=${NB_UID}:${NB_GID} stop_server_ext.py /srv/jupyter/stop_server_ext.py

# Enable deletion of non-empty directories from lab GUI
RUN echo "# -------------------------------- STSCI Config Overwrites --------------------------------" \
      >> /etc/jupyter/jupyter_notebook_config.py &&\
    echo "c.FileContentsManager.delete_to_trash = False" >> /etc/jupyter/jupyter_notebook_config.py &&\
    echo "c.FileContentsManager.always_delete_dir = True" >> /etc/jupyter/jupyter_notebook_config.py &&\
    echo "# -------------------------------- STSCI Config Overwrites --------------------------------" \
      >> /etc/jupyter/jupyter_server_config.py &&\
    echo "c.FileContentsManager.delete_to_trash = False" >> /etc/jupyter/jupyter_server_config.py &&\
    echo "c.FileContentsManager.always_delete_dir = True" >> /etc/jupyter/jupyter_server_config.py

# Install all Python (pip) packages in a single transaction; this replaces the
# old install-common/env-sync flow and the nbw --reinstall curation step (the
# pinned requirements those produced are now checked in statically)
USER ${NB_UID}
COPY requirements.pip /tmp/requirements.pip
RUN pip install ${PIP_SWITCHES} -r /tmp/requirements.pip && \
    rm -f /tmp/requirements.pip && \
    /opt/common-scripts/env-clean

# Populate $HOME from /etc/default-home-contents, register the mission kernel,
# and install the jupyter app launcher items ("docker" == skip hub-only steps)
RUN /opt/environments/post-start-hook docker

# Deployment shell setup: resolves the default environment name from the spec
# and activates it in every shell
USER root
COPY global_bashrc /tmp/global_bashrc
RUN  cat /tmp/global_bashrc /opt/environments/nbw-exports.sh >> /etc/bash.bashrc && \
     cat /tmp/global_bashrc /opt/environments/nbw-exports.sh >> /etc/bash.env && \
     rm -f /tmp/global_bashrc

# Provenance marker for frozen vs. floating requirement sets
RUN [ "${USE_FROZEN}" -eq "1" ] && echo >/opt/FROZEN || echo >/opt/FLOATING

RUN rm -rf "/home/${NB_USER}/.cache/rosetta"

# Switch back to jovyan to avoid accidental container runs as root
USER ${NB_UID}

WORKDIR "${HOME}"
