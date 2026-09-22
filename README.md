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

```
Usage: split_chapters [OPTION]... FILE...
Write a Windows batch file to standard output that encodes each chapter of
FILE(s) into a separate mp4 (x264 crf 18, or 2-pass abr 8192k when crf 18
would exceed 8 Mbps).

  -h, --help            display this help and exit
  --min-duration SECS   write chapters shorter than SECS as @rem (default 60; 0 = none)
  --max-duration SECS   write chapters longer than SECS as @rem (default none)
```

``` shell
$ ./split_chapters disc1.mkv disc2.mkv > /mnt/d/encode.bat
```
``` dos
D:\> encode.bat
```

出力ファイルはソースと同じディレクトリに `<ソース名>_<連番>.mp4`。2pass 用の stats ファイル（`<ソース名>.log` / `.mbtree`）もソースと同じディレクトリに置き、bat の最後で消す（別ディレクトリの同名ソースを並行してエンコードしても取り合わない）。60 秒未満のチャプター（タイトルカード・転換）は `@rem` でコメントアウトした状態で出力する。
上限は既定では設けない。10 分超のチャプターは大半が MC だが、曲＋MC で 1 チャプターになっているものが時々あり（アンコール曲など）、飛ばすと追加エンコードと再照合の一周が要るので、MC を余分にエンコードするほうが安い。以前の挙動（600 秒超を飛ばす）にしたければ `--max-duration 600`。

複数回に分けて生成したものを `>>` で単純連結してもよい（各出力は自分の `:encode` を一意なラベルへの `goto` で飛び越えるので、続けて次の出力が実行される）:

``` shell
$ ./split_chapters disc1.mkv >  /mnt/d/encode.bat
$ ./split_chapters disc2.mkv >> /mnt/d/encode.bat
```

bat は `bin\ffmpeg.exe` / `bin\ffprobe.exe` を自分のディレクトリからの相対で参照するので、`bin\` のある場所に置いて実行する。
ffmpeg は `start /low /b /wait` で低優先度（Low）で起動する。`/b` の子プロセスは Ctrl+C を無視するので、途中で止めるときは **Ctrl+Break**。

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
