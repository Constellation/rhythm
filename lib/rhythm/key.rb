
module Rhythm
  class Key
    def initialize key
      @command = nil
      @key = key
    end
    def set_command command
      @command = command
    end
    def execute
      if @command
        @command.execute
      end
    end
  end
end
