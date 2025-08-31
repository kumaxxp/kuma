#ARGS=""
#for d in /dev/i2c-* /dev/gpiochip*; do [ -e "$d" ] && ARGS="$ARGS --device $d"; done

ARGS=""
# I2C
for d in /dev/i2c-*; do [ -e "$d" ] && ARGS="$ARGS --device $d"; done
# GPU/EGL に必要
for d in /dev/nvhost-ctrl /dev/nvhost-ctrl-gpu /dev/nvhost-prof-gpu \
         /dev/nvhost-gpu /dev/nvhost-as-gpu /dev/nvmap; do
  [ -e "$d" ] && ARGS="$ARGS --device $d"
done
# DRM（EGL が裏で触ることがある）
for d in /dev/dri/card* /dev/dri/renderD*; do
  [ -e "$d" ] && ARGS="$ARGS --device $d"
done

docker run --rm -it \
  --privileged \
  --runtime nvidia --network host --ipc=host \
  --name jetracer-jp62 \
  $ARGS \
  --device /dev/video0 --device /dev/video1 \
  --device /dev/i2c-1 \
  -v /tmp/argus_socket:/tmp/argus_socket \
  --group-add $(getent group i2c | cut -d: -f3) \
  --group-add $(getent group gpio | cut -d: -f3) \
  --group-add $(getent group input | cut -d: -f3) \
  --group-add $(getent group video | cut -d: -f3) \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /home/kuma/Public/fabo/jetracer/notebooks:/workspace/notebooks:rw \
  -v "$PWD/data":/workspace/data \
  -p 8888:8888 \
  jetracer62:latest

