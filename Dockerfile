# vim:set ft=dockerfile:
FROM centos:latest
MAINTAINER Wu Ping <wuping@hotmail.com>

LABEL LAST_MODIFIED=20190415

# runtime dependencies
RUN yum -y install \
           epel-release \
 && yum -y install \
           libnghttp2 \
           http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/city-fan.org-release-2-1.rhel7.noarch.rpm \
 && yum -y update --enablerepo=city-fan.org \
 && yum -y install \
           openssl \
           which \
           rsyslog \
           socat

ENV TINI_VERSION=v0.18.0 \
    TINI_GPG_KEY=595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7

RUN set -x \
 && curl -k -L -R -o tini "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini-amd64" \
 && curl -k -L -R -o tini.asc "https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini-amd64.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$TINI_GPG_KEY" \
 || gpg --keyserver pool.sks-keyservers.net --recv-keys "$TINI_GPG_KEY" \
 || gpg --keyserver keyserver.pgp.com --recv-keys "$TINI_GPG_KEY" \
 || gpg --keyserver pgp.mit.edu --recv-keys "$TINI_GPG_KEY" \
 && gpg --batch --verify tini.asc tini \
 && rm -rf "$GNUPGHOME" tini.asc \
 && mv tini /usr/bin/tini \
 && chmod +x /usr/bin/tini \
 && tini -- true

ENV HAPROXY_MAJOR=1.8 \
    HAPROXY_VERSION=1.8.19 \
    HAPROXY_MD5=713d995d8b072a4ca8561ab389b82b7a

RUN set -x \
 && curl -k -L -R -o marathon-lb-1.12.3.tar.gz https://github.com/mesosphere/marathon-lb/archive/v1.12.3.tar.gz \
 && mkdir -p /marathon-lb \
 && tar zxf marathon-lb-1.12.3.tar.gz --directory /marathon-lb --strip-components=1 \
 && rm -f marathon-lb-1.12.3.tar.gz \
 && buildEss=' \
     apr \
     apr-util \
     avahi-libs \
     boost-date-time \
     boost-system \
     boost-thread \
     bzip2 \
     cpp \
     dwz \
     dyninst \
     efivar-libs \
     emacs-filesystem \
     file \
     fipscheck \
     fipscheck-lib \
     gdb \
     gettext-common-devel \
     gettext-libs \
     glibc-devel \
     glibc-headers \
     gnutls \
     kernel-debug-devel \
     kernel-headers \
     less \
     libcroco \
     libdwarf \
     libedit \
     libgfortran \
     libgnome-keyring \
     libgomp \
     libmodman \
     libmpc \
     libproxy \
     libquadmath \
     libstdc++-devel \
     libunistring \
     m4 \
     mokutil \
     mpfr \
     neon \
     nettle \
     openssh \
     openssh-clients \
     pakchois \
     perl-Data-Dumper \
     perl-Error \
     perl-TermReadKey \
     perl-Test-Harness \
     perl-Thread-Queue \
     perl-XML-Parser \
     perl-srpm-macros \
     rsync \
     subversion-libs \
     systemd-sysv \
     systemtap-client \
     systemtap-runtime \
     trousers \
     unzip \
     zip \
 ' \
 && buildDeps=' \
     glibc-static \
     keyutils-libs-devel \
     krb5-devel \
     libcom_err-devel \
     libcurl-devel \
     libkadm5 \
     libselinux-devel \
     libsepol-devel \
     libverto-devel \
     ncurses-devel \
     openssl-devel \
     pcre-devel \
     pcre-static \
     python36 \
     python36-setuptools \
     python36-libs \
     python36-devel \
     python-rpm-macros \
     python-srpm-macros \
     readline-devel \
     zlib-devel \
 ' \
 && yum groups mark convert \
 && yum -y groupinstall "Development Tools" \
 && yum -y install $buildDeps \
 && yum clean all \
 && rm -rf /tmp/* \
 && curl -L -R -O http://smarden.org/runit/runit-2.1.2.tar.gz \
 && tar zxf runit-2.1.2.tar.gz -C /usr/src --strip-components=1 \
 && rm -rf runit-2.1.2.tar.gz \
 && cd /usr/src/runit-2.1.2 \
 && package/install \
 && cd - \
 && curl -L -R -O http://www.lua.org/ftp/lua-5.3.5.tar.gz \
 && tar zxf lua-5.3.5.tar.gz -C /usr/src \
 && rm -f lua-5.3.5.tar.gz \
 && sed -e 's!^INSTALL_TOP=\(.*\)!INSTALL_TOP=/usr!g' \
        -e 's!^INSTALL_INC=\(.*\)!INSTALL_INC=\1/lua5.3!g' \
        -e 's!^INSTALL_LIB=\(.*/lib\)!INSTALL_LIB=\164!g' \
        -e 's!^INSTALL_MAN=\(.*\)\(/man/man1\)!INSTALL_MAN=\1/doc\2!g' \
        -e 's!^INSTALL_CMOD=\(.*/lib\)!INSTALL_CMOD=\164!g' \
        -e 's!^TO_LIB=\(.*\)!TO_LIB=\1 liblua.so!g' \
        -i /usr/src/lua-5.3.5/Makefile \
 && sed -e 's!^CFLAGS=\(.*\)!CFLAGS=\1 -fPIC!g' \
        -e '/^LUA_A=/a\LUA_SO= liblua.so' \
        -e 's!^ALL_T=\(.*\)!ALL_T=\1 $(LUA_SO)!g' \
        -i /usr/src/lua-5.3.5/src/Makefile \
 && { \
      echo '#!/usr/bin/env bash'; \
      echo ''; \
      echo 'sed -i '"'"'/^$(LUA_A)/{n;n;n;/.*/a\$(LUA_SO): $(CORE_O) $(LIB_O)\n\t$(CC) -o $@ -shared $? -ldl -lm\n'; \
      echo '}'"'"' /usr/src/lua-5.3.5/src/Makefile'; \
    } > /tmp/chgluamak.sh \
 && chmod +x /tmp/chgluamak.sh \
 && /tmp/chgluamak.sh \
 && rm -f /tmp/chgluamak.sh \
 && make linux -C /usr/src/lua-5.3.5 \
 && make install -C /usr/src/lua-5.3.5 \
 \
