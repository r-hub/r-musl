
FROM ghcr.io/r-lib/pak-libs-aarch64:latest AS libs
FROM alpine:3.19 AS build

COPY --from=libs /usr/local /usr/local

USER root
WORKDIR /root

RUN mkdir -p /root/.R
COPY Makevars /root/.R/Makevars

RUN apk add curl gcc musl-dev gfortran g++ ncurses-dev \
    bash pkgconf pcre2-dev make perl

RUN curl -LO https://cran.r-project.org/src/base/R-4/R-4.4.2.tar.gz
RUN tar xzf R-4.4.2.tar.gz

RUN curl -LO https://github.com/tukaani-project/xz/releases/download/v5.6.3/xz-5.6.3.tar.gz
RUN tar xzf xz-5.6.3.tar.gz
RUN cd xz-5.6.3 && \
    ./configure --enable-static --enable-shared=no \
        --disable-dependency-tracking && \
    make && \
    make install

RUN curl -LO https://invisible-island.net/datafiles/current/ncurses.tar.gz
RUN tar xzf ncurses.tar.gz
RUN cd ncurses-* && \
    ./configure --prefix=/usr/local && \
    make && \
    make install

RUN curl -LO https://ftp.gnu.org/gnu/readline/readline-8.2.13.tar.gz
RUN tar xzf readline-8.2.13.tar.gz
RUN cd readline-8.2.13 && \
    ./configure --enable-static --enable-shared=no && \
    make && \
    make install

RUN curl -LO https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.44/pcre2-10.44.tar.gz
RUN tar xzf pcre2-10.44.tar.gz
RUN cd pcre2-10.44 && \
    ./configure --enable-static --enable-shared=no && \
    make && \
    make install

RUN curl -LO https://www.sourceware.org/pub/bzip2/bzip2-latest.tar.gz
RUN tar xzf bzip2-latest.tar.gz
RUN cd bzip2-1.0.8 && \
    make && \
    make install PREFIX=/usr/local

RUN curl -LO https://github.com/OpenMathLib/OpenBLAS/releases/download/v0.3.28/OpenBLAS-0.3.28.tar.gz
RUN tar xzf OpenBLAS-0.3.28.tar.gz
RUN cd OpenBLAS-0.3.28 && \
    NO_SHARED=1 make && \
    NO_SHARED=1 make PREFIX=/usr/local/ install

RUN apk add icu-static icu-dev
RUN rm /usr/lib/libicu*so*

RUN apk add libpng-dev libpng-static
RUN rm /usr/lib/libpng*so*

RUN apk add libjpeg-turbo-static libjpeg-turbo-dev
RUN rm /usr/lib/libjpeg*so*

RUN apk add libdeflate-dev libdeflate-static
RUN rm /usr/lib/libdeflate*so*

RUN curl -LO https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz
RUN tar xzf tiff-4.7.0.tar.gz
RUN cd tiff-4.7.0 && \
    ./configure --enable-static --enable-shared=no && \
    make && \
    make install

RUN apk add openjdk21-jdk

COPY R-4.4.2.patch /root/
RUN apk add patch
RUN cd R-4.4.2 && patch -p1 < ../R-4.4.2.patch && \
    cp src/modules/lapack/Lapack.c src/main/Lapack.c && \
    cp src/modules/lapack/Lapack.h src/main/Lapack.h

RUN cd R-4.4.2 && \
    FLIBS='/usr/lib/libgfortran.a -lm -lssp_nonshared' \
    BLAS_LIBS='/usr/lib/libgfortran.a /usr/local/lib/libopenblas.a' \
    ./configure --with-internal-tzcode --prefix=/opt/R/4.4.2-static \
    --with-x=no --disable-openmp --with-blas=/usr/local/lib/libopenblas.a \
    --with-lapack

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

# test that BLAS/LAPACK are OK
RUN /opt/R/4.4.2-static/bin/R -q -e 'La_library()'

# test HTTPS
RUN /opt/R/4.4.2-static/bin/R -q -e \
    'download.file("https://httpbin.org/headers", tmp <- tempfile()); readLines(tmp)'

# test that we only link to musl
RUN DEPS="`find /opt/R/4.4.2-static/ -executable -type f | while read; do echo $REPLY:; patchelf 2>/dev/null --print-needed $REPLY | sed 's/\(.*\)/  \1/'; done`" && \
    echo "$DEPS" && \
    if [ "`echo \"$DEPS\" | grep \"^ \" | grep -v libc.musl-aarch64.so.1 | wc -l`" = "0" ]; \
      then echo ok; \
    fi

FROM alpine:3.19 AS final
COPY --from=build /opt/R/4.4.2-static /opt/R/4.4.2-static

USER root
WORKDIR /root

ENV TZ=UTC
