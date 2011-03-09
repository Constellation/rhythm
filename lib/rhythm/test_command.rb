
module Rhythm
  module Commands
    class TestCommand < Command
      def initialize
        super(:test)
      end

      def usage
        "test command"
      end

      def execute
        GC.start
        puts 'GC'
        #progress
      end
    end

    class OverlayCommand < Command
      attr_reader :usage
      def initialize
        @usage = "overlay"
        super(:overlay)
      end
      def execute
#        Overlay.message(<<-EOS)
#おはようございます
#土曜日です
#ただいま七時38分
#次は朝日ビール提供
#今朝のクローズアップです
#        EOS
#        result = choose('delete ok? ', ['yes', 'no'])
#        puts((result == 0)? 'DELETE!' : 'NOT DELETE')
#        sleep(2)
         Core.overlay.menu(:list => <<-EOS.split("\n"), :title => "おはよう朝日")
おはようございます
土曜日です
ただいま七時38分
次は朝日ビール提供
今朝のクローズアップ☆です
         EOS
      end
    end

    class F1Command < Command
      attr_reader :usage
      def initialize
        @usage = "f1 command"
        super(:f1command)
      end
      def execute
      end
    end
  end
end

