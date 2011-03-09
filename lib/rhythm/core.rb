# vim: fileencoding=utf-8
# Rhythm Core Definition File

require "pp"
require "monitor"
require "fileutils"
require "rhythm/delimiter"

module Rhythm

  # Standard key definition table
  DEFAULT_KEY = {}
  # active key definition table
  KEY_DEF = {}
  module Core
    CMD_HASH = {}

    class << self
      include Delimiter
      attr_reader :notify, :command, :main_win, :notify, :main_win, :monito, :current_pane, :another_pane, :overlay
      alias active_pane current_pane

      public
      def run
        cbreak do |term|
          clear
          @main_win = Screen.new
          @monitor = Monitor.new
          @resize_flag = false

          @status = StatusLine.new(self)
          @command = CommandLine.new(self)
          @notify = Notify.new(self)
          @prompt = Prompt.new(self)
          @overlay = Overlay.new
          @prompt << " X / _ / X < " if Config['YUNO']
          @notify.puts "welcome to Rhythm version #{About::VERSION}"
          @panes = {
            :lpane => Pane.new(true),
            :rpane => Pane.new(false),
          }
          init_panes
          cursor true
          load_plugins
          updater
          main_loop
        end
      end

      def status stat
        @status.print stat
      end

      def doupdate
        @main_win.doupdate
      end

      def exist_library? lib
        result = nil
        res = $:.detect do |path|
          File.exist?(result = File.join(path, lib))
        end
        return res ? result : nil
      end

      def is_current_pane pane
        return @current_pane == pane
      end

      def create_temp_directory
        id = 0
        path = nil
        loop do
          path = File.join(Config['TEMP'], "RHYTHMTEMP#{id}")
          break unless File.exist?(path)
          id+=1
        end
        Dir.mkdir(path)
        return path
      end

      def exec command
        @notify << command
        if Config["SCREEN"]
          system("#{Config["SCREEN"]} #{command.decode}")
        else
          def_prog_mode @main_win
          clear
          move(0, 0)
          print "\n"
          system(command)
          reset_prog_mode
          updater
#          @main_win.doupdate
        end
      end

      def swap_panes
        @current_pane, @another_pane = @another_pane, @current_pane
        @current_pane.line_refresh
        @another_pane.line_refresh
        @current_pane
      end

      def right_pane
        @panes[:rpane]
      end

      def left_pane
        @panes[:lpane]
      end

     # private
      # 初期設定
      def configure
        @dircolors = DirColors.instance
      end

      def finalize
#        move(0, 0)
#        clear
        remove_temp_dirs
        Log.finalize
      end

      def remove_temp_dirs
        list = Dir.entries(Config['TEMP']).inject [] do |memo, path|
          memo << File.join(Config['TEMP'], path) unless path == '.' || path == '..'
          memo
        end
        FileUtils.rm_rf(list)
      end

      def init_panes
        @current_pane = @panes[:lpane]
        @another_pane = @panes[:rpane]
        @current_pane.display
        @another_pane.display
        @current_pane.line_refresh
      end

      # all resize
      def resize
        clear
        @main_win.resize
        @prompt.resize
        @current_pane.resize.line_refresh
        @another_pane.resize.line_refresh
        @status.resize
        @notify.resize
        @command.resize
      end

      def updater
        @monitor.synchronize do
          resize if @resize_flag
          @main_win.noutrefresh
          @main_win.doupdate
          @overlay.resize if @resize_flag
          @resize_flag = false
        end
      end

      def main_loop
        # timer = Timer.new
        # resize observer
        @tr = nil
        Signal.trap(:WINCH) do
          # resize_flagは即座に立てる
          @resize_flag = true
          # TODO: STDINのかわりにpipeをつなげ,
          # それにRESIZE eventを送り込む
          updater
        end
        begin
          # main loop
          loop do
            sym, res = getch
            if sym == :KEY
              execute(res[0])
            elsif sym == :FKEY
              @notify << res
            end
            updater
          end
        rescue => e
          exit
        ensure
          @tr.join if @tr
          endwin
          finalize
          unless e.to_s == 'QUIT'
            pp e.to_s
            pp e.backtrace
          end
        end
      end

      def load_plugins
        require "rhythm/commands"
        require 'rhythm/nursery_rhyme.rb'
        require 'rhythm/test_command.rb'
      end

      def execute ch
        case ch
        when ?\s
          Commands::SelectCommand.instance.execute
        when ?\r
#          @current_pane.cd
          @current_pane.enter
        when ?j
          Commands::CursorDownCommand.execute
        when ?J
          Commands::JumpCommand.execute
        when ?\C-c
          Commands::QuitCommand.execute
        when ?\C-d
          Commands::CursorNDownCommand.execute
        when ?\C-u
          Commands::CursorNUpCommand.execute
        when ?k
          Commands::CursorUpCommand.execute
        when ?o
          Commands::OverlayCommand.execute
        when ?a
          Commands::SelectAllCommand.execute
        when ?K
          Commands::SystemMkdirCommand.execute
        when ?r
          Commands::SystemRenameCommand.execute
        when ?s
          Commands::SortCommand.execute
        when ?S
          Commands::RegexpSelectCommand.execute
        when ?h
          Commands::LeftPaneCommand.execute
        when ?c
          Commands::SystemCopyCommand.execute
        when ?d
          Commands::SystemDeleteCommand.execute
        when ?m
          Commands::SystemMoveCommand.execute
        when ?l
          Commands::RightPaneCommand.execute
        when ?u
          Commands::SystemUpdirCommand.execute
        when ?e
          Commands::EditorCommand.execute
        when ?v
          Commands::PagerCommand.execute
        when ?/
          Commands::SearchCommand.execute
        when ?\\
          Commands::MaskCommand.execute
        when ?N
          Commands::SearchPrevCommand.execute
        when ?n
          Commands::SearchNextCommand.execute
        when ?t
          Commands::TestCommand.execute
        when ?q
          Commands::QuitCommand.execute
        else
          @notify << ch.chr
        end
        @prompt.call :precmd
      end

      def cmd_call name
        Commands.call name
      end

      def cmd_def cmd
        CMD_HASH[cmd.name] = cmd
      end

    end
  end

  # command用 namespace
  module Commands
    HASH = {}
    def call name
      HASH[name].execute
    end
    module_function :call
  end

end
