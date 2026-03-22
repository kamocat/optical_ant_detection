# optical_ant_detection

Counts ants in motion between two JPEG frames captured from an IP camera.
Outputs the raw ant count (or `-1` if the image is too blurry to process).

## How it works

Each run takes two images captured a few seconds apart and applies:

1. **Crop** — extracts the region of interest defined in `config.yaml`
2. **Blur filter** — discards the frame pair if the first image is out of focus
3. **Motion filter** — Gaussian blur + per-channel absolute difference + triangle threshold
4. **Color filter** — burn blend, brightness threshold, dilation, convex-hull mask
5. **Contour filter** — logical AND of the two masks, count contours in the configured area range

## Configuration

All tunable parameters live in `config.yaml`:

```yaml
crop:
  x: 600           # left edge of ROI
  y: 600           # top edge of ROI
  width: 1150
  height: 250

motion_filter:
  gaussian_kernel: 3
  gaussian_sigma: 0   # 0 = auto-calculated from kernel size
  intensity_threshold: 50

color_filter:
  color_threshold: 70
  dilate_kernel: 3
  dilate_iterations: 1
  contour_area_max: 30

contour_filter:
  area_min: 6
  area_max: 30

blur_filter:
  variance_threshold: 35

classify:
  some_ants_threshold: 1
  many_ants_threshold: 4
```

---

## Local build (for development / tuning)

### Dependencies

| Package | Notes |
|---|---|
| CMake ≥ 3.16 | build system |
| C++17 compiler | gcc or clang |
| OpenCV ≥ 4 | modules: `core`, `imgproc`, `imgcodecs` |
| yaml-cpp | any recent version |

On Debian/Ubuntu:
```sh
sudo apt install cmake build-essential libopencv-dev libyaml-cpp-dev
```

On Alpine:
```sh
apk add build-base cmake pkgconf opencv-dev yaml-cpp-dev
```

### Build

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

The binary is placed at `build/count_ants`.

### Run

```sh
./build/count_ants A.jpg B.jpg
```

#### Verbose mode

Pass `-v` to save intermediate images after every tunable step, useful when
adjusting `config.yaml`:

```sh
./build/count_ants -v A.jpg B.jpg
```

Output files written to the current directory:

| File | Stage |
|---|---|
| `verbose_crop_a.jpg` | cropped first image |
| `verbose_crop_b.jpg` | cropped second image |
| `verbose_laplacian.jpg` | normalised Laplacian used for blur detection |
| `verbose_motion.jpg` | binary motion diff mask |
| `verbose_color.jpg` | color-based candidate mask |
| `verbose_contours.jpg` | combined mask with matched ant contours in red |

`blur variance` is also printed to stderr so you can tune `variance_threshold`
without guessing.

### Antcam script

`cantcam` fetches two frames from the camera and calls the binary:

```sh
./antcam
```

It tries `./build/count_ants` first (local build), falling back to
`count_ants` on `PATH` (Docker / system install).

---

## Docker build (production)

The Docker image compiles a **fully static** binary from OpenCV and yaml-cpp
sources, then copies only the binary + config into a minimal Alpine runtime.
The final image contains no OpenCV shared libraries.

### Build the image

```sh
docker build -t optical-ant-detection:alpine .
```

> First build takes ~10–15 minutes because OpenCV is compiled from source.
> Subsequent builds reuse the Docker layer cache for the OpenCV and yaml-cpp
> stages as long as `OPENCV_VERSION` / `YAML_VERSION` are unchanged.

#### Build ARGs

| ARG | Default | Description |
|---|---|---|
| `OPENCV_VERSION` | `4.10.0` | OpenCV source tag to build |
| `YAML_VERSION` | `0.8.0` | yaml-cpp source tag to build |

Override with `--build-arg`:
```sh
docker build --build-arg OPENCV_VERSION=4.11.0 -t optical-ant-detection:alpine .
```

### Run

The container runs `capture` on startup, which fetches frames from the camera
URL hardcoded in the script and prints the ant count to stdout.

```sh
docker run --rm optical-ant-detection:alpine
```

To override the camera URL at runtime, bind-mount a modified `capture` or
`config.yaml`:

```sh
docker run --rm \
  -v "$(pwd)/antcam:/app/cantcam" \
  -v "$(pwd)/config.yaml:/app/config.yaml" \
  optical-ant-detection:alpine
```

### Verify static linking

```sh
docker run --rm --entrypoint /bin/sh optical-ant-detection:alpine \
  -c "ldd /usr/local/bin/count_ants || true"
# expected: "Not a valid dynamic program"
```

---

## systemd integration

`antcam.service` + `antcam.timer` run `antcam` on a schedule.

```sh
sudo cp antcam.service antcam.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now antcam.timer
```
