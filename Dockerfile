FROM alpine:3.8 as base_image

FROM base_image AS build

RUN apk add --no-cache \
	build-base \
	curl \
	expat-dev \
	ffmpeg \
	ffmpeg-dev \
	libxslt-dev \
	linux-headers \
	geoip-dev \
	gd-dev \
	openssl \
	openssl-dev \
	pcre-dev \
	zlib-dev

RUN mkdir nginx nginx-vts-module

ENV NGINX_VERSION 1.16.0
ENV VTS_MODULE_VERSION v0.1.18
ENV WEBDAV_EXT_SHA 430fd774fe838a04f1a5defbf1dd571d42300cf9

RUN curl -fSsL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -C nginx --strip 1 -xz

RUN curl -fSsL https://github.com/vozlt/nginx-module-vts/archive/${VTS_MODULE_VERSION}.tar.gz  | tar -C nginx-vts-module --strip 1 -xz

RUN curl -fSsL https://codeload.github.com/arut/nginx-dav-ext-module/zip/$WEBDAV_EXT_SHA -o /nginx-dav-ext-module.zip \
	&& unzip -q /nginx-dav-ext-module.zip \
	&& rm /nginx-dav-ext-module.zip

WORKDIR /nginx
RUN ./configure \
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
	--add-module=../nginx-vts-module \
	--add-module=../nginx-dav-ext-module-$WEBDAV_EXT_SHA \
	--with-threads \
	--with-stream_ssl_preread_module \
	--with-stream_ssl_module \
	--with-stream_realip_module \
	--with-stream \
	--with-mail_ssl_module \
	--with-mail \
	--with-http_v2_module \
	--with-http_sub_module \
	--with-http_ssl_module \
	--with-http_slice_module \
	--with-http_realip_module \
	--with-http_gzip_static_module \
	--with-http_auth_request_module \
	--with-http_addition_module \
	--with-file-aio \
	--with-compat \
	--with-http_xslt_module=dynamic \
	--with-http_sub_module \
	--with-http_stub_status_module \
	--with-http_ssl_module \
	--with-http_secure_link_module \
	--with-http_realip_module \
	--with-http_random_index_module \
	--with-http_mp4_module \
	--with-http_image_filter_module=dynamic \
	--with-http_gzip_static_module \
	--with-http_gunzip_module \
	--with-http_geoip_module=dynamic \
	--with-http_flv_module \
	--with-http_dav_module \
	--with-http_auth_request_module \
	--with-http_addition_module \
	--with-cc-opt="-O3"
RUN make
RUN make install

FROM base_image
RUN apk add --no-cache \
	ca-certificates \
	gettext \
	openssl \
	pcre \
	tini \
	tzdata

# Only add htpasswd from the apache2-utils package.
RUN apk add --no-cache --virtual .htpasswd apache2-utils \
	&& mv /usr/bin/htpasswd /tmp/ \
	&& apk del .htpasswd \
	&& mv /tmp/htpasswd /usr/bin/ \
	&& apk add --no-cache apr apr-util

RUN addgroup -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

COPY docker-entrypoint.sh /

COPY --from=build /usr/sbin/nginx /usr/sbin/nginx
COPY --from=build /etc/nginx /etc/nginx

RUN rm -rf /etc/nginx/*.default
COPY nginx.conf.templ /etc/nginx/nginx.conf.templ
COPY nginx.*.conf.templ /etc/nginx/conf.d/

RUN mkdir -p /cache /log /etc/certs.d /var/log/nginx

ENV WORKER_USERNAME=nginx

RUN mkdir -p /data /tmp/uploads /log

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/data", "/tmp/uploads", "/log"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["/sbin/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["nginx"]

ARG VERSION=unknown
RUN echo "$VERSION" > /version.txt
