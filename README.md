# split chapters

チャプター情報が付与された動画ファイルを、チャプターごとに別の動画へエンコードするようなバッチファイルを標準出力に出力するスクリプトです

## 必要なもの
- WSL
  - ffprove
  - ruby 3.0以降
- Windows
  - ffmpeg  

## 使い方

``` shell
$ ./split_chapters {{path to source video file}} > /mnt/d/encode.bat
```
``` dos
D:\> encode.bat
```

## FAQ
### どうしてLinux(WSL)だけで全て完結するようにしなかったんですか？

ffmpegでのエンコードはWindows上でネイティブに動かしたほうが当然速いだろうと思ったからです
