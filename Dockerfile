# vim:set ft=dockerfile:
FROM centos:7
MAINTAINER Wu Ping <wuping@hotmail.com>

LABEL LAST_MODIFIED=20200225

# runtime dependencies
RUN yum -y clean all && yum makecache fast && yum -y update \
 && yum -y install \
           epel-release \
           http://www.city-fan.org/ftp/contrib/yum-repo/city-fan.org-release-2-1.rhel7.noarch.rpm \
 && yum -y update \
           https://github.com/ncwuping/marathon-lb/raw/master/curl/curl-7.65.3-4.0.cf.rhel7.x86_64.rpm \
           https://github.com/ncwuping/marathon-lb/raw/master/curl/libcurl-7.65.3-4.0.cf.rhel7.x86_64.rpm \
 && yum -y install --enablerepo="city-fan*" \
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

ENV HAPROXY_MAJOR=2.0 \
    HAPROXY_VERSION=2.0.13 \
    HAPROXY_MD5=fc1bab5f63ff1f057ec3e86b8447e69e \
    MARATHON_LB_VERSION=1.14.2 \
    RUN_IT_VERSION=2.1.2 \
    LUA_MAJOR=5.3 \
    LUA_VERSION=5.3.5

RUN set -x \
 && curl -k -L -R -o marathon-lb-$MARATHON_LB_VERSION.tar.gz https://github.com/mesosphere/marathon-lb/archive/v$MARATHON_LB_VERSION.tar.gz \
 && tar zxf marathon-lb-$MARATHON_LB_VERSION.tar.gz \
 && rm -f marathon-lb-$MARATHON_LB_VERSION.tar.gz \
 && mv -f marathon-lb-$MARATHON_LB_VERSION marathon-lb \
 && rm -rf marathon-lb/{.coveragerc,.dockerignore,.gitignore,Dockerfile,build.bash,hooks,requirements-dev.txt,scripts,tests} \
 && curl -k -L -R -o marathon-lb/run https://github.com/ncwuping/marathon-lb/raw/master/run \
 && devTools=' \
     autoconf \
     automake \
     bison \
     byacc \
     cscope \
     ctags \
     diffstat \
     doxygen \
     elfutils \
     flex \
     gcc \
     gcc-c++ \
     gcc-gfortran \
     gettext \
     git \
     indent \
     intltool \
     libtool \
     patch \
     patchutils \
     rcs \
     redhat-rpm-config \
     rpm-build \
     rpm-sign \
     subversion \
     swig \
     systemtap \
 ' \
 && buildDeps=' \
     glibc-static \
     keyutils-libs-devel \
     krb5-devel \
     libcom_err-devel \
     libkadm5 \
     libselinux-devel \
     libsepol-devel \
     libverto-devel \
     ncurses-devel \
     openssl-devel \
     pcre-devel \
     pcre-static \
     python-rpm-macros \
     python-srpm-macros \
     python3-rpm-macros \
     python36 \
     python36-setuptools \
     python36-libs \
     python36-devel \
     readline-devel \
     zlib-devel \
 ' \
 && yum -y install \
           $devTools \
           $buildDeps \
           https://github.com/ncwuping/marathon-lb/raw/master/curl/libcurl-devel-7.65.3-4.0.cf.rhel7.x86_64.rpm \
 && yum clean all \
 && rm -rf /tmp/* \
 && curl -L -R -O http://smarden.org/runit/runit-$RUN_IT_VERSION.tar.gz \
 && tar zxf runit-$RUN_IT_VERSION.tar.gz -C /usr/src --strip-components=1 \
 && rm -rf runit-$RUN_IT_VERSION.tar.gz \
 && cd /usr/src/runit-$RUN_IT_VERSION \
 && package/install \
 && cd - \
 && curl -L -R -O http://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz \
 && tar zxf lua-$LUA_VERSION.tar.gz -C /usr/src \
 && rm -f lua-$LUA_VERSION.tar.gz \
 && sed -e 's!^INSTALL_TOP=\(.*\)!INSTALL_TOP=/usr!g' \
        -e 's!^INSTALL_INC=\(.*\)!INSTALL_INC=\1/lua5.3!g' \
        -e 's!^INSTALL_LIB=\(.*/lib\)!INSTALL_LIB=\164!g' \
        -e 's!^INSTALL_MAN=\(.*\)\(/man/man1\)!INSTALL_MAN=\1/doc\2!g' \
        -e 's!^INSTALL_CMOD=\(.*/lib\)!INSTALL_CMOD=\164!g' \
        -e 's!^TO_LIB=\(.*\)!TO_LIB=\1 liblua.so!g' \
        -i /usr/src/lua-$LUA_VERSION/Makefile \
 && sed -e 's!^CFLAGS=\(.*\)!CFLAGS=\1 -fPIC!g' \
        -e '/^LUA_A=/a\LUA_SO= liblua.so' \
        -e 's!^ALL_T=\(.*\)!ALL_T=\1 $(LUA_SO)!g' \
        -i /usr/src/lua-$LUA_VERSION/src/Makefile \
 && { \
      echo '#!/usr/bin/env bash'; \
      echo ''; \
      echo 'sed -i '"'"'/^$(LUA_A)/{n;n;n;/.*/a\$(LUA_SO): $(CORE_O) $(LIB_O)\n\t$(CC) -o $@ -shared $? -ldl -lm\n'; \
      echo '}'"'"' /usr/src/lua-5.3.5/src/Makefile'; \
    } > /tmp/chgluamak.sh \
 && chmod +x /tmp/chgluamak.sh \
 && /tmp/chgluamak.sh \
 && rm -f /tmp/chgluamak.sh \
 && make linux -C /usr/src/lua-$LUA_VERSION \
 && make install -C /usr/src/lua-$LUA_VERSION \
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
 && make uninstall -C /usr/src/lua-$LUA_VERSION \
 && cp -f /usr/src/lua-$LUA_VERSION/src/liblua.so /usr/lib64/ \
 && make clean -C /usr/src/lua-$LUA_VERSION \
 && rm -rf /usr/src/lua-$LUA_VERSION \
 && yum -y autoremove libcurl-devel $buildDeps $devTools \
# Purge of python3-dev will delete python3 also
 && yum -y install python36 sysvinit-tools

WORKDIR /marathon-lb

ENTRYPOINT [ "tini", "-g", "--", "/marathon-lb/run" ]
CMD [ "sse", "--health-check", "--group", "external" ]

EXPOSE 80 443 9090 9091
