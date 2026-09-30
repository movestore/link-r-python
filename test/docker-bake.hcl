# Builds and tests both translator Apps from the real Dockerfile, on public images only:
#
#   co-pilot-r (stand-in) --BASE--+--> app-r2python --+
#   miniforge -----------CONDA----+--> app-python2r --+--> test: R unit tests, round trip, coherence
#
#   docker buildx bake -f test/docker-bake.hcl test

# "gha" inside GitHub Actions; empty elsewhere, where no Actions cache exists
variable "CACHE" {
  default = ""
}

# "true" for the runs that must resolve everything from scratch (see .github/workflows/test.yml)
variable "FRESH" {
  default = "false"
}

# the python co-pilot's own base; test/coherence.R holds test/Dockerfile to the same tag
variable "CONDA" {
  default = "condaforge/miniforge3:26.7.2-0"
}

function "cacheFrom" {
  params = [scope]
  result = CACHE == "gha" && FRESH != "true" ? ["type=gha,scope=${scope}"] : []
}

function "cacheTo" {
  params = [scope]
  result = CACHE == "gha" ? ["type=gha,mode=max,scope=${scope},ignore-error=true"] : []
}

target "co-pilot-r" {
  context = "."
  dockerfile = "test/co-pilot-r.Dockerfile"
  platforms = ["linux/amd64"]
  no-cache = FRESH == "true"
  cache-from = cacheFrom("co-pilot-r")
  cache-to = cacheTo("co-pilot-r")
}

target "app" {
  name = "app-${direction}"
  matrix = {
    direction = ["r2python", "python2r"]
  }
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]
  tags = ["link-r-python:${direction}"]
  contexts = {
    co-pilot-r = "target:co-pilot-r"
  }
  args = {
    BASE = "co-pilot-r"
    CONDA = CONDA
    DIRECTION = direction
  }
  no-cache = FRESH == "true"
  cache-from = cacheFrom("app-${direction}")
  cache-to = cacheTo("app-${direction}")
}

target "test" {
  context = "."
  dockerfile = "test/app-test.Dockerfile"
  platforms = ["linux/amd64"]
  contexts = {
    app-r2python = "target:app-r2python"
    app-python2r = "target:app-python2r"
  }
  no-cache = FRESH == "true"
  cache-from = cacheFrom("test")
  cache-to = cacheTo("test")
}

# Both must fail. The platform passes no build arguments, so a Dockerfile copy without its DIRECTION
# edit has to be refused rather than built.
target "app-without-direction" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64"]
  contexts = {
    co-pilot-r = "target:co-pilot-r"
  }
  args = {
    BASE = "co-pilot-r"
    CONDA = CONDA
  }
}

target "app-with-invalid-direction" {
  inherits = ["app-without-direction"]
  args = {
    DIRECTION = "sideways"
  }
}
