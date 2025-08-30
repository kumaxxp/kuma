
# JetRacer on Jetson Orin Nano Super (JetPack 6.2.1)

Jetson Orin Nano Super + **JetPack 6.2.1 (L4T r36.4.x / CUDA 12.8)** 上で、**PyTorch/torchvision** と **I2C (PCA9685)** / **GPIO** を Docker コンテナ内から扱うための環境です。
ベースは `dustynv/pytorch` を採用し、**最小セットを段階追加**する方針で構成しています。

* ベース: `dustynv/pytorch:2.7-r36.4.0`（fallback: `dustynv/pytorch:2.6-r36.4.0-cu128`）
* 実機確認: PyTorch/torchvision, GPIO, I2C(PCA9685) 動作済み
* 既知: 主環境では **PCA9685 = `/dev/i2c-7`, 0x40** で認識

---

## 0. ホスト前提（JetPack 6.x の注意）

JetPack 6.x は **Docker が自動導入されません**。未導入なら先にセットアップしてください。

```bash
sudo apt update
sudo apt install -y nvidia-container curl
curl -s https://get.docker.com | sh
sudo systemctl --now enable docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

> 40pin の I2C/GPIO を使う場合は **Jetson-IO** で有効化 → 再起動
> `sudo /opt/nvidia/jetson-io/jetson-io.py`

---

## 1. ビルド

```bash
# プロジェクト直下にある Dockerfile をビルド
docker build -t jetracer-jp62:latest .
```

> `pip` で重い数値系を入れると壊れがちです。SciPy が必要なら **apt の `python3-scipy`** を使うなど、追加は小さく分けてください（後述）。

---

## 2. 起動

### 2-1. 初回（切り分け用：とりあえず通す）

まずは一度 **強め設定**で起動して、I2C/GPIO/入力デバイスが見えることを確認します。

```bash
HOST_NOTEBOOKS=/home/kuma/Public/fabo/jetracer/notebooks

docker run --rm -it --privileged \
  --runtime nvidia --network host --ipc=host \
  $(for d in /dev/gpiochip* /dev/i2c-* /dev/input/js* /dev/input/event*; do [ -e "$d" ] && echo --device $d; done) \
  --group-add $(getent group gpio  | cut -d: -f3) \
  --group-add $(getent group i2c   | cut -d: -f3) \
  --group-add $(getent group input | cut -d: -f3) \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$HOST_NOTEBOOKS":/workspace/notebooks:rw \
  -p 8888:8888 \
  jetracer-jp62:latest
```

ブラウザから `http://<JetsonのIP>:8888` を開くと JupyterLab にアクセスできます。

### 2-2. 以降（最小権限で運用）

PCA9685 しか使わないなら、**I2C デバイスだけ**渡す運用に切り替えます。（実機で `/dev/i2c-7` だった例）

```bash
docker run --rm -it \
  --runtime nvidia --network host --ipc=host \
  --device /dev/i2c-7 \
  --group-add $(getent group i2c | cut -d: -f3) \
  -v "$HOST_NOTEBOOKS":/workspace/notebooks:rw \
  -p 8888:8888 \
  jetracer-jp62:latest
```

必要に応じて `/dev/gpiochip*`、`/dev/input/*` を追加してください。

---

## 3. 動作確認（ノートブック / ターミナル）

### 3-1. PyTorch/torchvision

```bash
python3 - <<'PY'
import torch, torchvision
print('torch', torch.__version__, 'cuda', torch.cuda.is_available(), 'vision', torchvision.__version__)
PY
```

### 3-2. I2C（バス列挙 → スキャン）

```bash
i2cdetect -l        # 例: i2c-7 ほか
i2cdetect -y 7      # 実際のバス番号に置き換え
```

### 3-3. GPIO（libgpiod）

```bash
gpiodetect
gpioinfo | head
python3 - <<'PY'
import Jetson.GPIO as GPIO
print('Jetson.GPIO', GPIO.VERSION, GPIO.JETSON_INFO)
PY
```

### 3-4. PCA9685（FaBo ライブラリ）

> 実機では **bus=7, addr=0x40** を確認済み。違う場合は下記の `BUS/ADDR` を修正。

```bash
python3 - <<'PY'
try:
    import smbus2 as smbus
except ImportError:
    from smbus import SMBus as smbus
import Fabo_PCA9685

BUS, ADDR, INIT = 7, 0x40, 300     # ←環境に合わせて
bus = smbus.SMBus(BUS)
pca = Fabo_PCA9685.PCA9685(bus, INIT, ADDR)  # 位置引数！
pca.set_hz(50)
pca.set_channel_value(0, 330)      # CH0 を軽く動かす
print("FaBo OK")
PY
```

