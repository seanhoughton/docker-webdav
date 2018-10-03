FROM alpine:3.7

ENV NGINX_VERSION 1.15.4
ENV WEBDAV_EXT_SHA 430fd774fe838a04f1a5defbf1dd571d42300cf9
ENV LDAP_AUTH_SHA 42d195d7a7575ebab1c369ad3fc5d78dc2c2669c

RUN CONFIG="\
	--prefix=/etc/nginx \
	--sbin-path=/usr/sbin/nginx \
	--modules-path=/usr/lib/nginx/modules \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--pid-path=/var/run/nginx.pid \
	--lock-path=/var/run/nginx.lock \
	--http-client-body-temp-path=/var/cache/nginx/client_temp \
	--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
	--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
	--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
	--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
	--user=nginx \
	--group=nginx \
	--with-http_ssl_module \
	--with-http_realip_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_mp4_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_random_index_module \
	--with-http_secure_link_module \
	--with-http_stub_status_module \
	--with-http_auth_request_module \
	--with-http_xslt_module=dynamic \
	--with-http_image_filter_module=dynamic \
	--with-http_geoip_module=dynamic \
	--with-threads \
	--with-stream \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \
	--with-stream_realip_module \
	--with-stream_geoip_module=dynamic \
	--with-http_slice_module \
	--with-mail \
	--with-mail_ssl_module \
	--with-compat \
	--with-file-aio \
	--with-http_v2_module \
	--add-module=/usr/src/nginx-dav-ext-module \
	--add-module=/usr/src/nginx-auth-ldap \
	" \
	&& addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
	curl \
	expat-dev \
	gcc \
	gd-dev \
	geoip-dev \
	gettext \
	gnupg \
	libc-dev \
	libxslt-dev \
	linux-headers \
	make \
	openldap-dev \
	libressl-dev \
	pcre-dev \
	zlib-dev \
	&& curl -fSsL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& curl -fSsL https://codeload.github.com/arut/nginx-dav-ext-module/zip/$WEBDAV_EXT_SHA -o /usr/src/nginx-dav-ext-module.zip \
	&& cd /usr/src \
	&& unzip /usr/src/nginx-dav-ext-module.zip \
	&& mv /usr/src/nginx-dav-ext-module-$WEBDAV_EXT_SHA /usr/src/nginx-dav-ext-module \
	&& rm /usr/src/nginx-dav-ext-module.zip \
	&& curl -fSsL https://github.com/kvspb/nginx-auth-ldap/archive/${LDAP_AUTH_SHA}.zip -o /usr/src/nginx-auth-ldap.zip \
	&& cd /usr/src \
	&& unzip /usr/src/nginx-auth-ldap.zip \
	&& rm nginx-auth-ldap.zip \
	&& mv /usr/src/nginx-auth-ldap-${LDAP_AUTH_SHA} /usr/src/nginx-auth-ldap \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& ./configure $CONFIG --with-debug \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mv objs/nginx objs/nginx-debug \
	&& mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
	&& mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
	&& mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
	&& mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
	&& install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	&& rm -rf /usr/src/nginx-dav-ext-module \
	&& rm -rf /usr/src/nginx-auth-ldap \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
	scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
	| tr ',' '\n' \
	| sort -u \
	| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# Bring in tzdata so users could set the timezones through the environment
	# variables
	&& apk add --no-cache tzdata \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log


# Only add htpasswd from the apache2-utils package.
RUN apk add --no-cache --virtual .htpasswd apache2-utils \
	&& mv /usr/bin/htpasswd /tmp/ \
	&& apk del .htpasswd \
	&& mv /tmp/htpasswd /usr/bin/ \
	&& apk add --no-cache apr apr-util

RUN apk --no-cache add \
	tini

ENV WORKER_USERNAME=nginx

RUN mkdir -p /data /tmp/uploads /log

COPY docker-entrypoint.sh /
COPY nginx.conf.templ /etc/nginx/nginx.conf.templ
COPY nginx.*.conf.templ /etc/nginx/conf.d/

STOPSIGNAL SIGTERM

VOLUME ["/data", "/tmp/uploads", "/log"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx"]

ARG VERSION=unknown
RUN echo "$VERSION" > /version.txt
