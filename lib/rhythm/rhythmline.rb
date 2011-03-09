# vim: fileencoding=utf-8
# Readline の Ruby + Delimiterによる実装
# 現在のReadlineのRuby Interfaceでは
# 特定キーにショートカット機能をもたせることが出来ないので,
# 独自に実装
#
require 'inline'
module Rhythm
  module RhythmLine
    @shortcutkeys = {}
    @completion_proc = nil

    class << self
      attr_accessor :completion_proc
      def readline prompt=""
        print(prompt)
        gets
      end

      def shortcutkey key
        @shortcutkeys[key] = Proc.new {|*args| yield(*args) }
      end

      def ok
        return @shortcutkeys
      end
    end
  end
end

