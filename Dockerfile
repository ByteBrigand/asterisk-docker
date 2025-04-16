# Stage 1:
FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV ASTERISK_VERSION=22.3.0

WORKDIR /usr/src


RUN apt update && apt upgrade -y

RUN apt install -y \
    build-essential \
    wget \
    subversion \
    libncurses5-dev \
    libssl-dev \
    libxml2-dev \
    libsqlite3-dev \
    uuid-dev \
    libjansson-dev \
    pkg-config \
    libedit-dev

RUN (wget -6 http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz || \
     wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz) && \
    (wget -6 http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.md5 || \
     wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.md5) && \
    md5sum -c asterisk-${ASTERISK_VERSION}.md5
RUN tar zxvf asterisk-${ASTERISK_VERSION}.tar.gz && \
    rm asterisk-${ASTERISK_VERSION}.tar.gz


WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}

COPY menuselect.makeopts .
COPY menuselect.makedeps .

RUN ./contrib/scripts/install_prereq install
RUN ./configure --with-pjproject-bundled
RUN ./contrib/scripts/install_prereq install-unpackaged
RUN ./contrib/scripts/get_mp3_source.sh
RUN make
RUN make install
RUN make samples
RUN make config
RUN make install-logrotate

# Stage 2
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV ASTERISK_VERSION=22.3.0

RUN apt update && apt upgrade -y
RUN apt autoremove -y
RUN apt clean
RUN rm -rf /var/lib/apt/lists/*


RUN groupadd --system asterisk
RUN useradd --system --no-create-home --gid asterisk asterisk

RUN mkdir -p /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk

COPY --from=build /usr/lib /usr/lib
COPY --from=build /usr/sbin /usr/sbin
COPY --from=build /var /var
COPY --from=build /etc/asterisk /etc/asterisk

RUN chown -R asterisk:asterisk /var/lib/asterisk
RUN chown -R asterisk:asterisk /var/log/asterisk
RUN chown -R asterisk:asterisk /var/spool/asterisk
RUN chown -R asterisk:asterisk /etc/asterisk

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER asterisk

EXPOSE 5060/udp 5060/tcp 10000-20000/udp

ENTRYPOINT ["/entrypoint.sh"]

# build with : docker build -t bytebrigand/asterisk:22.3.0 .
# push to repo : docker push bytebrigand/asterisk:22.3.0
