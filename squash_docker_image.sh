#!/bin/bash

# A script to squash a Docker image into a single layer while preserving critical metadata.
#
# USAGE:
#   ./squash_docker_image.sh <source_image> <target_image>
#
# DEPENDENCIES:
#   - docker
#   - jq (for parsing JSON output from docker inspect)
#
# DESCRIPTION:
# This script implements a Docker image squashing capability. It works by:
# 1. Inspecting the source image to extract its metadata (CMD, ENTRYPOINT, ENV, etc.).
# 2. Creating a temporary container from the source image.
# 3. Exporting the container's filesystem to a tarball, effectively flattening it.
# 4. Importing the flattened filesystem as a new, single-layer image (the "base").
# 5. Generating a temporary Dockerfile that starts FROM the new base and reapplies
#    all the extracted metadata.
# 6. Building the final target image from this Dockerfile.
# 7. Cleaning up all temporary artifacts (container, base image, Dockerfile).

set -e

SOURCE_IMAGE="$1"
TARGET_IMAGE="$2"
TEMP_BASE_IMAGE="squash-base-$(uuidgen)"
TEMP_DOCKERFILE="Dockerfile.squash-$(uuidgen)"

# --- Helper Functions ---

# Check for required command-line arguments
check_args() {
  if [ -z "$SOURCE_IMAGE" ] || [ -z "$TARGET_IMAGE" ]; then
    echo "Usage: $0 <source_image> <target_image>" >&2
    exit 1
  fi
}

# Check for dependencies
check_deps() {
  if ! command -v docker &> /dev/null; then
    echo "Error: 'docker' is not installed or not in your PATH." >&2
    exit 1
  fi
  if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed or not in your PATH. It's required for parsing image metadata." >&2
    exit 1
  fi
}

# Cleanup function to remove temporary artifacts
cleanup() {
  echo "--- Cleaning up temporary artifacts ---"
  if docker image inspect "$TEMP_BASE_IMAGE" &> /dev/null; then
    docker rmi "$TEMP_BASE_IMAGE"
  fi
  if [ -f "$TEMP_DOCKERFILE" ]; then
    rm "$TEMP_DOCKERFILE"
  fi
  # The container is already removed after export
  echo "Cleanup complete."
}

# --- Main Logic ---

main() {
  check_args
  check_deps

  # Ensure cleanup runs on script exit
  trap cleanup EXIT

  echo "--- Starting image squashing process for '$SOURCE_IMAGE' ---"

  # 1. Inspect the source image and extract metadata
  echo "Step 1: Inspecting source image and extracting metadata..."
  local inspection
  inspection=$(docker inspect "$SOURCE_IMAGE")

  # 2. Create temporary Dockerfile and add metadata
  echo "Step 2: Generating Dockerfile with preserved metadata..."
  # Start with the temporary base image (which we'll create next)
  echo "FROM $TEMP_BASE_IMAGE" > "$TEMP_DOCKERFILE"

  # Re-apply metadata using Dockerfile instructions
  jq -r '.[0].Config.Env[]' <<< "$inspection" | while read -r env; do
    # Split ENV var on the first '='
    key=$(echo "$env" | cut -d'=' -f1)
    value=$(echo "$env" | cut -d'=' -f2-)
    # Quote the value to handle spaces correctly
    echo "ENV $key=\"$value\"" >> "$TEMP_DOCKERFILE"
  done

  jq -r '.[0].Config.WorkingDir | select(. != null and . != "")' <<< "$inspection" | while read -r wd; do
    echo "WORKDIR $wd" >> "$TEMP_DOCKERFILE"
  done
  
  jq -r '.[0].Config.User | select(. != null and . != "")' <<< "$inspection" | while read -r user; do
    echo "USER $user" >> "$TEMP_DOCKERFILE"
  done

  jq -r '.[0].Config.ExposedPorts | keys[] | select(. != null)' <<< "$inspection" | while read -r port; do
    echo "EXPOSE $port" >> "$TEMP_DOCKERFILE"
  done

  jq -r '.[0].Config.OnBuild | select(. != null) | .[]' <<< "$inspection" | while read -r onbuild; do
    echo "ONBUILD $onbuild" >> "$TEMP_DOCKERFILE"
  done
  
  jq -r '.[0].Config.StopSignal | select(. != null)' <<< "$inspection" | while read -r signal; do
    echo "STOPSIGNAL $signal" >> "$TEMP_DOCKERFILE"
  done

  # Handle Entrypoint and Cmd
  local entrypoint
  entrypoint=$(jq '.[0].Config.Entrypoint' <<< "$inspection")
  if [ "$entrypoint" != "null" ]; then
    echo "ENTRYPOINT $(jq -c '.' <<< "$entrypoint")" >> "$TEMP_DOCKERFILE"
  fi

  local cmd
  cmd=$(jq '.[0].Config.Cmd' <<< "$inspection")
  if [ "$cmd" != "null" ]; then
    echo "CMD $(jq -c '.' <<< "$cmd")" >> "$TEMP_DOCKERFILE"
  fi
  
  # Handle Labels
  jq -r '.[0].Config.Labels | to_entries | .[] | "\(.key)=\"\(.value)\""' <<< "$inspection" | while read -r label; do
      echo "LABEL $label" >> "$TEMP_DOCKERFILE"
  done

  echo "Generated temporary Dockerfile '$TEMP_DOCKERFILE'."

  # 3. Flatten the image using docker export/import
  echo "Step 3: Flattening the image via export/import..."
  local container_id
  # Use --rm to automatically clean up the container after export
  container_id=$(docker create "$SOURCE_IMAGE")
  docker export "$container_id" | docker import - "$TEMP_BASE_IMAGE"
  docker rm "$container_id" > /dev/null
  echo "Flattened base image '$TEMP_BASE_IMAGE' created."

  # 4. Build the final image from the generated Dockerfile
  echo "Step 4: Building final squashed image '$TARGET_IMAGE' நான்காம்..."
  docker build --no-cache -t "$TARGET_IMAGE" -f "$TEMP_DOCKERFILE" .

  echo "--- Squashing complete! ---"
  echo "Final image '$TARGET_IMAGE' has been created."
}

# --- Run main function ---
main
