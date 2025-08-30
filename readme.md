# 目的

* **Jetson Orin Nano Super + JetPack 6.2.1（L4T r36.4.x / CUDA 12.8）**で**JetRacer**を動かす。
* **PyTorch/torchvision は dustynv ベースで稼働済み**。Notebook からの I2C/GPIO も動作確認済み。

# 採用ベース & 重要方針

* ベース: `dustynv/pytorch:2.7-r36.4.0`（fallback: `2.6-r36.4.0(-cu128)`）
* **pip の index が Jetsonミラーに向く** → 重いもの（SciPy等）は **apt**、一般PyPIパッケージは `--index-url https://pypi.org/simple` 明示で最小導入。
* **DeepStream/旧PyTorch wheel/virtualenv大量pinは混ぜない**（世代不一致で壊れる）。
* 追加は**小さく分割（Batch A/B/C/D…）→毎回スモークテスト**。

# 現行 Dockerfile（抜粋 / 差分の中核）

```dockerfile
FROM dustynv/pytorch:2.7-r36.4.0
ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Tokyo \
    PIP_DISABLE_PIP_VERSION_CHECK=1 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 FORCE_COLOR=1

# 必須: I2C/カメラ/GUI最低限 + gpiod + OpenCV(apt)
RUN apt-get update && apt-get install -y --no-install-recommends \
  python3-dev build-essential git cmake pkg-config \
  libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev \
  libgtk-3-dev libcanberra-gtk3-module libv4l-dev v4l-utils \
  gstreamer1.0-tools gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
  libgl1-mesa-glx libglib2.0-0 \
  i2c-tools python3-smbus python3-opencv \
  gpiod libgpiod2 python3-libgpiod sudo curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# pip は本家PyPIから最小だけ
RUN python3 -m pip install --no-cache-dir --index-url https://pypi.org/simple \
  "Jetson.GPIO>=2.1.8" adafruit-circuitpython-pca9685 adafruit-blinka

# FaBo PCA9685（Notebookが import Fabo_PCA9685 を要求）
RUN python3 -m pip install --no-cache-dir --index-url https://pypi.org/simple \
  "git+https://github.com/FaBoPlatform/FaBoPWM-PCA9685-Python@master#egg=Fabo_PCA9685"

WORKDIR /workspace

# 非rootユーザ（UID/GID=1000想定）
ARG USERNAME=jetson UID=1000 GID=1000
RUN groupadd -g ${GID} ${USERNAME} && useradd -m -s /bin/bash -u ${UID} -g ${GID} ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USERNAME}
USER ${USERNAME}

EXPOSE 8888
CMD ["bash","-lc","jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --NotebookApp.token='' --NotebookApp.password='' --allow-root"]
```

# 既知の論点と解決

* **scipy の pip 失敗**: ベースの pip index が NVIDIA 側を向くため。→ **削除** or 本当に要る時だけ `apt-get install python3-scipy`。
* **GPIO**: JP6 は **libgpiod** 前提。→ `gpiod/python3-libgpiod/Jetson.GPIO>=2.1.8` を入れる＋ `/dev/gpiochip*` を渡す。
* **I2C**: `/dev/i2c-*` を `--device` で渡し、`i2c` グループを `--group-add`。Bus 番号は `i2cdetect -l` で確認（有力: `1`, 次点 `9`）。

# 起動テンプレ（まずは切り分け → その後絞る）

```bash
# 共有ノートブック
HOST_NOTEBOOKS=/home/kuma/Public/fabo/jetracer/notebooks

# まずは通す（切り分け）。通ったら --privileged を外し、--device を最小化。
docker run --rm -it --privileged \
  --runtime nvidia --network host --ipc=host \
  $(for d in /dev/gpiochip* /dev/i2c-* /dev/input/js* /dev/input/event*; do [ -e "$d" ] && echo --device $d; done) \
  --group-add $(getent group gpio  | cut -d: -f3) \
  --group-add $(getent group i2c   | cut -d: -f3) \
  --group-add $(getent group input | cut -d: -f3) \
  -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY \
  -v "$HOST_NOTEBOOKS":/workspace/notebooks:rw \
  -p 8888:8888 yourimage:latest
```

# スモークテスト（Notebook/ターミナル）

```bash
# CUDA/torch/vision
python3 - <<'PY'
import torch, torchvision; print(torch.__version__, torch.cuda.is_available(), torchvision.__version__)
PY

# I2C
i2cdetect -l
i2cdetect -y 1     # 見つかったバスに合わせる

# GPIO
gpiodetect; gpioinfo | head
python3 - <<'PY'
import Jetson.GPIO as GPIO; print(GPIO.VERSION, GPIO.JETSON_INFO)
PY
```

# PCA9685 動作チェック

```python
# FaBo
import Fabo_PCA9685, pkg_resources
import smbus2 as smbus   # or from smbus import SMBus
bus = smbus.SMBus(1)     # 見つかったバスに合わせる
pca = Fabo_PCA9685.PCA9685(bus, INITIAL_VALUE=300)
pca.set_hz(50); pca.set_channel_value(0, 330); print("FaBo OK")

# 代替: Adafruit
from adafruit_pca9685 import PCA9685
from board import SCL, SDA
# Jetsonでは blinka 経由の I2C バス取得に追加設定が必要な場合あり。FaBoが通るならまずはFaBo継続でOK。
```

# Batch 計画（状態）

* **Batch A（入力/ユーティリティ）**: `python3-evdev`/`joystick`/`pyyaml`/`simple-pid`/`tqdm`/`pyserial` など → **導入候補**（必要が出たら入れる）。
* **Batch B（GStreamer Python）**: `python3-gi`/`python3-gst-1.0` → **ノートが Gst を使うなら追加**。
* **Batch C（JetRacer最小移植）**: リポは必要部だけ持込（丸ごと導入は最後）。
* **Batch D（FaBo PCA9685）**: **導入済み（上記 pip git+ URL）**。

# 旧Dockerfileから“持ち込まない”もの

* DeepStream 6.2 一式、torch/vision の手動 wheel、巨大 virtualenv/pin、GCC9固定/CMakeビルド、torch2trt、TF2.12、DonkeyCar… → **今は不採用**（世代不一致/肥大化/壊れやすい）。

# 次の一手

1. 現行イメージで **Notebook実行→I2C(0x40)・GPIO・カメラ・推論**を再確認。
2. Notebookが要求する欠品が出たら、**1〜2個ずつ**（Batch A/B/Cの方針で）Dockerfileに追記→再ビルド。
3. `--privileged` を外し、実際に使う **`--device` と `--group-add` を最小化**。

