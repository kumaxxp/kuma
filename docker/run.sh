ARGS=""
for d in /dev/i2c-* /dev/gpiochip*; do [ -e "$d" ] && ARGS="$ARGS --device $d"; done

docker run --rm -it \
  --privileged \
  --group-add $(getent group i2c | cut -d: -f3) \
  --group-add $(getent group gpio | cut -d: -f3) \
  --runtime nvidia --network host --ipc=host \
  --name jetracer-jp62 \
  --device /dev/video0 --device /dev/video1 \
  --device /dev/i2c-1 \
  --name jetracer-jp62 \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /home/kuma/Public/fabo/jetracer/notebooks:/workspace/notebooks:rw \
  -v $PWD/data:/workspace/data \
  -p 8888:8888 \
  jetracer62:latest
  
  
