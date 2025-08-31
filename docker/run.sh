ARGS=""
# I2C（必要なら）
for d in /dev/i2c-*; do [ -e "$d" ] && ARGS="$ARGS --device $d"; done
# GPU/EGL に必要なノード
for d in /dev/nvhost-ctrl /dev/nvhost-ctrl-gpu /dev/nvhost-prof-gpu \
         /dev/nvhost-gpu /dev/nvhost-as-gpu /dev/nvhost-vic /dev/nvmap; do
  [ -e "$d" ] && ARGS="$ARGS --device $d"
done
# DRM (EGL が裏で使う)
for d in /dev/dri/card* /dev/dri/renderD*; do
  [ -e "$d" ] && ARGS="$ARGS --device $d"
done

docker run --rm -it \
  --privileged \
  --runtime nvidia --network host --ipc=host \
  -e NVIDIA_DRIVER_CAPABILITIES=all \
  -e EGL_PLATFORM=surfaceless \
  -e DISPLAY= \
  -v /tmp/argus_socket:/tmp/argus_socket \
  --group-add $(getent group i2c | cut -d: -f3) \
  --group-add $(getent group gpio | cut -d: -f3) \
  --group-add $(getent group input | cut -d: -f3) \
  --group-add $(getent group video | cut -d: -f3) \
  $ARGS \
  --device /dev/video0 --device /dev/video1 \
  --device /dev/i2c-1 \
  -v /home/kuma/Public/fabo/jetracer/notebooks:/workspace/notebooks:rw \
  -v "$PWD/data":/workspace/data \
  -p 8888:8888 \
  --name jetracer-jp62 \
  jetracer62:latest
