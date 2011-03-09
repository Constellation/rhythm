#
# -*- coding: utf-8 -*-
#
# stdfs基準に一般化 (例: cp)
#
# 両方stdfs     => stdfsでcp
# fromがstdfs   => dest側でfromを取得しcp
# destがstdfs   => from側でdestに向けcp
# 両方stdfs以外 => fromをtempへcpし, dest側が取得しcp
#
# 特殊fs構築時の仕様
# tempへ移動するmethod
# stdfsから渡されるentryを処理するmethod
# stdfsへentryを処理するmethod
# の3種類を定義すると利用可能となる.
#

module Rhythm
  module CommonCommands
    def common_cp from, dest
      if from.fs.name == :stdfs
        if dest.fs.name == :stdfs
          STDFS.cp from, dest
        else
          dest.fs.cp_from from
        end
      elsif dest.fs.name == :stdfs
        from.fs.cp_to dest
      else
        dest.fs.cp_from from.fs.cp_temp
      end
    end

    def common_mv from, dest
      if from.fs.name == :stdfs
        if dest.fs.name == :stdfs
          STDFS.mv from, dest
        else
          dest.fs.mv_from from
        end
      elsif dest.fs.name == :stdfs
        from.fs.mv_to dest
      else
        dest.fs.mv_from from.fs.mv_temp
      end
    end

    def common_rm dest
      dest.fs.remove
    end

    def common_jump dest
      dest.fs.jump
    end

    def common_extract dest
      dest.fs.extract
    end

    def common_mkdir dest
      dest.fs.mkdir
    end

    module_function :common_cp, :common_mv, :common_rm, :common_jump, :common_extract, :common_mkdir

  end
end


