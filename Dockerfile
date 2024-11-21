
FROM alpine:3.19 AS build

USER root
WORKDIR /root

RUN apk add linux-headers bash gcc musl-dev g++ pkgconf make

# zlib --------------------------------------------------------------------

RUN wget https://zlib.net/zlib-1.3.1.tar.gz
RUN tar xzf zlib-*.tar.gz && rm zlib-*.tar.gz
RUN cd zlib-* &&                                                     \
    CFLAGS=-fPIC ./configure --static &&                             \
    make &&                                                          \
    make install

# openssl -----------------------------------------------------------------

RUN wget https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz
RUN tar xzf openssl-*.tar.gz && rm openssl-*.tar.gz
RUN apk add perl linux-headers
RUN cd openssl-* &&                                                  \
    ./config -fPIC no-shared &&                                      \
    make &&                                                          \
    make install_sw &&                                               \
    rm -rf /usr/local/bin/openssl                                    \
       /usr/local/share/{man/doc}

# libcurl now -------------------------------------------------------------

RUN wget https://curl.haxx.se/download/curl-8.11.0.tar.gz
RUN tar xzf curl-*.tar.gz && rm curl-*.tar.gz
RUN apk add pkgconfig
RUN cd curl-* && \
    ./configure --enable-static --disable-shared --with-openssl      \
                --without-libpsl;				     \
    make &&                                                          \
    make install &&                                                  \
    rm -rf /usr/local/bin/curl                                       \
       /usr/local/share/{man/doc}

# =========================================================================
# We don't need to keep the compilation artifacts, so copy the results
# to a clean image

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
    sed -i '/^CFLAGS=/ s/$/ -fPIC/' Makefile
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

RUN curl -LO https://download.sourceforge.net/libpng/libpng-1.6.44.tar.gz
RUN tar xf libpng-1.6.44.tar.gz
RUN cd libpng-1.6.44 && \
    CFLAGS=-fPIC ./configure --enable-static --disable-shared && \
    make && \
    make install

RUN curl -LO https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.0.4/libjpeg-turbo-3.0.4.tar.gz
RUN tar xf libjpeg-turbo-3.0.4.tar.gz
RUN apk add cmake ninja
RUN cd libjpeg-turbo-3.0.4 && \
    mkdir build && cd build && \
    CFLAGS=-fPIC cmake -B build-static -G Ninja \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_INSTALL_LIBDIR=/usr/local/lib \
      -DBUILD_SHARED_LIBS=False \
      -DENABLE_STATIC=True \
      -DCMAKE_BUILD_TYPE=None \
      -DCMAKE_SKIP_INSTALL_RPATH=ON \
      -DWITH_JPEG8=1 .. && \
    cmake --build build-static && \
    cmake --install build-static && \
    rm -f /usr/local/lib/libjpeg.so*

RUN apk add libdeflate-dev libdeflate-static
RUN rm /usr/lib/libdeflate*so*

RUN curl -LO https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz
RUN tar xzf tiff-4.7.0.tar.gz
RUN cd tiff-4.7.0 && \
    CFLAGS=-fPIC ./configure --enable-static --enable-shared=no && \
    make && \
    make install

RUN apk add openjdk21-jdk

RUN apk add cairo-static cairo-dev
RUN rm /usr/lib/libcairo*so*

RUN curl -LO https://www.kernel.org/pub/linux/utils/util-linux/v2.39/util-linux-2.39.3.tar.gz
RUN tar xf util-linux-2.39.3.tar.gz
RUN cd util-linux-2.39.3 && \
    ./configure --enable-static --disable-shared --prefix=/usr/local && \
    make && \
    make install

RUN curl -LO https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.14.2.tar.gz
RUN tar xf fontconfig-2.14.2.tar.gz
RUN apk add gperf
RUN cd fontconfig-2.14.2 && \
    CFLAGS=-fPIC ./configure --enable-static=yes --enable-shared=no && \
    make && \
    make install

RUN curl -LO https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz
RUN tar xzf libffi-3.4.4.tar.gz
RUN cd libffi-3.4.4 && \
    CFLAGS=-fPIC ./configure --enable-static=yes --enable-shared=no && \
    make && \
    make install

