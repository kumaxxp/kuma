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

# gpiodツール & Pythonバインディング
RUN apt-get update && apt-get install -y --no-install-recommends \
      gpiod libgpiod2 python3-libgpiod \
    && rm -rf /var/lib/apt/lists/*

# Jetson.GPIO（JP6対応版を明示。Orin Nano/Superは 2.1.8+ が安全）
RUN python3 -m pip install --no-cache-dir \
      --index-url https://pypi.org/simple \
      "Jetson.GPIO>=2.1.8"

# controls / utils（前の提案どおり） batch A
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-evdev joystick htop tree vim git wget unzip \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --index-url https://pypi.org/simple \
      simple-pid pyyaml tqdm pyserial

# GStreamer Python bindings（cv2だけなら不要） batch B
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-gi python3-gst-1.0 \
    && rm -rf /var/lib/apt/lists/*

# Adafruit/Jetson系は導入済みを前提（未導入ならここに追記） batch C
# RUN python3 -m pip install --no-cache-dir --index-url https://pypi.org/simple \
#       adafruit-circuitpython-pca9685 adafruit-blinka Jetson.GPIO>=2.1.8

# JetRacer リポを入れる場合（とりあえず notebooks だけ持ってくる）
# "FaBoPlatform/jetracer" を想定（必要に合わせて repo/branch を差し替え）
RUN git clone https://github.com/FaBoPlatform/jetracer /opt/jetracer || true
# 必要なnotebook/スクリプトだけコピー（全部は入れない）
# 例:
# RUN mkdir -p /workspace/notebooks/jetracer && \
#     cp -r /opt/jetracer/notebooks/* /workspace/notebooks/jetracer/

# --- Batch D: FaBo PCA9685 (import Fabo_PCA9685 を有効化)
# 依存の smbus/smbus2 は既に入っている前提（入ってなければ python3-smbus をaptで）
RUN python3 -m pip install --no-cache-dir \
      --index-url https://pypi.org/simple \
      "git+https://github.com/FaBoPlatform/FaBoPWM-PCA9685-Python@master#egg=Fabo_PCA9685"

# --- Batch E: plotting (matplotlib)
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-matplotlib \
      fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# --- Batch F: jupyter_clickable_image_widget (Python側)
# まずは Python パッケージのみ導入（最小）。フロント側は後述のFallback参照。
RUN python3 -m pip install --no-cache-dir --index-url https://pypi.org/simple \
  "git+https://github.com/jaybdub/jupyter_clickable_image_widget@master#egg=jupyter_clickable_image_widget"

# --- Batch H: ipyevents (ClickableImageWidget 互換実装用)
RUN python3 -m pip install --no-cache-dir --index-url https://pypi.org/simple ipyevents

# --- JetCam と CSI 用の最小依存（OpenCVはaptを使う） ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-opencv \
    python3-numpy \
    v4l-utils \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    python3-gi python3-gst-1.0 \
    git && \
    rm -rf /var/lib/apt/lists/*

# pip は本家PyPIを使うが、★numpyは入れない/更新しない★
ENV PIP_INDEX_URL=https://pypi.org/simple
RUN python3 -m pip install --no-cache-dir -U pip traitlets

# JetCam はソースから。OpenCV/NumPy はaptで満たしているので --no-deps
RUN git clone --depth 1 https://github.com/NVIDIA-AI-IOT/jetcam.git /opt/jetcam && \
    cd /opt/jetcam && \
    python3 -m pip install --no-deps -e .

# --- model caches to /data (writeable)
ENV TORCH_HOME=/data/torch \
    XDG_CACHE_HOME=/data/.cache \
    HF_HOME=/data/huggingface

# ★ ここが修正ポイント：ユーザー作成前でも通るように UID/GID で chown する
ARG UID=1000
ARG GID=1000
RUN mkdir -p /data/torch/hub/checkpoints /data/.cache /data/huggingface \
 && chown -R ${UID}:${GID} /data

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