---

## 4. ノートブックの共有

ホストのノートブックディレクトリをコンテナの `/workspace/notebooks` にマウントしています。

```bash
-v /home/kuma/Public/fabo/jetracer/notebooks:/workspace/notebooks:rw
```

JupyterLab から `notebooks/` 以下が見えます。

---

## 5. 追加インストールの方針（小分け）

**一気に入れない**のが安定の近道です。ImportError が出たら、\*\*そのパッケージ“だけ”\*\*を追加して再ビルド。

* 入力デバイス（ゲームパッド）:

  * apt: `python3-evdev joystick`
  * run: `--device /dev/input/js0 --group-add $(getent group input | cut -d: -f3)`
* GStreamer を Python から使う場合:

  * apt: `python3-gi python3-gst-1.0`
* 数値系（どうしても必要な時だけ）:

  * **SciPy** は apt: `python3-scipy`（pip で入れない）
* シリアル:

  * pip: `pyserial`、run: `--device /dev/ttyUSB0` など

> `dustynv/pytorch` のイメージは pip の index が NVIDIA/Jetson ミラーに向くため、**一般パッケージは本家PyPI**を明示して入れるのが安全です（Dockerfile では `--index-url https://pypi.org/simple` を付けています）。

---

## 6. よくあるエラーと対処

* `No i2c-bus specified!`
  → `i2cdetect -l` でバス番号を確認し、`i2cdetect -y <bus>` の形で実行。

* `Permission denied: /dev/i2c-*`
  → `--group-add $(getent group i2c | cut -d: -f3)` を付ける。切り分けに一度 `--privileged` でも可。

* `ModuleNotFoundError: Jetson` / `This library is not supported on this board`
  → `Jetson.GPIO>=2.1.8` を入れる（JP6 対応）。`/dev/gpiochip*` をコンテナに渡す。

* `Fabo_PCA9685` の `TypeError: unexpected keyword argument 'INITIAL_VALUE'`
  → **位置引数で渡す**（`PCA9685(bus, INIT[, ADDR])`）。キーワード引数は不可。

* `i2cdetect` に 0x40 が出ない / `OSError: [Errno 121]`
  → バスやアドレス（0x40〜0x47）違い、配線/電源、Jetson-IO 設定を再確認。

---

## 7. JetRacer への展開（最小ループ）

1. **ステア/スロットルのパルス範囲**を実機でキャリブ
2. **ゲームパッド**が必要なら `python3-evdev` + `/dev/input/*` を渡す
3. **カメラ**はまず `cv2.VideoCapture` / `gst-launch-1.0` で生存確認
   （必要時のみ `python3-gi` を導入）

> JetRacer のリポは丸ごと入れず、**Notebook/スクリプトの必要部分だけ**段階的に持ち込むのが安全です。

---

## 8. メンテ

* ベースタグ更新（例：`2.7-r36.4.0` → 次の r36.x）時は、まず **pip 追加を最小**にしてビルド通し → 検証後に必要分だけ追加。
* 依存追加は **1〜2個ずつ** → スモークテスト → コミット、のリズムで。

---

## 9. ライセンス / 謝辞

* ベースイメージ: [dustynv/pytorch](https://hub.docker.com/r/dustynv/pytorch)
* FaBo PCA9685: FaBoPlatform/FaBoPWM-PCA9685-Python
* その他 OSS に感謝

---

## 付録：トラブルシュート用スクリプト（オプション）

**存在する I2C/GPIO/Input デバイスだけ**を自動で渡して起動するワンライナー。

```bash
HOST_NOTEBOOKS=/home/kuma/Public/fabo/jetracer/notebooks
ARGS=""
for d in /dev/gpiochip* /dev/i2c-* /dev/input/js* /dev/input/event*; do
  [ -e "$d" ] && ARGS="$ARGS --device $d"
done
docker run --rm -it --privileged \
  --runtime nvidia --network host --ipc=host \
  $ARGS \
  --group-add $(getent group gpio  | cut -d: -f3) \
  --group-add $(getent group i2c   | cut -d: -f3) \
  --group-add $(getent group input | cut -d: -f3) \
  -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$HOST_NOTEBOOKS":/workspace/notebooks:rw \
  -p 8888:8888 jetracer-jp62:latest
```

