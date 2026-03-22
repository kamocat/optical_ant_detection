FROM alpine:3.21 AS builder

WORKDIR /work

RUN apk add --no-cache \
        build-base \
        cmake \
        pkgconf \
        linux-headers \
        zlib-dev \
        zlib-static \
        libjpeg-turbo-dev \
        libjpeg-turbo-static \
        libpng-dev \
        libpng-static

ARG OPENCV_VERSION=4.10.0
RUN wget -qO- "https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.tar.gz" | tar xz

RUN cmake -S "opencv-${OPENCV_VERSION}" -B /work/opencv-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_LIST=core,imgproc,imgcodecs \
        -DBUILD_JPEG=ON \
        -DBUILD_PNG=ON \
        -DBUILD_ZLIB=ON \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_JAVA=OFF \
        -DBUILD_opencv_apps=OFF \
        -DWITH_QT=OFF \
        -DWITH_GTK=OFF \
        -DWITH_FFMPEG=OFF \
        -DWITH_GSTREAMER=OFF \
        -DWITH_V4L=OFF \
        -DWITH_OPENCL=OFF \
        -DWITH_OPENMP=OFF \
        -DWITH_TBB=OFF \
        -DWITH_IPP=OFF \
        -DWITH_WEBP=OFF \
        -DWITH_TIFF=OFF \
        -DWITH_OPENEXR=OFF \
        -DWITH_1394=OFF \
        -DWITH_ADE=OFF \
        -DWITH_PROTOBUF=OFF \
        -DBUILD_PROTOBUF=OFF \
        -DCPU_DISPATCH="" \
    && cmake --build /work/opencv-build -j"$(nproc)"

ARG YAML_VERSION=0.8.0
RUN wget -qO- "https://github.com/jbeder/yaml-cpp/archive/refs/tags/${YAML_VERSION}.tar.gz" | tar xz

RUN cmake -S "yaml-cpp-${YAML_VERSION}" -B /work/yaml-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/yaml-cpp \
        -DBUILD_SHARED_LIBS=OFF \
        -DYAML_CPP_BUILD_TESTS=OFF \
        -DYAML_CPP_BUILD_TOOLS=OFF \
    && cmake --build /work/yaml-build -j"$(nproc)" \
    && cmake --install /work/yaml-build

COPY . /src

RUN cmake -S /src -B /src/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DOpenCV_DIR=/work/opencv-build \
        -Dyaml-cpp_DIR=/opt/yaml-cpp/lib/cmake/yaml-cpp \
        -DCMAKE_EXE_LINKER_FLAGS="-static -static-libgcc -static-libstdc++" \
    && cmake --build /src/build -j"$(nproc)" \
    && strip --strip-all /src/build/count_ants

FROM alpine:3.21 AS runtime

WORKDIR /app

RUN apk add --no-cache curl

COPY --from=builder /src/build/count_ants /usr/local/bin/count_ants
COPY --from=builder /src/config.yaml /app/config.yaml
COPY --from=builder /src/antcam /app/antcam

RUN chmod +x /app/antcam

CMD ["/app/antcam"]