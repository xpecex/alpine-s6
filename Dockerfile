# BUILD FROM SCRATCH
FROM --platform=$TARGETPLATFORM scratch AS build

# BUILD ARGs
ARG TARGETPLATFORM
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.description="Alpine Linux with S6-Overlay" \
      org.label-schema.name="xpecex/alpine-s6" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.usage="https://github.com/xpecex/alpine-s6" \
      org.label-schema.vcs-url="https://github.com/xpecex/alpine-s6" \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vendor="xPeCex" \
      org.label-schema.version=${VERSION}

# ADD ALPINE ROOTFS
ADD ${TARGETPLATFORM}/rootfs.tar.gz /

# ADD S6-OVERLAY
ADD ${TARGETPLATFORM}/s6-overlay.tar.gz /

# INIT S6-OVERLAY
ENTRYPOINT ["/init"]

# SET DEFAULT COMMAND
CMD ["/bin/sh"]
