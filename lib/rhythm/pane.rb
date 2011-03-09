# vim: fileencoding=utf-8
# Rhythm Pane : GUI Class

module Rhythm
  class Pane < Object
    attr_reader :filelist, :pane, :top_statement, :cursor_y
    @@cursor_prefix = 6
    include Utils, GUI

    def self.is_current_pane pane
      Core::current_pane == pane
    end

    def initialize left
      win = Core::main_win
      width, r = win.getmaxx.divmod(2)
      height = win.getmaxy-7
      @left = left
      if left
        @box, @pane  = win.subwin2(height, width, 1, 0)
      else
        @box, @pane  = win.subwin2(height, width, 1, width+r)
      end
      @box.border('|', '|', '-', '-', '+', '+', '+', '+')
      @box.noutrefresh(true, true, true, true)
      dir_c = DirColors.instance
      @title_color = dir_c.get "TITLE"
      @filelist = FileList.new((left)? :left : :right)
      @pane.scrollok true
    end

    def left?
      return @left
    end

    def right?
      return !@left
    end

    def display
      @pane.clear
      @cursor_y = 0
      @cursor_x = 0
      @top_statement = 0
      refresh
      change_title
      change_footer
      self
    end

    def resize
      width, r = getmaxx.divmod(2)
      height = getmaxy-7
      if @left
        @box.resize(height, width, 1, 0)
        @pane.resize(height-2, width-2, 2, 1)
      else
        @box.resize(height, width, 1, width+r)
        @pane.resize(height-2, width-2, 2, width+r+1)
      end
      @box.border('|', '|', '-', '-', '+', '+', '+', '+')
      @box.noutrefresh(true, true, true, true)
      refresh
      move_to @top_statement + @cursor_y
      change_title
      change_footer
      self
    end

    # display files in range
    def refresh
      @filelist[@top_statement, @pane.getmaxy].each do |entry|
        draw_entry entry
      end
      @pane.noutrefresh
    end

    # display files in range (not scrollable ver)
    def refresh2
      @filelist[@paneid*(@pane.getmaxy), @pane.getmaxy].each do |entry, index|
        draw_entry2 entry, index
      end
      @pane.noutrefresh
    end

    # 同一directoryで@top_statementや@cursor_yを保ってrefresh
    # select情報は消えるが, filelistは最新
    def same_dir_refresh
      @pane.clear
      @filelist.refresh
      size = @filelist.size
      height = @pane.getmaxy
      state = size - height
      if state < 0
        @top_statement = 0
      elsif @top_statement > state
        @top_statement = state
      end
      if @cursor_y >= size - @top_statement
        @cursor_y = size - 1 - @top_statement
      end
      refresh
      change_title
      change_footer
      self
    end

    # 同一directoryで@top_statementや@cursor_yを保ってrefresh
    # select情報は消ないが, filelistは最新を保障されない
    def same_status_refresh
      @pane.clear
      size = @filelist.size
      height = @pane.getmaxy
      state = size - height
      if state < 0
        @top_statement = 0
      elsif @top_statement > state
        @top_statement = state
      end
      if @cursor_y >= size - @top_statement
        @cursor_y = size - 1 - @top_statement
      end
      refresh
      change_title
      change_footer
      self
    end

    def change_title name=@filelist.path
      # clear title
      maxx = @box.getmaxx - 1
      @box.top_hline(2, '-', maxx - 4)
      @box.draw_top(2, ("#{name} #{@filelist.mask[:mask]}").w_rmax(maxx-4, '-'), "\x1b[0;38;5;#{@title_color}m")
      @box.noutrefresh(true, false, false, false)
    end

    def change_footer
      maxx = @box.getmaxx - 1
      @box.bottom_hline(2, '-', maxx - 4)
      @box.draw_bottom(2, ("(#{@filelist.selected_size}/#{@filelist.selectable_size})").w_rmax(maxx-4, '-'), "\x1b[0;38;5;#{@title_color}m")
      @box.noutrefresh(false, true, false, false)
    end

    def line_refresh
      entry = get_current_entry
      if entry
        draw_entry entry
        Core.status entry.statusline if Pane.is_current_pane(self)
      end
    end

    def search n, str, index=nil
      index ||= @top_statement + @cursor_y
      entry = @filelist.search_entry(index, n, str)
      if entry
        move_to entry.index
      end
      return entry
    end

    # enter時
    # 特別処理
    def enter
      entry = get_current_entry
      extname = entry.extname.downcase
      if entry.dir?
        cd entry, entry.top
      elsif extname == '.gz' || extname == '.bz2' || extname == '.tgz' || extname == '.zip' || extname == '.rar' || extname == '.iso'
        extract entry
      elsif extname == '.mp3' || extname == '.wav'
        if entry.real_path
          #Core::exec("amarok #{entry.real_path}")
        else
          Core::notify.puts("missing entry path")
        end
      else
        if entry.real_path
          Core::exec("less #{entry.real_path}")
        else
          Core::notify.puts("missing entry path")
        end
      end
    end

    # cd
    def cd entry=nil, updir=false
      old_path = @filelist.path
      unless entry
        temp = get_current_entry
        if temp.dir?
          entry = temp
        end
      end
      if entry
        begin
          @filelist.cd entry
          display
          if updir
            entry = @filelist.get_entry_by_path(old_path)
            if entry
              index = entry.index
            else
              index = 0
            end
            move_to index
          end
        rescue Errno::EACCES => e
          Core::notify.puts e
          # 最初からの変更の無限ループ回避
