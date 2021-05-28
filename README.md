# キー入力の時間差を計測する (Windows)

## KeyTimingChecker.exe

実行して開かれるメモ帳でキーを押すと、キーの名前と時間差が出力されます。

誤操作を防ぐため、開いたメモ帳以外でキー入力すると即終了します。

できるだけ多くのキーに対応しました。(104英語キーボード、109日本語キーボードドライバ使用時)

![画面サンプル](画面サンプル.png)

## 仕様

* キーボードドライバを通じてキーの上げ下げを取得し、同時に表示もしているので時間差にはぶれがあります。

* 同時押しで名前が変わるキーがあります。

例：Alt+PrintScreen、Ctrl+Pause

* スリープ系のキーには対応しません。また、ドライバが認識できない機能キーには対応できません。

例：PC-9801キーボードドライバ使用時は、(Mac)英数、(Mac)かな、右Alt、F13〜F24を認識しません。

* 次のキーを押すのは勧めません。

1. Win+L

* 一度に大量のキーを押すと、動作不良を起こすことがあります。

## 動作確認

* Windows 10 Home version 20H2 + AutoHotkey (v1.1.33.08)
