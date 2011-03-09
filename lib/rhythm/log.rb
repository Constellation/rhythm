# -*- coding: utf-8 -*-
#
require 'monitor'

module Rhythm
  class Log
    class << self
      def log n
        f = file
        @mutex.synchronize do
          f.puts n
        end
      end
      alias << log
      def finalize
        if @file
          @mutex.synchronize do
            file.close
          end
        end
      end
      def file
        @file if @file
        @mutex = Monitor.new
        @file = File.open(File.expand_path(Config['LOG']), 'ab')
        @file.sync = true
        @file
      end
    end
  end
end

