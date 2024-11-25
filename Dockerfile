
FROM ghcr.io/r-hub/r-musl-libs AS build

USER root
WORKDIR /root

RUN curl -LO https://cran.r-project.org/src/base/R-4/R-4.4.2.tar.gz
RUN tar xzf R-4.4.2.tar.gz

RUN if [ "`arch`" = "x86_64" ]; then \
      curl -LO https://github.com/r-hub/r-musl/releases/download/0.0.1/patchelf-0.18.0-r99.apk; \
      apk add --allow-untrusted patchelf-*.apk; \
      rm patchelf-*.apk; \
      mkdir -p /opt/R/4.4.2-static/lib/R/bin/; \
      cp /usr/bin/patchelf /opt/R/4.4.2-static/lib/R/bin/; \
      mkdir -p /root/R-4.4.2/bin; \
      cp /usr/bin/patchelf /root/R-4.4.2/bin; \
    fi

COPY R-4.4.2.patch /root/
COPY Makevars /root/.R/
RUN apk add patch
RUN cd R-4.4.2 && patch -p1 < ../R-4.4.2.patch && \
    cp src/modules/lapack/Lapack.c src/main/Lapack.c && \
    cp src/modules/lapack/Lapack.h src/main/Lapack.h

# x86_64 needs to link to libquadmath
RUN cd R-4.4.2 && \
    export PATH=/opt/r-lib/bin:$PATH && \
    if [ "`arch`" = "x86_64" ]; then QUAD="/usr/lib/libquadmath.a"; fi && \
    ./configure --with-internal-tzcode --prefix=/opt/R/4.4.2-static --with-x=no \
      --disable-openmp --with-blas=/opt/r-lib/lib/libopenblas.a --with-lapack \
      --with-static-cairo --with-included-gettext \
      CPPFLAGS=-I/opt/r-lib/include \
      LDFLAGS=-L/opt/r-lib/lib \
      BLAS_HOME='/opt/r-lib/lib/libopenblas.a' FLIBS="/usr/lib/libgfortran.a $QUAD" \
      PKG_CONFIG_PATH=/opt/r-lib/lib/pkgconfig

RUN cd R-4.4.2 && make
RUN cd R-4.4.2 && make install

RUN mkdir -p /opt/R/4.4.2-static/lib/R/lib/ && \
    cp /opt/r-lib/lib/libopenblas.a /opt/R/4.4.2-static/lib/R/lib/ && \
    cp /usr/lib/libgfortran.a /opt/R/4.4.2-static/lib/R/lib/ && \
    cp /usr/lib/libquadmath.a /opt/R/4.4.2-static/lib/R/lib/ || true
RUN makeconf="/opt/R/4.4.2-static/lib/R/etc/Makeconf"; \
    sed -i 's|/opt/r-lib/lib/libopenblas.a|$(R_HOME)/lib/libopenblas.a|g' \
      "${makeconf}" && \
    sed -i 's|/usr/lib/libgfortran.a|$(R_HOME)/lib/libgfortran.a|g' \
      "${makeconf}" && \
    sed -i 's|/usr/lib/libquadmath.a|$(R_HOME)/lib/libquadmath.a|g' \
      "${makeconf}"

RUN makeconf="/opt/R/4.4.2-static/lib/R/etc/Makeconf" && \
    sed -i -E '/^CFLAGS ?=/ s/$/ -D__MUSL__ -static-libgcc -static/' "${makeconf}" && \
    sed -i -E '/^C[0-9][0-9]FLAGS ?=/ s/$/ -D__MUSL__ -static-libgcc -static/' "${makeconf}" && \
    sed -i -E '/^SHLIB_LIBADD ?=/ s|$| -static-libgcc -static-libstdc++ /usr/lib/libstdc++.a /usr/lib/libc.a -static|' "${makeconf}" && \
    sed -i -E '/^CXXFLAGS ?=/ s/$/ -D__MUSL__ -static-libgcc -static-libstdc++ -static/' "${makeconf}" && \
    sed -i -E '/^CXX[0-9][0-9]FLAGS ?=/ s/$/ -D__MUSL__ -static-libgcc -static-libstdc++ -static/' "${makeconf}" && \
    rm -rf ~/.R/

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
    'download.file("https://example.com", tmp <- tempfile()); readLines(tmp)'

# test that we only link to musl
# TODO: this does not work...
RUN apk add patchelf
RUN DEPS="`find /opt/R/4.4.2-static/ -executable -type f | while read; do echo $REPLY:; patchelf 2>/dev/null --print-needed $REPLY | sed 's/\(.*\)/  \1/'; done`" && \
    echo "$DEPS" && \
    if [ "`echo \"$DEPS\" | grep \"^ \" | grep -v libc.musl | wc -l`" = "0" ]; \
      then true; \
    else \
      false; \
    fi

FROM alpine:3.19 AS final
COPY --from=build /opt/R/4.4.2-static /opt/R/4.4.2-static

USER root
WORKDIR /root

RUN mkdir -p /root/.R
COPY Makevars /root/.R/

ENV TZ=UTC

# Some of this info is shown on the GH packages pages
LABEL org.opencontainers.image.source="https://github.com/r-hub/r-musl"
LABEL org.opencontainers.image.description="Self-contained R build for Alpine Linux"
LABEL org.opencontainers.image.authors="https://github.com/gaborcsardi"
