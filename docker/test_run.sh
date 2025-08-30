docker run --rm -it \
  --runtime nvidia --network host --ipc=host \
  --name jetracer-jp62 \
  --device /dev/i2c-1 \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /home/kuma/Public/fabo/jetracer/notebooks:/workspace/notebooks:rw \
  -v $PWD/data:/workspace/data \
  -p 8888:8888 \
  132fdd133060


