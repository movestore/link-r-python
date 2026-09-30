# Runs a command inside an App image and copies its results out. No bind mounts: Docker Desktop on
# macOS cannot mount the per-user temp directories, and copying leaves the image's own files alone.
#
#   runInImage <image> <input dir> <command> <output dir>
#     <input dir>  -> /tmp/in   read only: owned by root inside the container
#     <command>       runs as the image's user in /home/moveapps/co-pilot-r and writes to /tmp/out
#     /tmp/out     -> <output dir>
#
# OVERLAY=1 first replaces the image's r/link.R, r/rds_2_csv.R and r/csv_2_rds.R with this
# checkout's - how a change to the R side is proved against an older image.
runInImage() {
  local image="$1" input="$2" command="$3" output="$4"
  local container status

  container="$(docker create --platform linux/amd64 --entrypoint bash -w /home/moveapps/co-pilot-r "$image" -c "$command")"
  docker cp "$input" "$container:/tmp/in" > /dev/null

  if [ "${OVERLAY:-0}" = 1 ]; then
    for file in r/link.R r/rds_2_csv.R r/csv_2_rds.R; do
      docker cp "$file" "$container:/home/moveapps/co-pilot-r/$file" > /dev/null
    done
  fi

  docker start --attach "$container" && status=0 || status=$?

  rm -rf "$output"
  docker cp "$container:/tmp/out" "$output" > /dev/null || true
  docker rm "$container" > /dev/null
  return "$status"
}
