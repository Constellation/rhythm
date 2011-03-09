# -*- coding: utf-8 -*-

module Rhythm
  module Plugins
    class ScreenNotifier
      class << self
        def notify arg
          print "\033k#{arg}\033\\" if Config['SCREEN']
        end
      end
    end
  end
end

