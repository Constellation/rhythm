# -*- coding: utf-8 -*-

# nursery rhyme
# rhythm standard commands
#

module Rhythm
  module Commands
    class QuitCommand < Command
      attr_reader :usage
      def initialize
        @usage = "quit Rhythm"
        super(:quit)
      end

      def execute
        if Config['QUIT_CONFIRM']
          raise 'QUIT' if ask_yes_no('quit? ')
        else
          raise 'QUIT'
        end
      end
    end

    class LeftPaneCommand < Command
      attr_reader :usage
      def initialize
        @usage = "select left pane"
        super(:leftpane)
      end

      def execute
        if current_pane.right?
          swap_panes
        end
      end
    end

    class RightPaneCommand < Command
      attr_reader :usage
      def initialize
        @usage = "select right pane"
        super(:rightpane)
      end

      def execute
        if current_pane.left?
          swap_panes
        end
      end
    end

    class CursorUpCommand < Command
      attr_reader :usage
      def initialize
        @usage = "up cursor"
        super(:upcursor)
      end

      def execute
        current_pane.cursor_up
      end
    end

    class CursorNUpCommand < Command
      attr_accessor :count
      def initialize
        @count = 5
        super(:upncursor)
      end

      def usage
        "up cursor #{@count} times"
      end

      def execute
        current_pane.cursor_up @count
      end
    end

    class CursorDownCommand < Command
      attr_reader :usage
      def initialize
        @usage = "down cursor"
        super(:downcursor)
      end

      def execute
        current_pane.cursor_down
      end
    end

    class CursorNDownCommand < Command
      attr_accessor :count
      def initialize
        @count = 5
        super(:downncursor)
      end

      def usage
        "down cursor #{@count} times"
      end

      def execute
        current_pane.cursor_down @count
      end
    end

    class SelectCommand < Command
      attr_reader :usage
      def initialize
        @usage = "select"
        super(:select)
      end

      def execute
        pane = current_pane
        pane.toggle_select
        pane.cursor_down
      end
    end

    class SelectAllCommand < Command
      attr_reader :usage
      def initialize
        @usage = "select all except for directory"
        super(:all_select)
      end

      def execute
        get_filelist(:current).each do |entry|
          entry.toggle_select unless entry.dir?
        end
        pane = current_pane
        pane.change_footer
        same_status_refresh(:current)
      end
    end

    # Directory Jump
    class JumpCommand < Command
      attr_reader :usage
      def initialize
        @usage = "directory jump"
        super(:jump)
      end
      def execute
        dict = {
          "H HOME" => File.expand_path("~"),
          "D DEV"  => File.expand_path("~/dev"),
          "W WORK" => File.expand_path("~/work")
        }
        list = dict.keys
