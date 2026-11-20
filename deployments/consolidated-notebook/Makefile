# Simple Makefile to build (and use) the consolidated image locally.
# This mirrors the pattern of the docker-stacks root Makefile, but stands
# alone so the consolidated image directory stays self-contained:
#
#   cd deployments/consolidated-notebook && make build
#
# The consolidated image replaces the docker-stacks chain
# (docker-stacks-foundation -> base-notebook -> minimal-notebook) plus the
# science-platform-images common layer in a single build, so no intermediate
# notebook-common image is required for deployments built on top of it.
#
# Lock-readiness: `build` produces the unlocked image (solved from live conda
# channels at build time). A future `build-locked` target would consume a
# lockfile + downloaded packages directory (see the comments in the Dockerfile).

# Image name and tag to build
IMAGE_NAME?=consolidated-notebook
TAG?=latest

# Use Docker if available, otherwise use Apple's container framework
CONTAINER_CLI?=$(if $(shell command -v docker),docker,container)

# Build args (defaults match the Dockerfile; these mirror the variables that
# scripts/image-build used to pass to the separate base + common builds)
ROOT_IMAGE?=default_root_image
PYTHON_VERSION?=3.13
USE_FROZEN?=1
PIP_SWITCHES?=
CONDA_VER?=mamba
MAMBA_ROOT_PREFIX?=/opt/conda
USER_CACHE_DIRS?=

# Enable BuildKit for Docker builds
export DOCKER_BUILDKIT:=1

.PHONY: help build run shell clean

help: ## show this help
	@echo "consolidated-notebook"
	@echo "====================="
	@grep -E '^[a-zA-Z0-9_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## build the consolidated image (docker-stacks chain + common layer)
	$(CONTAINER_CLI) build \
	  --tag "$(IMAGE_NAME):$(TAG)" \
	  --build-arg ROOT_IMAGE="$(ROOT_IMAGE)" \
	  --build-arg PYTHON_VERSION="$(PYTHON_VERSION)" \
	  --build-arg USE_FROZEN="$(USE_FROZEN)" \
	  --build-arg PIP_SWITCHES="$(PIP_SWITCHES)" \
	  --build-arg CONDA_VER="$(CONDA_VER)" \
	  --build-arg MAMBA_ROOT_PREFIX="$(MAMBA_ROOT_PREFIX)" \
	  --build-arg USER_CACHE_DIRS="$(USER_CACHE_DIRS)" \
	  .
	@$(CONTAINER_CLI) image ls | grep -E "^(REPOSITORY|NAME|IMAGE)|^$(IMAGE_NAME)[: ]"

run: ## run the consolidated image, mapping the Jupyter port
	$(CONTAINER_CLI) run --rm -it --publish 8888:8888 "$(IMAGE_NAME):$(TAG)"

shell: ## run bash in interactive mode inside the consolidated image
	$(CONTAINER_CLI) run --rm -it "$(IMAGE_NAME):$(TAG)" bash

clean: ## remove the locally built consolidated image
	-$(CONTAINER_CLI) image rm --force "$(IMAGE_NAME):$(TAG)"
