# -*- coding: utf-8 -*-

module Rhythm
  module About
    NAME = 'Rhythm'
    LICENSE = 'MIT License'
    AUTHOR = 'Constellation'
    MAIL   = 'utatane.tea@gmail.com'
    DEVELOPPERS = {
      'Constellation' => 'utatane.tea@gmail.com'
    }
    CONTRIBUTERS = {
    }
    VERSION = "0.0.2"
    ABOUT_E = <<-EOF
    Rhythm
      Rhythm is Ruby-based File Management Application with Prompt
      inspired from AFx, mfiler3, FD, cfiler, Recodes and so on.
      #{LICENSE}
      (c) #{AUTHOR} <#{MAIL}>
    EOF
    ABOUT_J = <<-EOF
    Rhythm
      Rhythm は Ruby-basedのファイル管理アプリケーション(通称ファイラ)です.

      FD, AFx, mfiler3, 内骨格の影響を受けつつ,
      Script言語であるRubyの特長を生かし,
      plaggableな構造になっています.

      Shellのよさも取り入れる方針であり, Promptの表示やなどの機能もあります.
      また, ファイル管理のみでなく, ファイルに対し特定の処理を行うなどのscriptを,
      Rubyで簡単に追加することができるという特徴があります.

      もともとLinux環境上のAFx代替を目指して作られたものなので,
      Cygwinで動くことは確認しましたが, Win32環境のサポートは考慮していません.
      AFxWを使ってください.
      また, AFxW並の行為をLinux上で行えるという目標を掲げるため,
      他のLinuxのファイラーとは少し異なる部分が強化されています.
      (RAR書庫やISO, ZIPといったWin32環境でメジャーな書庫の
      仮想ディレクトリ化機能や, 画像の表示管理, MP3 Titleタグ表示など)

      そのいっぽうで, Linux環境における開発に適した機能も強化されています
      (GitのbranchのPrompt表示, screen連携, pagerによる閲覧など)

      256色表示対応やUNICODE対応などもありますが,
      基本的には私個人の趣向を反映したものになっています.

      そして, キー定義はVimファンの自身の欲望に忠実に,
      Vim Likeなキーバインドとなっています. Emacs派はあしからず.
      設定はできますが, Emacsはほとんど知らないので,
      sample key定義かいてくれる方募集しています.

      #{LICENSE}
      (c) #{AUTHOR} <#{MAIL}>
    EOF
    TECHNICA = <<-EOF
    Delimiter:
      画面描画Library
      もとは汎用でしたが, 速度が遅かったのでRhythm用に改定して高速化.
      256色表示可能などの機能.
      ja_JP.UTF-8のambiguous対応
    Libunrar:
      RAR Archiveヘッダ読み取りLibrary
      Filelistの構築用. 解凍, 圧縮はunrar or 7-zipに丸投げ
    EOF
  end
end

