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

## FAQ
### どうしてLinux(WSL)だけで全て完結するようにしなかったんですか？

ffmpegでのエンコードはWindows上でネイティブに動かしたほうが当然速いだろうと思ったからです
