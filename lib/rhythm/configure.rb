# vim: fileencoding=utf-8
# configure setting

require 'fileutils'
require "rhythm/locale"

module Rhythm
  Config = {}

  # ConfigはHashの特異オブジェクトとして実装
  class << Config
    @@chars = ['UTF-8', 'SHIFT_JIS', 'EUC-JP']
    @@splitter = {
      'UTF-8' => //u,
      'EUC-JP' => //e,
      'SHIFT_JIS' => //s
    }
    def configure
      # rhythm directory
      FileUtils.mkdir_p(File.expand_path('~/.rhythm')) unless File.exist?(File.expand_path('~/.rhythm'))
      self['TEMP'] = File.expand_path("~/.rhythm/temp")
      FileUtils.mkdir_p(self['TEMP'])

      # log
      self['LOG_ENABLE'] = true
      self['LOG'] = '~/.rhythm/rhythm.log'

      # 標準LANGUAGE SYSTEM
      # SHIFT_JIS, EUC-JP, UTF-8を想定(KCODE由来)
      # 内部表現はUTF8で固定
      # Ruby1.8ではこれで限界 => 1.9ならEncodingにより効率的にできる
      $KCODE = 'u'
      self['LANG'] = ENV['LANG']
      self['LOCALE'], self['CHARMAP'] = self['LANG'].split('.')
      unless @@chars.include?(self['CHARMAP'])
        self['LANG'] = 'ja_JP.UTF-8'
        self['LOCALE'] = 'ja_JP'
        self['CHARMAP'] = 'UTF-8'
      end
      self['SPLITTER'] = @@splitter[self['CHARMAP']]
      Locale.setlocale2 self['LANG']
      # ambiguous chars width
      # ambiguousはdefaultencodingがutf-8の時にしか問題にならない
      self['AMBIGUOUS'] = true
      #self['AMBIGUOUS'] = false

      self['PATHES'] = ENV["PATH"].split(':')

      # screen検知
      screen_configure

      # size単位をhuman readableにするか?
      self['HUMAN_READABLE'] = false
      # size単位を3桁区切りするか?(HUMAN_READABLE実行時は無効)
      self['SIZE_CURRENCY'] = false

      # migemo設定
      self['MIGEMO'] = true
      self['MIGEMO_STATIC_DICT'] = '~/.rhythm/migemo/migemo-dict'
      self['MIGEMO_DICT_CACHE'] = '~/.rhythm/migemo/migemo-dict.cache'

      # search設定
      self['SEARCH_FORWARD'] = false
      self['ISEARCH'] = true
      # 最終項まで検索した後最上位に戻るかどうか
      self['WRAP_SCAN'] = true

      # PAGER default は less
      self['PAGER'] = ENV['PAGER'] || Sys.which('less')
      # EDITOR default は vim
      self['EDITOR'] = ENV['EDITOR'] || Sys.which('vim')

      # FileList
      self['LEFT_SORT_MODE'] = :extension
      self['LEFT_SORT_ORDER'] = true
      self['LEFT_MASK_MODE'] = :all
      # self['LEFT_START_PATH'] = '~'
      self['RIGHT_SORT_MODE'] = :extension
      self['RIGHT_SORT_ORDER'] = true
      self['RIGHT_MASK_MODE'] = :all
      # self['RIGHT_START_PATH'] = '~'

      # colors
      self['ENABLE_COLOR_256'] = true
      self['COLOR_DEFINITION'] = '~/.rhythm/dircolors'

      self['QUIT_CONFIRM'] = true

      # paneをscrollさせる
      # falseなら, 下端までいくと切り替える
      self['PANE_SCROLL'] = true
      # menuファイルを毎回読み込む
      self['MENU_RELOAD'] = true

      # yuno mode
      self['YUNO'] = true
    end

    # screen種類探索
    private
    @@screens_func = {
      :screen => lambda do |conf|
        screen = Sys.which('screen')
        if screen
          output = `#{screen} -ls`
          unless output =~ /No Sockets found/i
            screen
          else
            false
          end
        else
          false
        end
      end,
      :tscreen => lambda do |conf|
        tscreen = Sys.which('tscreen')
        if tscreen
          output = `#{tscreen} -ls`
          unless output =~ /No Sockets found/i
            tscreen
          else
            false
          end
        else
          false
        end
      end
    }
    @@screens = [:screen, :tscreen]
    def screen_configure
      # screen内かどうか判定 => 環境変数STY
      self['SCREEN'] = ENV.key?('STY')
      if self['SCREEN']
        @@screens.each do |name|
          res = @@screens_func[name].call(self)
          if res
            self['SCREEN'] = res
            break
          end
        end
      end
    end
  end
  Config.configure
end

