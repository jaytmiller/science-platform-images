# Static equivalent of the build-time generated wrangler environment exports
# (formerly produced inside the image by
#   `nbw --data-print --data-env-vars-mode pantry --data-no-symlinks`):
# the `environment_vars` block of environments/nbw-wrangler-spec.yaml.
export PYTHONPATH="/srv/jupyter:$PYTHONPATH"
