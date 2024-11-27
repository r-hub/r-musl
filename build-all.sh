
docker build -f Dockerfile-libs -t ghcr.io/r-hub/r-musl-libs-common .
docker build -f Dockerfile-libs-musl -t ghcr.io/r-hub/r-musl-libs-musl .
docker build -f Dockerfile-libs-bionic -t ghcr.io/r-hub/r-musl-libs-bionic .
docker build -f Dockerfile -t ghcr.io/r-hub/r-musl .
docker build -f Dockerfile-bionic -t ghcr.io/r-hub/r-musl-glibc .
