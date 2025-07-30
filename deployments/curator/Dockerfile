# ========================= vvvvv Custom  vvvvv =========================

ARG BASE_IMAGE=notebook-common
FROM $BASE_IMAGE AS build

ARG NBC_ROOT="/opt/nbc-live"
ENV NBC_ROOT="${NBC_ROOT}"

ARG NBC_PANTRY="/teams/users/nbc-pantry"
ENV NBC_PANTRY="${NBC_PANTRY}"

# ----------------------------------------------------------------------
# Install environments

USER root
RUN mkdir -p ${NBC_ROOT} && chown -R ${NB_UID}:${NB_GID} ${NBC_ROOT} && \
    mkdir -p ${NBC_PANTRY} && chown -R ${NB_UID}:${NB_GID} ${NBC_PANTRY}

# ----------------------------------------------------------------------
# Add jupyter-lab-extensions to base environment as well as standard packages.
# Performing common update here enables mission specific frozen spec.

COPY --chown=${NB_UID}:${NB_GID} env-frozen/base/  /opt/env-frozen/base/
COPY --chown=${NB_UID}:${NB_GID} environments/common-hints.* /opt/environments/
RUN   /opt/common-scripts/install-common  base && \
      fix-permissions

USER ${NB_UID}:${NB_GID}

WORKDIR ${NBC_ROOT}
RUN curl https://raw.githubusercontent.com/spacetelescope/nb-curator/refs/heads/main/nb-curator >nb-curator && \
    chmod +x nb-curator && \
    ${NBC_ROOT}/nb-curator bootstrap && \
    chmod -R g+w ${NBC_ROOT} && \
    cp nb-curator /opt/tools && \
    rm -rf ${NBC_ROOT}/cache ${NBC_ROOT}/mm/pkgs

# Suppress tensorflow warnings by default, ERROR and up only
ENV TF_CPP_MIN_LOG_LEVEL=2

# ========================= ^^^^^ Custom  ^^^^^ =========================
# ========================= vvvvv Generic vvvvv  =========================

USER ${NB_UID}:${NB_GID}

# ----------------------------------------------------------------------

RUN /opt/common-scripts/kernel-setup   # set up Ipython / JupyterLab kernels

# ----------------------------------------------------------------------
# As part of Dockerfile.trailer,  these statements are executed from the
# perspective of the deployment image directory,  not common.

USER root

# remove this step once nbgitpuller enabled; these contents will be in the
#  jupyterhub-user-content repo.   Install deployment-specific $HOME files.
COPY default-home-contents/ /etc/default-home-contents
RUN  cp -r $HOME/.local /etc/default-home-contents && \
     cp -r $HOME/.jupyter /etc/default-home-contents
COPY global_bashrc $HOME
RUN  cat $HOME/global_bashrc >> /etc/bash.bashrc  && \
     cat $HOME/global_bashrc >> /etc/bash.env  && \
     rm $HOME/global_bashrc

# Copy any remaining environments files not caught by more precise as-needed build copies
COPY --chown=${NB_UID}:${NB_GID} environments/    /opt/environments/

# ----------------------------------------------------------------------

COPY --chown=${NB_UID}:${NB_GID}  MISSION_VERSION /opt
COPY --chown=${NB_UID}:${NB_GID}  MISSION_HASH /opt
RUN  [ $USE_FROZEN -eq "1" ] && echo >/opt/FROZEN || echo >/opt/FLOATING

# ----------------------------------------------------------------------
# For standalone operation outside JupyterHub,  note that  /etc also includes
# common home directory files.   post-start-hook may not include everything required
# for running on AWS,  just common functions needed for both AWS and standalone/CI.

# Enable deletion of non-empty directories from lab GUI
RUN echo "# -------------------------------- STSCI Config Overwrites --------------------------------" \
      >> /etc/jupyter/jupyter_notebook_config.py &&\
    echo "c.FileContentsManager.delete_to_trash = False" >> /etc/jupyter/jupyter_notebook_config.py &&\
    echo "c.FileContentsManager.always_delete_dir = True" >> /etc/jupyter/jupyter_notebook_config.py &&\
    echo "# -------------------------------- STSCI Config Overwrites --------------------------------" \
      >> /etc/jupyter/jupyter_server_config.py &&\
    echo "c.FileContentsManager.delete_to_trash = False" >> /etc/jupyter/jupyter_server_config.py &&\
    echo "c.FileContentsManager.always_delete_dir = True" >> /etc/jupyter/jupyter_server_config.py

USER ${NB_UID}:${NB_GID}
RUN /opt/environments/post-start-hook  docker   # docker == do not run hub-specific functions of hook

USER root

RUN /opt/environments/post-start-hook  docker   # docker == do not run hub-specific functions of hook
RUN fix-permissions $CONDA_DIR $HOME

USER ${NB_UID}:${NB_GID}
WORKDIR $HOME
CMD [ "start-notebook.py" ]
