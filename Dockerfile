FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV ASTERISK_VERSION=22.3.0

WORKDIR /usr/src

COPY asterisk-${ASTERISK_VERSION}.md5 .

RUN apt update && apt upgrade -y && \
    apt install -y build-essential wget subversion \
    libncurses5-dev libssl-dev libxml2-dev libsqlite3-dev uuid-dev \
    libjansson-dev pkg-config libedit-dev && \
    apt clean && rm -rf /var/lib/apt/lists/*

RUN wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz && \
    wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.md5 && \
    md5sum -c asterisk-${ASTERISK_VERSION}.md5 && \
    tar zxvf asterisk-${ASTERISK_VERSION}.tar.gz && \
    rm asterisk-${ASTERISK_VERSION}.tar.gz

WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}

COPY menuselect.makeopts .

RUN ./configure --with-pjproject-bundled --enable-shared && \
    ./contrib/scripts/install_prereq install-unpackaged && \
    ./contrib/scripts/get_mp3_source.sh && \
    make && \
    make install && \
    make samples && \
    make config && \
    make install-logrotate

RUN groupadd --system asterisk && \
    useradd --system --no-create-home --gid asterisk asterisk && \
    mkdir -p /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk && \
    chown -R asterisk:asterisk /var/{lib,log,spool}/asterisk /etc/asterisk


USER asterisk

COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh



EXPOSE 5060/udp 5060/tcp 10000-20000/udp

ENTRYPOINT ["/entrypoint.sh"]
