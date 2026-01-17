# ---------------------------------------------------------------------------- Stage 1
FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV ASTERISK_VERSION=22.7.0

WORKDIR /usr/src

RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    subversion \
    pkg-config \
    git \
    curl \
    ca-certificates \
    aptitude \
    libxml2-dev \
    libncurses5-dev \
    libsqlite3-dev \
    libssl-dev \
    uuid-dev \
    libjansson-dev

RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz && \
    wget https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.sha256 && \
    sha256sum -c asterisk-${ASTERISK_VERSION}.sha256 && \
    tar zxvf asterisk-${ASTERISK_VERSION}.tar.gz && \
    rm asterisk-${ASTERISK_VERSION}.tar.gz asterisk-${ASTERISK_VERSION}.sha256

WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}



RUN ./contrib/scripts/install_prereq install
RUN ./contrib/scripts/install_prereq install-unpackaged
RUN ./contrib/scripts/get_mp3_source.sh
RUN ./configure --with-pjproject-bundled

RUN make menuselect


RUN ./menuselect/menuselect \
    --disable BUILD_NATIVE \
    # --- Enable Codecs ---
    --enable codec_a_mu \
    --enable codec_adpcm \
    --enable codec_alaw \
    --enable codec_dahdi \
    --enable codec_g722 \
    --enable codec_g726 \
    --enable codec_gsm \
    --enable codec_ilbc \
    --enable codec_lpc10 \
    --enable codec_opus \
    --enable codec_resample \
    --enable codec_silk \
    --enable codec_speex \
    --enable codec_ulaw \
    # --- Enable Audio Formats  ---
    --enable format_g719 \
    --enable format_g723 \
    --enable format_g726 \
    --enable format_gsm \
    --enable format_h263 \
    --enable format_h264 \
    --enable format_ilbc \
    --enable format_mp3 \
    --enable format_ogg_speex \
    --enable format_ogg_vorbis \
    --enable format_pcm \
    --enable format_sln \
    --enable format_wav \
    --enable format_wav_gsm \
    # --- Enable Encryption ---
    --enable ENABLE_SRTP_AES_192 \
    --enable ENABLE_SRTP_AES_256 \
    --enable ENABLE_SRTP_AES_GCM \
    # --- Core Sounds (English) ---
    --enable CORE-SOUNDS-EN-WAV \
    --enable CORE-SOUNDS-EN-ULAW \
    --enable CORE-SOUNDS-EN-ALAW \
    --enable CORE-SOUNDS-EN-G722 \
    --enable CORE-SOUNDS-EN-SLN16 \
    # --- Core Sounds (French) ---
    --enable CORE-SOUNDS-FR-WAV \
    --enable CORE-SOUNDS-FR-ULAW \
    --enable CORE-SOUNDS-FR-ALAW \
    --enable CORE-SOUNDS-FR-GSM \
    --enable CORE-SOUNDS-FR-G722 \
    --enable CORE-SOUNDS-FR-SLN16 \
    # --- Music On Hold ---
    --enable MOH-OPSOUND-WAV \
    --enable MOH-OPSOUND-ULAW \
    --enable MOH-OPSOUND-ALAW \
    --enable MOH-OPSOUND-G722 \
    --enable MOH-OPSOUND-SLN16 \
    # --- Extra Sounds (English) ---
    --enable EXTRA-SOUNDS-EN-WAV \
    --enable EXTRA-SOUNDS-EN-ULAW \
    --enable EXTRA-SOUNDS-EN-ALAW \
    --enable EXTRA-SOUNDS-EN-GSM \
    --enable EXTRA-SOUNDS-EN-G722 \
    --enable EXTRA-SOUNDS-EN-SLN16 \
    # --- Extra Sounds (French) ---
    --enable EXTRA-SOUNDS-FR-WAV \
    --enable EXTRA-SOUNDS-FR-ULAW \
    --enable EXTRA-SOUNDS-FR-ALAW \
    --enable EXTRA-SOUNDS-FR-GSM \
    --enable EXTRA-SOUNDS-FR-G722 \
    --enable EXTRA-SOUNDS-FR-SLN16 \
    menuselect.makeopts

RUN make

RUN make install DESTDIR=/tmp/asterisk
RUN make samples DESTDIR=/tmp/asterisk
# RUN make config DESTDIR=/tmp/asterisk

RUN strip /tmp/asterisk/usr/sbin/asterisk && \
    strip /tmp/asterisk/usr/lib/asterisk/modules/*.so

RUN mkdir -p /tmp/asterisk/var/lib/asterisk/configs/samples && \
    cp -a /tmp/asterisk/etc/asterisk/* /tmp/asterisk/var/lib/asterisk/configs/samples/


RUN rm -rf /tmp/asterisk/var/run



# ---------------------------------------------------------------------------- Stage 2
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libncurses5 \
    libssl3 \
    libxml2 \
    libsqlite3-0 \
    libuuid1 \
    libjansson4 \
    libedit2 \
    libxslt1.1 \
    liburiparser1 \
    libcurl4 \
    libpq5 \
    libsrtp2-1 \
    unixodbc \
    curl \
    iputils-ping \
    net-tools \
    ssmtp \
    # --- AUDIO/CODEC RUNTIME LIBS ---
    libspeex1 \
    libspeexdsp1 \
    libopus0 \
    libvorbis0a \
    libvorbisenc2 \
    libogg0 \
    libgsm1 \
    libmp3lame0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/lib/asterisk /var/log/asterisk /var/run/asterisk /var/spool/asterisk /etc/asterisk /usr/lib/asterisk/modules /usr/share/alsa

COPY --from=build /tmp/asterisk /

RUN ldconfig

EXPOSE 5060/udp 5060/tcp 10000-20000/udp

CMD ["/usr/sbin/asterisk", "-f", "-vvv"]


# build with : docker build -t bytebrigand/asterisk:22.7.0 .
# push to repo : docker push bytebrigand/asterisk:22.7.0
# docker image prune
# docker builder prune
# docker builder prune --all --force