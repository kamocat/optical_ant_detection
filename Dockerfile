FROM alpine:3.21

WORKDIR /app

COPY . .

RUN apk add --no-cache --virtual .build-deps \
        build-base \
        cmake \
        pkgconf \
        opencv-dev \
        yaml-cpp-dev \
    && cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)" \
    && cp build/count_ants /usr/local/bin/count_ants \
    && apk add --no-cache \
        curl \
        libstdc++ \
        opencv \
        yaml-cpp \
    && apk del .build-deps \
    && rm -rf build /root/.cache /var/cache/apk/*

RUN chmod +x /app/capture

CMD ["/app/capture"]