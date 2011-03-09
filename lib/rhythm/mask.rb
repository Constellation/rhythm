module Rhythm
  module Mask
    # hash mask
    # {
    #   :mask => mask text
    #   :text => name
    #   :reg  => regexp
    # }
    # ex:
    # register_regexp_mask(:all, 'All', '*', /.+$/)
    def register_regexp_mask sym, text, mask, reg
      h = {}
      h[:type], h[:text] ,h[:mask], h[:reg] = :reg, text, mask, reg
      register_mask(sym, h)
    end
    module_function :register_regexp_mask

    # 最終的にはregexp maskとしてregister
    # ex:
    # register_glob_mask(:all, 'All', '*')
    def register_glob_mask sym, text, glob
      h = {}
      h[:type], h[:text], h[:mask], h[:reg] = :reg, text, glob, extend_glob(glob)
      register_mask(sym, h)
    end
    module_function :register_glob_mask

    # Ruby-basedの真骨頂, lambda mask
    # lambdaにentryが渡されるので, trueを返したもののみにフィルターする.
    # ex:
    # register_lambda_mask(:dir, 'Dir') do |entry|
    #   entry.dir?
    # end
    def register_lambda_mask sym, text, mask=nil, &block
      h = {}
      mask = text if mask.nil?
      h[:type], h[:text], h[:mask], h[:lambda] = :lambda, text, mask, block
      register_mask(sym, h)
    end
    module_function :register_lambda_mask

    def extend_glob text
      text = text.split(/\s/).collect! do |token|
        token = Regexp.escape(token)
        token.gsub!('\*', '.+')
        token.gsub!('\?', '.')
        token << '$'
      end.join('|')
      Regexp.compile(text)
    end
    module_function :extend_glob

    def register_mask name, hash
      Rhythm::FileList.register_mask name, hash
    end
    module_function :register_mask

  end
end
