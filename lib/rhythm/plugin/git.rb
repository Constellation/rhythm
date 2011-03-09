# -*- coding: utf-8 -*-

module Rhythm
  module Commands
    prompt_hook(
      :phase => :precmd,
      :execute => lambda do |core, ns|
        set_env_git_current_branch
        update_prompt
      end
    )
    prompt_hook(
      :phase => :chpwd,
      :execute => lambda do |core, ns|
        set_env_git_current_branch
        update_prompt
      end
    )
    def set_env_git_current_branch
      @git_current_branch= ` git branch --no-color 2> /dev/null | grep '^\*' | cut -b 3- `.chomp!
    end
    def update_prompt
      if `git ls-files 2>/dev/null` != ""
        @core.prompt.print(@git_current_branch)
      else
        @core.prompt.print("")
      end
    end
  end
end
