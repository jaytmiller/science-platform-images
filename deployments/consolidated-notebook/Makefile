# Simple Makefile to build (and use) the consolidated image locally.
# This mirrors the pattern of the repo-root Makefile, but stands alone so the
# consolidated image directory stays self-contained:
#
#   cd images/consolidated-notebook && make build
#
# Lock-readiness: `build` produces the unlocked image (solved from live conda
# channels at build time). A future `build-locked` target would consume a
# lockfile + downloaded packages directory (see the comments in the Dockerfile).

# Image name and tag to build
IMAGE_NAME?=consolidated-notebook
TAG?=latest

# Use Docker if available, otherwise use Apple's container framework
CONTAINER_CLI?=$(if $(shell command -v docker),docker,container)

# Only applicable knobs (same as the upstream docker-stacks-foundation args)
ROOT_IMAGE?=default_root_image
PYTHON_VERSION?=3.13

# Enable BuildKit for Docker builds
export DOCKER_BUILDKIT:=1

.PHONY: help build run shell clean

help: ## show this help
	@echo "consolidated-notebook"
	@echo "====================="
	@grep -E '^[a-zA-Z0-9_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## build the consolidated image
	$(CONTAINER_CLI) build \
	  --tag "$(IMAGE_NAME):$(TAG)" \
	  --build-arg ROOT_IMAGE="$(ROOT_IMAGE)" \
	  --build-arg PYTHON_VERSION="$(PYTHON_VERSION)" \
	  .
	@$(CONTAINER_CLI) image ls | grep -E "^(REPOSITORY|NAME|IMAGE)|^$(IMAGE_NAME)[: ]"

run: ## run the consolidated image, mapping the Jupyter port
	$(CONTAINER_CLI) run --rm -it --publish 8888:8888 "$(IMAGE_NAME):$(TAG)"

shell: ## run bash in interactive mode inside the consolidated image
	$(CONTAINER_CLI) run --rm -it "$(IMAGE_NAME):$(TAG)" bash

clean: ## remove the locally built consolidated image
	-$(CONTAINER_CLI) image rm --force "$(IMAGE_NAME):$(TAG)"