#          if entry.path == old_path
#            cd "/"
#          else
#            cd old_path
#          end
        end
      end
    end

    def jump path
      entry = STDFS::Entry::new(Pathname.new(File.expand_path(path)), false)
      begin
        @filelist.jump entry
        display
      rescue Errno::EACCES => e
        Core::notify.puts e
      end
    end

    def extract entry
      Core::notify.qputs "extract #{entry.real_path}"
      @filelist.extract entry
      @filelist.refresh
      display
    end

    def get_current_entry
      @filelist[@top_statement + @cursor_y]
    end

    def get_first_entry
      @filelist[@top_statement]
    end

    def get_last_entry
      @filelist[@top_statement + @pane.getmaxy - 1]
    end

    def get_entries_in_view range
      @filelist[range]
    end

    def get_entries_by_first n
      @filelist[@top_statement, n]
    end

    def get_entries_by_last n
      @filelist[@top_statement + @pane.getmaxy - n, n]
    end

    def toggle_select
      entry = get_current_entry
      entry.toggle_select
      draw_entry entry
      change_footer
      @pane.noutrefresh
    end

    def select entry = nil
      if entry == nil
        entry = get_current_entry
      end
      entry.select
      draw_entry entry if entry
    end

    def unselect entry = nil
      if entry == nil
        entry = get_current_entry
      end
      entry.unselect
      draw_entry entry if entry
    end

    # 指定index番目のentryをなるべく
    # 低コストで中央に表示し, 選択するmethod
    # 中央表示がfilelist.size上無理であればなるべく付近に表示
    def move_to index
      # 再描画必要性検討
      old_entry = get_current_entry

      # 座標修正Phase
      height = @pane.getmaxy - 1
      last = @filelist.size - 1
      now_top_statement = @top_statement
      half = height >> 1

      if height >= last
        @top_statement = 0
        @cursor_y = index
      elsif index + half >= last
        @top_statement = last - height
        if last < index
          @cursor_y = height
        else
          @cursor_y = index - @top_statement
        end
      elsif index - half < 0
        @top_statement = 0
        if index < 0
          @cursor_y = 0
        else
          @cursor_y = index
        end
      else
        @top_statement = index - half
        @cursor_y = half
      end

      hold = @top_statement - now_top_statement

      if hold.abs < height
        # highlight解除
        # draw_entry old_entry if (@top_statement..(@top_statement+height)).include?(old_entry.index)

        unless hold.zero?
          @pane.scrl(hold)
          if hold > 0
            get_entries_by_last(hold).each do |entry|
              draw_entry entry
            end
          else
            get_entries_by_first(-hold).each do |entry|
              draw_entry entry
            end
          end
        end
      else
       refresh
      end
      # highlight
      draw_entry old_entry
      line_refresh
      @pane.noutrefresh
    end

    # ゆとりをもって最下行表示
    # 6行以内にくると自動で先行表示
    # nに数字を渡すとその分先行表示などを計算しつつcursorをdownさせる.
    def cursor_down n=1
      # 再描画必要性検討Phase
      # cursor位置がfilelistの表示限界よりも下に存在する
      # 動かす必要なし
      list_index = @filelist.size - 1
      unless @cursor_y + @top_statement == list_index

        # ハイライト解除Phase
        old_entry = get_current_entry

        # 座標補正Phase
        maxy = @pane.getmaxy - 1
        if @cursor_y > (maxy - @@cursor_prefix - n)
          # そして, いまだfilelist終端まで表示しきっていない
          if @top_statement + maxy < list_index
            # scrlするまでの余剰があるのか?
            # あるならつめる.
            a = (maxy - @@cursor_prefix) - @cursor_y
            @cursor_y += a
            n = n - a
            # 最下行がnより小さい
            if @top_statement + maxy + n > list_index
              n = list_index - @top_statement - maxy
            end
            @pane.scrl(n)
            @top_statement += n
            # 描画
            get_entries_by_last(n).each{|entry| draw_entry entry }
          else
            # filelist終端まで表示しきっていて, @cursor_yが最下行ではない
            # nだけ移動するとmaxyを超える
            which_min = (maxy < list_index)? maxy : list_index
            if @cursor_y + n > which_min
              @cursor_y = which_min
            else
              @cursor_y += n
            end
          end
        else
        # cursor位置が最下行の位置より-7した場所より上にいる
        # この下の条件分岐は, upの際は考慮する必要がない
          # 移動位置がfilelistの終端より大きい
          if @cursor_y + n > list_index
            @cursor_y = list_index
          else
            @cursor_y += n
          end
        end

        # ハイライトPhase
        draw_entry old_entry
        line_refresh
        # 再描画予約Phase
        @pane.noutrefresh
      end
    end

    def cursor_up n=1
      # 再描画必要性検討Phase
      # cursor位置が最上段
      # 動かす必要なし
      unless @cursor_y.zero?

        # ハイライト解除Phase
        old_entry = get_current_entry

        # 座標補正Phase
        # cursor位置が最上行の位置(0)より+6した場所より上まで至っている
        # scrl発生条件
        if @cursor_y < @@cursor_prefix + n
          # そして, いまだtop_statement 0まで表示しきっていない
          if @top_statement > 0
            # scrlするまでの余剰があるのか?
            # あるならつめる.
            a = @cursor_y - @@cursor_prefix
            @cursor_y -= a
            n = n - a
            # top_statementがnより小さい
            n = @top_statement if @top_statement < n
            @pane.scrl(-(n))
            @top_statement -= n
            # 描画
            get_entries_by_first(n).each{|entry| draw_entry entry }
          # top_statement 0まで表示しきっている
          #elsif @cursor_y > 0
          else
            n = @cursor_y if @cursor_y < n
            @cursor_y -= n
          end
        # cursor位置が最上行の位置より+7した場所より下にいる
        else
          @cursor_y -= n
        end

        # ハイライトPhase
        draw_entry old_entry
        line_refresh
        # 再描画予約Phase
        @pane.noutrefresh
      end
    end

    def path
      @filelist.path
    end

    def selections
      @filelist.inject([]) do |memo, entry|
        if entry.selected
          memo << entry
        end
        memo
      end
    end

    def draw_entry entry
      target = entry.index - @top_statement
      if @pane.getmaxy - 1 >= target && target >= 0
        if target == @cursor_y && Pane.is_current_pane(self)
            @pane.mvaddstr(target, 0, "#{entry.selected ? "*" : " "} #{entry.line}".w_ljust(@pane.getmaxx), "\x1b[4;38;5;#{entry.color}m")
        else
          @pane.mvaddstr(target, 0, "#{entry.selected ? "*" : " "} #{entry.line}".w_ljust(@pane.getmaxx), "\x1b[0;38;5;#{entry.color}m")
        end
      else
        Core::notify << "alert"
      end
    end

    # not scrollable ver
    def draw_entry2 entry, index
      if @pane.getmaxy - 1 >= index && index >= 0
        if index == @cursor_y && Pane.is_current_pane(self)
            @pane.mvaddstr(index, 0, "#{entry.selected ? "*" : " "} #{entry.line}".w_ljust(@pane.getmaxx), "\x1b[4;38;5;#{entry.color}m")
        else
          @pane.mvaddstr(index, 0, "#{entry.selected ? "*" : " "} #{entry.line}".w_ljust(@pane.getmaxx), "\x1b[0;38;5;#{entry.color}m")
        end
      end
    end
  end
end
