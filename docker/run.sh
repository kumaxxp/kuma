docker run --rm -it \
  --runtime nvidia --network host --ipc=host \
  --name jetracer-jp62 \
  --device /dev/video0 --device /dev/video1 \
  --device /dev/i2c-1 \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $PWD/notebooks:/workspace/notebooks \
  -v $PWD/data:/workspace/data \
  -p 8888:8888 \
  jetracer62:latest
