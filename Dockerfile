# syntax=docker/dockerfile:1

############## picons stage ##############
# built by https://github.com/linuxserver/picons-builder
FROM ghcr.io/linuxserver/picons-builder as piconsstage


FROM ghcr.io/linuxserver/baseimage-alpine:edge as buildstage
############## build stage ##############

# environment settings
ARG TZ="Etc/UTC"
ARG TVHEADEND_COMMIT
ENV HOME="/config"

# copy patches and picons
COPY patches/ /tmp/patches/
COPY --from=piconsstage /picons.tar.bz2 /picons.tar.bz2

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache \
    argtable2-dev \
    autoconf \
    automake \
    bsd-compat-headers \
    build-base \
    cmake \
    ffmpeg-dev \
    file \
    findutils \
    gettext-dev \
    git \
    gnu-libiconv-dev \
    libdvbcsa-dev \
    libgcrypt-dev \
    libhdhomerun-dev \
    libtool \
    libva-dev \
    libvpx-dev \
    libxml2-dev \
    libxslt-dev \
    linux-headers \
    openssl-dev \
    opus-dev \
    patch \
    pcre2-dev \
    pkgconf \
    pngquant \
    python3 \
    sdl2-dev \
    uriparser-dev \
    x264-dev \
    x265-dev \
    zlib-dev

RUN \
  echo "**** compile tvheadend ****" && \
  if [ -z ${TVHEADEND_COMMIT+x} ]; then \
    TVHEADEND_COMMIT=$(curl -sX GET https://api.github.com/repos/tvheadend/tvheadend/commits/master \
    | jq -r '. | .sha'); \
  fi && \
  mkdir -p \
    /tmp/tvheadend && \
  git clone https://github.com/jefflessard/tvheadend.git /tmp/tvheadend && \
  cd /tmp/tvheadend && \
  git checkout ${TVHEADEND_COMMIT} && \
  ./configure \
    `#Encoding` \
    --disable-ffmpeg_static \
    --disable-libfdkaac_static \
    --disable-libtheora_static \
    --disable-libopus_static \
    --disable-libvorbis_static \
    --disable-libvpx_static \
    --disable-libx264_static \
    --disable-libx265_static \
    --disable-libfdkaac \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    \
    `#Options` \
    --disable-avahi \
    --disable-dbus_1 \
    --disable-bintray_cache \
    --disable-execinfo \
    --disable-hdhomerun_static \
    --enable-hdhomerun_client \
    --enable-libav \
    --enable-pngquant \
    --enable-trace \
    --enable-vaapi \
    --infodir=/usr/share/info \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --prefix=/usr \
    --python=python3 \
    --sysconfdir=/config && \
  make -j$(nproc) && \
  make DESTDIR=/tmp/tvheadend-build install

RUN \
  echo "***** compile comskip ****" && \
  git clone https://github.com/kainlan/Comskip /tmp/comskip && \
  cd /tmp/comskip && \
  ./autogen.sh && \
  ./configure \
    --bindir=/usr/bin \
    --sysconfdir=/config/comskip && \
  make -j$(nproc) && \
  make DESTDIR=/tmp/comskip-build install

RUN \
  echo "***** extract picons ****" && \
  mkdir -p /picons && \
  tar xf \
    /picons.tar.bz2 -C \
    /picons

############## runtime stage ##############
FROM ghcr.io/linuxserver/baseimage-alpine:edge

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="saarg"

# environment settings
ENV HOME="/config"
ENV RADV_PERFTEST="video_decode,video_encode"
ENV ANV_DEBUG="video-decode,video-encode"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    argtable2 \
    bsd-compat-headers \
    ffmpeg \
    ffmpeg-libavcodec \
    ffmpeg-libavdevice \
    ffmpeg-libavfilter \
    ffmpeg-libavformat \
    ffmpeg-libavutil \
    ffmpeg-libswresample \
    ffmpeg-libswscale \
    gnu-libiconv \
    libdvbcsa \
    libhdhomerun-libs \
    libva \
    libva-intel-driver \
    intel-media-driver \
    libvpx \
    libxml2 \
    libxslt \
    linux-headers \
    mesa-va-gallium \
    mesa-vulkan-ati \
    mesa-vulkan-intel \
    opus \
    pcre2 \
    perl \
    perl-datetime-format-strptime \
    perl-json \
    perl-json-xs \
    py3-requests \
    python3 \
    shaderc \
    uriparser \
    vulkan-tools \
    x264 \
    x265 \
    xmltv \
    zlib && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version

RUN \
  rm -rf /tmp/packages

# copy local files and buildstage artifacts
COPY --from=buildstage /tmp/comskip-build/usr/ /usr/
COPY --from=buildstage /tmp/tvheadend-build/usr/ /usr/
COPY --from=buildstage /picons /picons
COPY transcode-hevc /usr/bin/
COPY root/ /

# ports and volumes
EXPOSE 9981 9982
VOLUME /config
