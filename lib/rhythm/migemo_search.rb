require 'kconv'
require 'singleton'
# vim: fileencoding=utf-8
# kcode = eの空間を作成し, migemoに処理してもらって返してもらう.
# CMigemo or Migemoの差異吸収
# 存在しない場合には使えないように
# kconv + $KCODE

module Rhythm
  class MigemoSearch
    DIRMAP = {
      "UTF8" => "utf-8",
      "SJIS" => "cp932",
      "EUC"  => "euc-jp"
    }
    def initialize
      @stat = nil
      if cmigemo
        @stat = :cmigemo
      elsif migemo
        @stat = :migemo
      end
    end

    def search pattern
      return @cache[pattern] if @cache.has_key?(pattern)
      if @stat == :cmigemo
        cmigemo_search pattern
      else
        migemo_search pattern
      end
    end

    def valid
      !!@stat
    end

    private
    def cmigemo
      require 'cmigemo'
      @migemo = CMigemo.new
      cdict.each do|file, type|
        @migemo.load(type, file)
      end
      @cache = {}
      return true
    rescue LoadError
      return false
    end

    def cdict
      dir = DIRMAP[$KCODE]
      path = Config['CMIGEMO_DICT_DIR'] || '/usr/local/share/migemo/'
      path = File.join(path, dir)
      {
        File.join(path, "migemo-dict")   => CMigemo::MIGEMO,
        File.join(path, "han2zen.dat")   => CMigemo::HAN2ZEN,
        File.join(path, "hira2kata.dat") => CMigemo::HIRA2KATA,
        File.join(path, "roma2hira.dat") => CMigemo::ROMA2HIRA
      }
    end

    def cmigemo_search pattern
      result = @migemo.query(pattern)
      @cache[pattern] = result if pattern.length < 4
      return result
    end

    def migemo
      kcode 'e' do
        begin
          require 'migemo'
          static_dict = File.expand_path Config['MIGEMO_STATIC_DICT']
          dict_cache = File.expand_path Config['MIGEMO_DICT_CACHE']
          @static_dict_migemo = MigemoStaticDict.new(static_dict)
          @cache = {}
          raise 'migemo static dict not found' unless File.exist? static_dict
          if dict_cache && File.exist?(dict_cache)
            @dict_cache = MigemoDictCache.new dict_cache
          else
            @dict_cache = nil
          end
          @optimization = 2
          true
        rescue LoadError
          false
        rescue => e
          false
        end
      end
    end

    def kcode c, *args
      prev = $KCODE
      begin
        $KCODE = c
        return yield(*args)
      ensure
        $KCODE = prev
      end
    end

    def migemo_search pattern
      escaped = Regexp.escape(pattern)
      kcode 'e' do
        euc_pattern = escaped.toeuc
        migemo = Migemo.new(@static_dict_migemo, euc_pattern)
        migemo.dict_cache = @dict_cache if @dict_cache
        migemo.optimization = @optimization
        migemo.with_paren = false
        result = Kconv.kconv(migemo.regex, Kconv::UTF8, Kconv::EUC)
        @cache[pattern] = result if pattern.length < 4
      end
      return result
    end
  end

  Search = MigemoSearch.new
end

