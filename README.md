# ARLISS2022_simulator
ARLISS2022 Dolphinsチームで使用する強化学習手法を検討するためのシミュレータです。

# 開発環境
Processing 3.5.4 (<a href="https://processing.org/download">ダウンロード</a>)
※動作のために**Java8**を導入する必要があります。なければインストールしましょう(<a href="https://www.oracle.com/java/technologies/downloads/#java8">ダウンロード</a>)。Java18とかじゃないので注意！

# 開発言語
Processing(Javaベース言語)
基本的な書き方はJavaと同じ(というか中身はJava)ですが、c言語やPythonみたいに1行〜のコードでも動くのが特徴です。
簡単に言うと超簡単に書けるようにしたJavaって感じです！普通に楽しいので<a href="https://p5codeschool.net/">チュートリアル</a>を見て遊んでみよう！

# 実行の仕方
0. **初めに下記のライブラリ導入をしましょう！**
1. Processingをインストールし開く
2. ARLISS2022_simulator.pdeを開く
3. 左上の▷ボタンで実行

## Processingに強化学習ライブラリ導入
0. https://drive.google.com/drive/folders/1Xo17VE_zV6Hraf-tmE5FO4qUiTDC_YCU?usp=sharing からjarファイルを全て落としてくる
1. ライブラリをProcessingが読み込むように配置する。macなら `~/Document(書類)/Processing/libraries/chen0040rlearning/library` とフォルダを作ってその中に落としてきたjarファイル全部入れる。winでも多分同じ
2. Processingを開いて `スケッチ > ライブラリをインポート` の中に `chen0040rlearning` という名前があれば成功
　
