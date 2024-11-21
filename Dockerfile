
FROM ghcr.io/r-hub/r-musl-libs AS build

USER root
WORKDIR /root
COPY Makevars /root/.R/Makevars

RUN curl -LO https://cran.r-project.org/src/base/R-4/R-4.4.2.tar.gz
RUN tar xzf R-4.4.2.tar.gz

COPY R-4.4.2.patch /root/
RUN apk add patch
RUN cd R-4.4.2 && patch -p1 < ../R-4.4.2.patch && \
    cp src/modules/lapack/Lapack.c src/main/Lapack.c && \
    cp src/modules/lapack/Lapack.h src/main/Lapack.h

# x86_64 needs to link to libquadmath
RUN cd R-4.4.2 && \
    if [ "`arch`" = "x86_64" ]; then QUAD="/usr/lib/libquadmath.a"; fi && \
    ./configure --with-internal-tzcode --prefix=/opt/R/4.4.2-static \
      --with-x=no --disable-openmp --with-blas=/usr/local/lib/libopenblas.a \
      --with-lapack --with-static-cairo --with-included-gettext \
      FLIBS="$QUAD /usr/lib/libgfortran.a" \
      BLAS_LIBS="$QUAD /usr/lib/libgfortran.a /usr/local/lib/libopenblas.a"

RUN cd R-4.4.2 && make
RUN apk add patchelf
RUN cd R-4.4.2 && \
    patchelf --remove-needed libgcc_s.so.1 src/modules/lapack/lapack.so && \
    patchelf --remove-needed libgcc_s.so.1 src/main/R.bin
RUN cd R-4.4.2 && make install

# patch to embed CA certs
RUN curl -L https://curl.se/ca/cacert.pem -o /opt/R/4.4.2-static/lib/R/share/curl-ca-bundle.crt
RUN echo "CURL_CA_BUNDLE=${CURL_CA_BUNDLE-/opt/R/4.4.2-static/lib/R/share/curl-ca-bundle.crt}" \
    >> /opt/R/4.4.2-static/lib/R/etc/Renviron

# strip
RUN for f in `find /opt/R/4.4.2-static/ -executable -type f `; do strip -x "$f" || true; done

# test that BLAS/LAPACK are OK
RUN /opt/R/4.4.2-static/bin/R -q -e 'La_library()'

# test HTTPS
RUN /opt/R/4.4.2-static/bin/R -q -e \
    'download.file("https://httpbin.org/headers", tmp <- tempfile()); readLines(tmp)'

# test that we only link to musl
# TODO: this does not work...
RUN DEPS="`find /opt/R/4.4.2-static/ -executable -type f | while read; do echo $REPLY:; patchelf 2>/dev/null --print-needed $REPLY | sed 's/\(.*\)/  \1/'; done`" && \
    echo "$DEPS" && \
    if [ "`echo \"$DEPS\" | grep \"^ \" | grep -v libc.musl-aarch64.so.1 | wc -l`" = "0" ]; \
      then true; \
    else \
      false; \
    fi

FROM alpine:3.19 AS final
COPY --from=build /opt/R/4.4.2-static /opt/R/4.4.2-static

USER root
WORKDIR /root

RUN mkdir -p /root/.R
COPY Makevars /root/.R/Makevars

ENV TZ=UTC

# Some of this info is shown on the GH packages pages
LABEL org.opencontainers.image.source="https://github.com/r-hub/r-musl"
LABEL org.opencontainers.image.description="Self-contained R build for Alpine Linux"
LABEL org.opencontainers.image.authors="https://github.com/gaborcsardi"
