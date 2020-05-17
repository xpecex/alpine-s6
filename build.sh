#!/bin/bash

# List of Archs
PLATFORMS=("linux/386" "linux/amd64" "linux/arm/v6" "linux/arm/v7" "linux/arm64" "linux/aarch64" "linux/ppc64le")
PLATFORM="$( echo ${PLATFORMS[@]} | sed 's/ /,/g')"
echo $PLATFORM

# ALPINE VERSION
LATEST_STABLE="$(curl -sL https://alpinelinux.org/downloads/ | sed -n 's:.*<strong>\(.*\)</strong>.*:\1:p' )"
ALPINE_VER="${ALPINE_VERSION:-$LATEST_STABLE}"

# S6-OVERLAY
S6_VER="${S6_VERSION:-$(curl -s https://github.com/just-containers/s6-overlay/releases/latest | cut -d '/' -f 8 | cut -d '"' -f 1 | cut -d 'v' -f 2)}"

for ARCH in "${PLATFORMS[@]}" 
do
    # Create dir for rootfs and s6-overlay files
    echo "Creating directory: $ARCH"
    mkdir -p "$ARCH"

    # Download ALPINE ROOTFS
    echo "Download files for $ARCH"
    _ARCH=""
    case "$ARCH" in
	linux/386 ) 	_ARCH="x86" ;;
	linux/amd64 )   _ARCH="x86_64" ;;
	linux/arm/v6 )  _ARCH="armhf" ;;
	linux/arm/v7 )  _ARCH="armhf" ;;
	linux/arm64 )   _ARCH="armv7" ;;
	linux/aarch64 ) _ARCH="aarch64" ;;
	linux/ppc64le ) _ARCH="ppc64le" ;;
     esac
     ALPINE_URL="http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER%.*}/releases/${_ARCH}/alpine-minirootfs-${ALPINE_VER}-${_ARCH}.tar.gz"
     echo "ALPINE ROOTFS: $ALPINE_URL"
     wget -c -nv ${ALPINE_URL} -O ${ARCH}/rootfs.tar.gz

     # Download S6-OVERLAY
     if [ "$_ARCH" = "x86_64" ]; then
	_ARCH="amd64"
     fi
     if [ "$_ARCH" = "armv7" ]; then
	_ARCH="arm"
     fi
     S6_URL="https://github.com/just-containers/s6-overlay/releases/download/v${S6_VER}/s6-overlay-${_ARCH}.tar.gz"
     echo -e "S6-OVERLAY: $S6_URL \n"
     wget -c -nv ${S6_URL} -O ${ARCH}/s6-overlay.tar.gz

done

# BUILD AND PUSH TO DOCKER
NAME="${IMG_NAME:-$(git config --get remote.origin.url | sed 's/.*\/\([^ ]*\/[^.]*\).*/\1/')}"
TAG="${IMG_TAG:-$ALPINE_VER}"
echo "BUILD AND PUSH TO DOCKER"
echo "IMAGE: ${NAME}:${TAG}"
# DOCKER LOGIN
echo $DOCKER_PASSWORD | docker login -u xpecex --password-stdin &> /dev/null
docker buildx build \
	--build-arg VERSION="${ALPINE_VER}" \
	--build-arg VCS_REF="$(git rev-parse --short HEAD)" \
	--build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
	--platform="$PLATFORM" \
	-t ${TAG}:${ALPINE_VER} \
	--push \
	.

if [ "$BRANCH" = "master" ]; then
	docker buildx build \
        --build-arg VERSION="${ALPINE_VER}" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD)" \                                                                                                                  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --platform="$PLATFORM" \
        -t ${TAG}:latest \
        --push \
        .
fi

echo -e "\nDelete downloaded files"
echo -e "Finish!"
rm -rf linux