# Build HAProxy
 && curl -k -L -R -o haproxy.tar.gz "https://www.haproxy.org/download/$HAPROXY_MAJOR/src/haproxy-$HAPROXY_VERSION.tar.gz" \
 && echo "$HAPROXY_MD5 haproxy.tar.gz" | md5sum -c \
 && mkdir -p /usr/src/haproxy \
 && tar zxf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1 \
 && rm -f haproxy.tar.gz \
 && make -C /usr/src/haproxy \
     TARGET=linux2628 \
     ARCH=x86_64 \
     USE_LUA=1 \
     LUA_INC=/usr/include/lua5.3/ \
     USE_OPENSSL=1 \
     USE_PCRE_JIT=1 \
     USE_PCRE=1 \
     USE_REGPARM=1 \
     USE_STATIC_PCRE=1 \
     USE_ZLIB=1 \
     all \
     install-bin \
 && rm -rf /usr/src/haproxy \
 \
# Install Python dependencies
# Install Python packages with --upgrade so we get new packages even if a system
# package is already installed. Combine with --force-reinstall to ensure we get
# a local package even if the system package is up-to-date as the system package
# will probably be uninstalled with the build dependencies.
 && curl -k -L -R -O https://bootstrap.pypa.io/get-pip.py \
 && python36 get-pip.py \
 && rm -f get-pip.py \
 && export PYCURL_SSL_LIBRARY=openssl \
 && pip3 install --no-cache --upgrade --force-reinstall -r /marathon-lb/requirements.txt \
 \
 && make uninstall -C /usr/src/lua-5.3.5 \
 && cp -f /usr/src/lua-5.3.5/src/liblua.so /usr/lib64/ \
 && make clean -C /usr/src/lua-5.3.5 \
 && rm -rf /usr/src/lua-5.3.5 \
 && yum -y remove libssh2-devel \
 && yum -y remove $buildDeps \
 && yum -y groupremove "Development Tools" \
 && yum -y remove $buildEss \
# Purge of python3-dev will delete python3 also
 && yum -y install python36 sysvinit-tools

WORKDIR /marathon-lb

ENTRYPOINT [ "tini", "-g", "--", "/marathon-lb/run" ]
CMD [ "sse", "--health-check", "--group", "external" ]

EXPOSE 80 443 9090 9091
