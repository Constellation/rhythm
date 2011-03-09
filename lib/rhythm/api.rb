# Rhythm APIs
# Directionality of Rhythm APIs
#
# Rhythm APIは主に2つの方法で提供される
#  => Rhythm module内のinclude可能なmodule群
#  => Rhythm module内のSingleton
# なるべく多くのAPI公開(低レベルの場合も含め)を方針とし,
# 低レベルのものには その旨 + sample script を書く
# また, Rhythm本体に直接関係のないUtility群もAPIとして公開し,
# extensionの作りやすい環境状態とする.
#
# たとえばMozilla FirefoxのAPIの構造は, ほとんどにアクセスできる反面,
# たかだかキー定義だけでも結構なものを書く必要がある.
# そこで, 簡易なものに関しては目的ずばりのAPIを提供する反面,
# 細かいCoreなAPIも公開する方針とする.
# さらにより一般的なもの
# (キー定義, メニュー定義, 色指定, 拡張子関連付け, マスク定義などAFxを参考に)
# に関しては, 設定ファイルから読み込むという形で,
# Rubyすら書かずに定義可能とする.

# Rhythm Core accessor methods module
# vim: fileencoding=utf-8

module Rhythm
# API modules
  module Getter
    def notify
      return Core::notify
    end
    alias get_notify notify

    def core
      return Core
    end
    alias get_core core

    def commandline
      return Core::command
    end
    alias get_commandline commandline

    def statusline
      return Core::status
    end
    alias get_statusline statusline

    def current_pane
      return Core::current_pane
    end
    alias get_current_pane current_pane

    def another_pane
      return Core::another_pane
    end
    alias get_another_pane another_pane

    # get methods
    def get_pane set=:current
      if set == :another
        return another_pane
      else
        return current_pane
      end
    end
    def get_filelist set=:current
      return get_pane(set).filelist
    end

    def get_current_filelist
      current_pane.filelist
    end

    def get_another_filelist
      another_pane.filelist
    end

    def get_path set=:current
      return get_filelist(set).current.current
    end

    def get_path_entry set=:current
      return get_filelist(set).current
    end

    def get_current_entry set=:current
      return get_pane(set).get_current_entry
    end

    def get_selections set=:current
      return get_pane(set).selections
    end
  end

  module Utils
    include Getter
    # utility methods
    def swap_panes
      return Core::swap_panes
    end

    # quick puts
    def qputs *args
      notify.send(:qputs, *args)
    end

    def puts *args
      notify.send(:puts, *args)
    end

    def status text=nil
      statusline << text
    end

    def same_status_refresh set=:current
      get_pane(set).same_status_refresh
    end

    def same_dir_refresh set=:current
      get_pane(set).same_dir_refresh
    end

    def getch
      Core::getch
    end

    def progress *args
      commandline.send(:progress, *args)
    end

    def choose *args
      commandline.send(:choose, *args)
    end

    def ask_yes_no str
      commandline.ask_yes_no(str)
    end

    def getstr *args, &block
      commandline.send(:getstr, *args, &block)
    end

    def updater
      Core::updater
    end

    def which cmd
      Core::which(cmd)
    end

    def exec cmd
      Core::exec(cmd)
    end

    def exist_library? name
      Core::exist_library? name
    end

    def convert str
      return Kconv.kconv(str, Config['KCONV'])
    end
  end

  module GUI
    def getmaxx
      return Core::main_win::getmaxx
    end
    def getmaxy
      return Core::main_win::getmaxy
    end
  end

end

