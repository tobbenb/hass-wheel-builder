FROM lsiobase/alpine:3.12

# set version label
ARG BUILD_DATE
ARG VERSION
ARG HASS_RELEASE
ARG HACS_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="saarg"

# environment settings
ENV HOME="/tmp"

# install packages
RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	autoconf \
    bluez-deprecated \
	ca-certificates \
 	cmake \
    curl \
    cython \
	eudev-dev \
    eudev-libs \
    ffmpeg \
	ffmpeg-dev \
    gcc \
	glib-dev \
    g++ \
	jq \
    libffi-dev \
    libjpeg-turbo \
	libjpeg-turbo-dev \
    libstdc++ \
	libxml2-dev \
    libxslt \
	libxslt-dev \
    make \
    openssl \
	openssl-dev \
    py3-pip \
	py3-wheel \
    python3 \
    python3-dev \
	sudo \
	unzip

RUN \
 echo "**** find packages to build for homeassistant ****" && \
 mkdir -p \
 		/tmp/core && \
  if [ -z ${HASS_RELEASE+x} ]; then \
	HASS_RELEASE=$(curl -sX GET https://api.github.com/repos/home-assistant/core/releases/latest \
	| jq -r .tag_name); \
 fi && \
 curl -o \
 /tmp/core.tar.gz -L \
		"https://github.com/home-assistant/core/archive/${HASS_RELEASE}.tar.gz" && \
 tar xf \
 /tmp/core.tar.gz -C \
		/tmp/core --strip-components=1

RUN \
 echo "**** make folders for building wheels and upgrade pip ****" && \
 mkdir -p \
		/build/addons \
		/build/core && \
 pip3 install --no-cache-dir --upgrade \
        pip

RUN \
 echo "**** build wheels for home assistant core ****" && \
 awk '/# Home Assistant core/,/^$/' /tmp/core/requirements_all.txt > /tmp/requirements_hass.txt && \
 awk '/# homeassistant.components.trend/,/^$/' /tmp/core/requirements_all.txt >> /tmp/requirements_hass.txt && \
 pip3 wheel --wheel-dir=/build/core --no-cache-dir \
		-r /tmp/requirements_hass.txt

RUN \
 echo "**** build wheels for home assistant addons ****" && \
 sed -i "s/-r requirements_test.txt/-r \/tmp\/core\/requirements_test.txt/g" /tmp/core/requirements_test_all.txt && \
 sed -i "s/-r requirements_test_pre_commit.txt/-r \/tmp\/core\/requirements_test_pre_commit.txt/g" /tmp/core/requirements_test.txt && \
 pip3 wheel --wheel-dir /build/addons --no-cache-dir --find-links=/build/core \
		-r /tmp/core/requirements_test_all.txt

RUN \
 echo "**** install dependencies for hacs.xyz ****" && \
 if [ -z ${HACS_RELEASE+x} ]; then \
	HACS_RELEASE=$(curl -sX GET "https://api.github.com/repos/hacs/integration/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && \
 mkdir -p \
		/build/hacs \
		/tmp/hacs-source && \
 curl -o \
 	/tmp/hacs.tar.gz -L \
		"https://github.com/hacs/integration/archive/${HACS_RELEASE}.tar.gz" && \
 tar xf \
	/tmp/hacs.tar.gz -C \
		/tmp/hacs-source --strip-components=1 && \
 pip3 wheel --wheel-dir=/build/hacs --no-cache-dir --find-links=/build/core --find-links=/build/addons \
		-r /tmp/hacs-source/requirements.txt

RUN \
 mkdir -p \
		/tmp/repo && \
 mv /build/addons/* /tmp/repo/ && \
 mv /build/core/* /tmp/repo/ && \
 mv /build/hacs/* /tmp/repo/ && \
 tar zcf /tmp/wheel-repo-x86_64.tar.gz /tmp/repo

CMD ["cp", "-avr", "/tmp/wheel-repo-x86_64.tar.gz", "/mnt/"]