#        index = Overlay.menu(
        index = Core::overlay.menu(
          :title => "Dir Jump",
          :list  => list,
          :key   => true
        )
        if index
          current_pane.jump(dict[list[index]])
        end
      end
    end

    # 正規表現によるfiltering select
    class RegexpSelectCommand < Command
      attr_reader :usage
      def initialize
        @usage = "filtering selection by regexp"
        super(:regexp_select)
      end

      def execute
        regexp_text = getstr("select filter by: ")
        begin
          reg = Regexp.compile(regexp_text)
          count = 0
          get_filelist(:current).each do |entry|
            if reg =~ entry.name
              entry.select
              count+=1
            end
          end
          puts("select #{count.to_s + (count==1? ' item' : ' items')} by #{Regexp.quote(regexp_text)}")
          pane = current_pane
          pane.change_footer
          same_status_refresh(:current)
        rescue RegexpError
          puts("invalid regexp: #{Regexp.quote(regexp_text)}")
        end
      end
    end

    # wild card(glob)によるfiltering select
    class GlobSelectCommand < Command
      attr_reader :usage
      def initialize
        @usage = "filtering selection by glob pattern"
        super(:glob_select)
      end

      def execute
        glob_text = getstr("select filter by: ")
        begin
          reg = Mask::extend_glob(glob_text)
          count = 0
          get_filelist(:current).each do |entry|
            if reg =~ entry.name
              entry.select
              count+=1
            end
          end
          puts("select #{count.to_s + (count==1? ' item' : ' items')} by #{glob_text}")
          pane = current_pane
          pane.change_footer
          same_status_refresh(:current)
        rescue RegexpError
          puts("invalid glob pattern: #{glob_text}")
        end
      end
    end


    class FindCommand < Command
      attr_reader :usage
      def initialize
        @usage = "find files"
        super(:find)
      end

      def execute
      end
    end

    class SearchCommand < Command
      attr_reader :usage
      def initialize
        @usage = "search entry"
        super(:search)
      end

      def execute
        commandline.search
      end
    end

    class SearchNextCommand < Command
      attr_reader :usage
      def initialize
        @usage = "search next entry"
        super(:search_next)
      end

      def execute
        commandline.next_search
      end
    end

    class SearchPrevCommand < Command
      attr_reader :usage
      def initialize
        @usage = "search prev entry"
        super(:search_prev)
      end

      def execute
        commandline.prev_search
      end
    end

    class EditorCommand < Command
      attr_reader :usage
      def initialize
        @usage = "edit entry"
        super(:editor)
      end

      def execute
        exec("#{Config['EDITOR']} #{get_current_entry.real_path}")
      end
    end

    class PagerCommand < Command
      attr_reader :usage
      def initialize
        @usage = "page entry"
        super(:pager)
      end

      def execute
        exec("#{Config['PAGER']} #{get_current_entry.real_path}")
      end
    end

    class SortCommand < Command
      attr_reader :usage
      def initialize
        @modes_list = Rhythm::FileList.sort_procs.keys
        @usage = "sort entries"
        @sort_modes = @modes_list.collect(&:to_s)
        super(:sort)
      end

      def execute
        cf = get_current_filelist#current_filelist => cf
        index = @modes_list.index(cf.sort_mode)
        result = choose('sort_mode? ', @sort_modes, index)
        if result
          cf.change_sort_mode @modes_list[result]
          puts "sorted by #{@sort_modes[result]}"
          same_status_refresh
        end
      end
    end

    class MaskCommand < Command
      attr_reader :usage
      def initialize
        super(:mask)
        @usage = "change mask"
        @masks = Rhythm::FileList.masks
        @masks_list = []
        @masks_text = []
        @masks_mask = []
        @masks.each_pair do |key, val|
          @masks_list << key
          @masks_mask << val[:mask]
          @masks_text << val[:text]
        end
      end

      def execute
        pane = get_pane
        cf = get_current_filelist#current_filelist => cf
        index = @masks_list.index(cf.mask_mode)
        result = choose('mask? ', @masks_text, index)
        if result
          cf.change_mask_mode @masks_list[result]
          puts "masked by #{@masks_text[result]}"
          same_status_refresh
        end
      end
    end

    class SystemCopyCommand < SystemCommand
      attr_reader :usage
      def initialize
        @usage = "copy files from stdfs to stdfs"
        super(:sys_cp)
      end

      def execute
        entries = get_selections
        current = get_pane
        pathname = get_path(:another)
        to_path = pathname.to_s
        all_size = entries.size
        entries.each_with_index do |entry, index|
          begin
            current.move_to entry.index
    #        if t_p.join(entry.basename).exist?
    #          core.main_win.overlay do |ol, scr|
    #          end
    #        end
            if entry.directory?
              cp_r(entry.path.to_s, to_path, {:verbose => true})
            else
              cp(entry.path.to_s, to_path, {:verbose => true})
            end
            current.draw_entry entry
          rescue => e
            puts e.to_s
          end
          progress((index+1) * 100 / all_size, "copy")
          entry.unselect
          updater
        end
        progress
        same_dir_refresh(:another)
        same_dir_refresh(:current)
      end

      def depup
      end
    end

    class SystemDeleteCommand < SystemCommand
      attr_reader :usage
      def initialize
        @usage = "delete files from stdfs"
        super(:sys_del)
      end

      def execute
        if ask_yes_no('delete ok? ')
          entries = get_selections(:current)
          all_size = entries.size
          if all_size.zero?
            entries = [get_current_entry]
            all_size = 1
          end
          entries.each_with_index do |entry, index|
            begin
              if entry.directory?
                rm_rf(entry.path)
              else
                rm(entry.path)
              end
              progress((index+1) * 100 / all_size, "delete")
              updater
            rescue => e
              puts e.to_s
            end
          end
          progress
          same_dir_refresh(:current)
        end
      end
    end

    class SystemMoveCommand < SystemCommand
      attr_reader :usage
      def initialize
        @usage = "move files from stdfs to stdfs"
        super(:sys_mv)
      end

      def execute
        entries = get_selections
        current = get_pane
        pathname = get_path(:another)
        to_path = pathname.to_s
        all_size = entries.size
        entries.each_with_index do |entry, index|
          begin
            mv(entry.path.to_s, to_path, {:verbose => true})
          rescue => e
            puts e.to_s
          end
          progress((index+1) * 100 / all_size, "move")
          updater
        end
        progress
        same_dir_refresh(:another)
        same_dir_refresh(:current)
      end
    end

    class SystemMkdirCommand < SystemCommand
      attr_reader :usage
      def initialize
        @usage = "mkdir in stdfs"
        @path = nil
    #    @completion_proc = lambda do |cmd|
    #      res = []
    #      path = File.dirname(cmd)
    #      reg = /\A#{Regexp.quote cmd}/
    #      path = File.join(@path, path)
    #      Dir.foreach(path) do |file|
    #        unless file == '.' || file == '..'
    #          if file =~ reg
    #            res << (File.directory?(File.join(path, file)) ? (file + '/') : file)
    #          end
    #        end
    #      end
    #      res
    #    end
        super(:sys_mkdir)
      end

      def execute
        @path = get_path(:current)
    #    dest = getstr("mkdir: ", &@completion_proc)
        dest = getstr("mkdir: ")
        unless dest.empty?
          path = File.join(@path, dest)
          begin
            mkdir_p(path, {:verbose => true})
          rescue => e
            puts e.to_s
          end
          same_dir_refresh(:current)
        end
      end
    end

    class SystemRenameCommand < SystemCommand
      attr_reader :usage
      def initialize
        super(:sys_rename)
        @usage = "rename in stdfs"
      end

      def execute
        entry = get_current_entry
        if entry.selectable?
          name = getstr("rename from #{entry.name}: ")
          path = (get_path + Pathname.new(name)).to_s
          begin
            mv(entry.path.to_s, path, {:verbose => true})
          rescue => e
            puts e.to_s
          end
          same_dir_refresh
          dest = get_filelist.detect{|ent| ent.path == path }
          if dest.nil?
            index = 0
          else
            index = dest.index
          end
          get_pane.move_to index
        end
      end
    end

    class SystemUpdirCommand < Command
      attr_reader :usage
      def initialize
        super(:sys_updir)
        @usage = "updir in stdfs"
      end

      def execute
        pane = get_pane
        now = get_path_entry
        current = get_pane
        parent = now.parent
        unless now == parent
          unless parent.nil?
            current.cd(parent, true)#第二引数に渡すときは, updirのときのみ.
          end
        end
      end
    end
  end
end


