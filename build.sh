#!/bin/bash

# RELEASES LIST
RELEASES=(
    "3.10.0"
    "3.10.1"
    "3.10.2"
    "3.10.3"
    "3.10.4"
    "3.10.5"
    "3.11.0"
    "3.11.1"
    "3.11.2"
    "3.11.3"
    "3.11.4"
    "3.11.5"
    "3.11.6"
    "3.12.0"
    "3.12.1"
    "3.12.2"
    "3.12.3"
    "3.13.0"
    "3.13.1"
    "3.13.2"
    "3.13.3"
    "3.13.4"
    "3.13.5"
    "edge"
)
LATEST_STABLE="$(curl -sL https://alpinelinux.org/downloads/ | sed -n 's:.*<strong>\(.*\)</strong>.*:\1:p' )"
EDGE_LATEST="3.13.0"

# ARCHITECTURE LIST
ARCH=(
    "linux/386"
    "linux/amd64"
    "linux/arm/v6"
    "linux/arm/v7"
    "linux/arm64"
    "linux/ppc64le"
)

# REMOVE UNSUPPORTED ARCH FOR RELEASE
# ie: <release name>=<architecture 1>,<architecture 2>,...<architecture n>
UNSUPPORTED=(
    "3.5=linux/arm64,linux/ppc64le"
    "3.6=linux/arm64"
    "3.7=linux/arm64"
    "3.8=linux/arm64"
)
checkSupport() {

    # local var
    local REL=$1
    local _ARCH=("${ARCH[@]}")

    # Search elements in unsupported list
    for ((i = 0; i < ${#UNSUPPORTED[@]}; i++)); do
        # Check if element is equal release
        if [ "$REL" = "${UNSUPPORTED[$i]%%"="*}" ]; then
            UNSUPPORT="${UNSUPPORTED[$i]#*"="}"
            ARCH_REMOVE=(${UNSUPPORT/,/ })

            # Remove from ARCH list
            for item in "${ARCH_REMOVE[@]}"; do
                _ARCH=("${_ARCH[@]/$item/}")
            done
        fi
    done
    echo "${_ARCH[@]}"
}

# S6-OVERLAY
S6_LATEST_VERSION="$(curl -s https://github.com/just-containers/s6-overlay/releases/latest | cut -d '/' -f 8 | cut -d '"' -f 1 | cut -d 'v' -f 2)"
S6_INSTALL_VERSION="${S6_VERSION:-$S6_LATEST_VERSION}"
echo -e "S6-OVERLAY VERSION: ${S6_INSTALL_VERSION} \n"

# DOCKER LOGIN
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USER" --password-stdin &> /dev/null

# Search release for build
for RELEASE in "${RELEASES[@]}"; do

    _RELEASE=""
    if [ "$RELEASE" != "edge" ]; then
        _RELEASE=${RELEASE%.*}
    else 
        _RELEASE=${RELEASE}
    fi

    # Check ARCH support
    PLATFORM=($(checkSupport ${_RELEASE}))
    echo "$_RELEASE supported architectures: ${PLATFORM[@]}"

    # Init download of files for ARCH
    for _PLATFORM in "${PLATFORM[@]}"; do

        echo -e "\nDownload files from $_RELEASE FOR $_PLATFORM\n"

        _ARCH=""
        case "$_PLATFORM" in
            linux/386)      _ARCH="x86" ;;
            linux/amd64)    _ARCH="x86_64" ;;
            linux/arm/v6)   _ARCH="armhf" ;;
            linux/arm/v7)   _ARCH="armhf" ;;
            linux/arm64)    _ARCH="armv7" ;;
            linux/ppc64le)  _ARCH="ppc64le" ;;
        esac

        # SET ROOTFS DOWNLOAD URL 
        ROOTFS_URL="http://dl-cdn.alpinelinux.org/alpine/v${_RELEASE}/releases/${_ARCH}/alpine-minirootfs-${RELEASE}-${_ARCH}.tar.gz"
        if [ "$RELEASE" = "edge" ]; then
            ROOTFS_URL="http://dl-cdn.alpinelinux.org/alpine/${_RELEASE}/releases/${_ARCH}/alpine-minirootfs-${EDGE_LATEST}-${_ARCH}.tar.gz"
        fi

        # SET S6-OVERLAY DOWNLOAD URL
        if [ "${_ARCH}" = "x86_64" ]; then
            _ARCH="amd64"
        fi
        if [ "${_ARCH}" = "armv7" ]; then
            _ARCH="arm"
        fi
        S6_URL="https://github.com/just-containers/s6-overlay/releases/download/v${S6_INSTALL_VERSION}/s6-overlay-${_ARCH}.tar.gz"

        # Create dir for platform
        mkdir -p "$_PLATFORM"

        # DOWNLOAD ROOTFS AND S6-OVERLAY
        wget -nv "${ROOTFS_URL}" -O "${_PLATFORM}/rootfs.tar.gz" # rootfs
        wget -nv "${S6_URL}" -O "${_PLATFORM}/s6-overlay.tar.gz" # s6-overlay
    done

    # BUILD AND PUSH TO DOCKER

    # IMAGE CONFIG AND ARGS
    _NAME="${IMAGE_NAME:-$(git config --get remote.origin.url | sed 's/.*\/\([^ ]*\/[^.]*\).*/\1/')}"
    _VERSION="$RELEASE"
    _BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    _VCS_REF="$(git rev-parse --short HEAD)"
    _PLATFORMS="$( echo ${PLATFORM[@]} | sed 's/ /,/g' )"

    if [ "$RELEASE" = "$LATEST_STABLE" ]; then
        docker buildx build \
            --push \
	        --build-arg VERSION="${_VERSION}" \
	        --build-arg VCS_REF="${_VCS_REF}" \
	        --build-arg BUILD_DATE="${_BUILD_DATE}" \
	        --platform "${_PLATFORMS}" \
	        -t "${_NAME}:${RELEASE}" \
            -t "${_NAME}:latest" \
	        .
    else
        docker buildx build \
            --push \
	        --build-arg VERSION="${_VERSION}" \
	        --build-arg VCS_REF="${_VCS_REF}" \
	        --build-arg BUILD_DATE="${_BUILD_DATE}" \
	        --platform "${_PLATFORMS}" \
	        -t "${_NAME}:${RELEASE}" \
	        .
    fi

    # Remove Files
    rm -rf linux
done

# Build Finish
echo -e "Finish!\n"
