FROM alpine:3.21 AS builder

WORKDIR /src

RUN apk add --no-cache \
        build-base \
        cmake \
        pkgconf \
        opencv-dev \
        yaml-cpp-dev

COPY . .

RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)"

FROM alpine:3.21 AS runtime

WORKDIR /app

RUN apk add --no-cache \
        curl \
        libstdc++ \
        libopencv_core \
        libopencv_imgcodecs \
        libopencv_imgproc \
        yaml-cpp

COPY --from=builder /src/build/count_ants /usr/local/bin/count_ants
COPY --from=builder /src/config.yaml /app/config.yaml
COPY --from=builder /src/capture /app/capture

RUN chmod +x /app/capture

CMD ["/app/capture"]