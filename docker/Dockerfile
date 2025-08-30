FROM dustynv/pytorch:2.7-r36.4.0

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FORCE_COLOR=1

# OS周り（カメラ/I2C/可視化 最小）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3-dev build-essential git cmake pkg-config \
      libjpeg-dev libpng-dev libtiff-dev \
      libavcodec-dev libavformat-dev libswscale-dev \
      libgtk-3-dev libcanberra-gtk3-module \
      libv4l-dev v4l-utils \
      gstreamer1.0-tools \
      gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
      gstreamer1.0-plugins-ugly gstreamer1.0-libav \
      libgl1-mesa-glx libglib2.0-0 \
      i2c-tools python3-smbus python3-smbus2 \
      python3-opencv \
      # SciPy が必要なら apt で（pip は使わない）
      # python3-scipy \
      sudo curl ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# pip は “必要なものだけ”。Adafruit 系は PyPI 本家から取得する
# （base イメージに jupyterlab / notebook / numpy / matplotlib 等は既に入っている）
RUN python3 -m pip install --no-cache-dir --prefer-binary \
      --index-url https://pypi.org/simple \
      adafruit-circuitpython-pca9685 adafruit-blinka

# 作業ディレクトリ
WORKDIR /workspace

# （必要ならアプリやNotebookをここにCOPY）
# COPY ./notebooks ./notebooks
# COPY ./your_app ./your_app

# 非rootユーザー
ARG USERNAME=jetson
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${USERNAME} && \
    useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USERNAME}
USER ${USERNAME}

EXPOSE 8888
CMD ["bash", "-lc", "jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --NotebookApp.token='' --NotebookApp.password='' --allow-root"]
