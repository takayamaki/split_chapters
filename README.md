# split chapters

チャプター情報が付与された動画ファイルを、チャプターごとに別の動画へエンコードするようなバッチファイルを標準出力に出力するスクリプトです

## 必要なもの
- WSL
  - ffprobe
  - ruby 3.0以降
- Windows
  - ffmpeg
  - ffprobe（crf で作った出力のビットレート確認に使う）

## 使い方

``` shell
$ ./split_chapters {{path to source video file}} > /mnt/d/encode.bat
```
``` dos
D:\> encode.bat
```

## エンコードの流れ

チャプターごとに bat 内の `:encode` サブルーチンを呼び、次の順で処理する

1. **pass 1 (crf 18)** — x264 の pass 1 を crf で走らせ、末尾の `kb/s:` 行から映像ビットレートを取る。stats ファイルは 2pass 用にそのまま残す
2. probe が `PROBETHR`（7800 kbps）以下なら **crf 18 単発**でエンコードし、ffprobe で見たコンテナビットレートが `LIMIT`（8320 kbps）以下ならそれを採用
3. probe が `PROBETHR` を超えた場合、または crf の結果が `LIMIT` を超えた場合は、1 の stats を使って **pass 2 (abr 8192k)** を走らせる

x264 の pass 1 は rate control 方式に関わらず fast-firstpass で走るため、crf の pass 1 で書いた stats は abr の pass 2 にそのまま使える。
判定を外して crf → pass 2 と落ちても pass 1 + crf + pass 2 で、従来の「crf → 超過なら 2pass」と同じコストにしかならない。

閾値などは bat 冒頭の tunables（`CRF` / `LIMIT` / `ABRBV` / `CRFCAP` / `PROBETHR`）で変えられる。

## エンコードオプション（VJ 用）

- `-force_key_frames "expr:gte(t,n_forced)"` — 1 秒ごとに I フレームを打つ（VJ ソフトでのシーク・頭出し用）
- `-x264-params ref=4:bframes=2:b-pyramid=none:level=5.1` — 順方向再生前提の固定値
- `-profile:v high -pix_fmt yuv420p`
- `-fps_mode cfr -r <rate>` — CFR 化。レートは生成時に ffprobe で見て決める
  - `r_frame_rate` と `avg_frame_rate` が 1% 以内で一致していれば `r_frame_rate` をそのまま使う（元を尊重）
  - それ以上ズレる VFR 素材は `avg_frame_rate` に最も近い標準レート（23.976 / 24 / 25 / 29.97 / 30 / 50 / 59.94 / 60）に丸める
  - `avg_frame_rate` が取れない場合は `r_frame_rate` を使う

## FAQ
### どうしてLinux(WSL)だけで全て完結するようにしなかったんですか？

ffmpegでのエンコードはWindows上でネイティブに動かしたほうが当然速いだろうと思ったからです