RUN curl -LO https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.3.tar.gz
RUN tar xf gettext-0.22.3.tar.gz
RUN cd gettext-0.22.3 && \
    CFLAGS=-fPIC ./configure --enable-static=yes --enable-shared=no \
    --enable-threads=posix --disable-java && \
    make && \
    make install 

RUN curl -LO https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.gz
RUN tar xf expat-2.6.4.tar.gz
RUN cd expat-2.6.4 && \
    CFLAGS=-fPIC ./configure --enable-static=yes --enable-shared=no && \
    make && \
    make install

RUN curl -LO https://download.gnome.org/sources/pango/1.51/pango-1.51.0.tar.xz
RUN tar xf pango-1.51.0.tar.xz
RUN apk add meson py3-jinja2 py3-markdown py3-packaging py3-pygments py3-typogrify
RUN apk add harfbuzz-static harfbuzz-dev
RUN apk add fribidi-dev fribidi-static
RUN apk add pixman-dev pixman-static
RUN apk add libxml2-dev libxml2-static
RUN apk add freetype-dev freetype-static
RUN apk add brotli-dev brotli-static
RUN apk add graphite2-dev graphite2-static
RUN apk add glib-static

RUN sed -ibak '/^Libs:/d' /usr/lib/pkgconfig/cairo.pc && \
    echo 'Libs: -L${libdir} -lcairo /usr/local/lib/libz.a /usr/local/lib/libpng.a /usr/local/lib/libpng.a /usr/lib/libfreetype.a /usr/lib/libpixman-1.a /usr/local/lib/libbz2.a /usr/lib/libbrotlicommon.a /usr/lib/libbrotlidec.a /usr/lib/libbrotlienc.a /usr/local/lib/libexpat.a' \
    >> /usr/lib/pkgconfig/cairo.pc

RUN cd pango-1.51.0 && \
    CFLAGS=-fPIC meson setup --reconfigure --buildtype release --strip --prefix /usr/local \
    --libdir /usr/local/lib --default-library static . build && \
    meson compile -C build && \
    meson install -C build

RUN sed -ibak '/^Libs:/d' /usr/local/lib/pkgconfig/pango.pc && \
    echo 'Libs: -L${libdir} -lpango-1.0 -lm /usr/lib/libgio-2.0.a /usr/lib/libglib-2.0.a /usr/lib/libgobject-2.0.a /usr/lib/libfribidi.a /usr/lib/libharfbuzz.a /usr/local/lib/libfontconfig.a /usr/lib/libfreetype.a /usr/lib/libcairo.a /usr/local/lib/libintl.a /usr/lib/libgraphite2.a /usr/local/lib/libexpat.a /usr/lib/libbrotlicommon.a /usr/lib/libbrotlidec.a /usr/lib/libbrotlienc.a' \
    >> /usr/local/lib/pkgconfig/pango.pc

RUN sed -ibak '/^Libs:/d' /usr/local/lib/pkgconfig/pangocairo.pc && \
    echo 'Libs: -L${libdir} -lpangocairo-1.0 -lm /usr/lib/libglib-2.0.a /usr/lib/libgobject-2.0.a /usr/lib/libgio-2.0.a /usr/lib/libfribidi.a /usr/lib/libharfbuzz.a /usr/local/lib/libfontconfig.a /usr/lib/libfreetype.a /usr/lib/libcairo.a' \
    >> /usr/local/lib/pkgconfig/pangocairo.pc

RUN sed -ibak '/^Libs:/d' /usr/local/lib/pkgconfig/pangoft2.pc && \
    echo 'Libs: -L${libdir} -lpangoft2-1.0 -lm /usr/lib/libglib-2.0.a /usr/lib/libgobject-2.0.a /usr/lib/libgio-2.0.a /usr/local/lib/libffi.a /usr/lib/libfribidi.a /usr/lib/libharfbuzz.a /usr/local/lib/libfontconfig.a /usr/lib/libfreetype.a /usr/lib/libcairo.a' >> \
    /usr/local/lib/pkgconfig/pangoft2.pc

# On x86_64 we need libgfortran compiled with -fPIC
RUN if [ "`arch`" = "x86_64" ]; then \
      curl -LO  https://github.com/r-hub/r-musl/releases/download/0.0.1/gfortran-13.2.1_git20231014-r0.apk; \
      apk add --allow-untrusted gfortran-13.2.1_git20231014-r0.apk; \
    fi

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
      then echo ok; \
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
