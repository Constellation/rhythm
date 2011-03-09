module Rhythm
  module Mask
    register_glob_mask(:c, 'C Source', '*.c *.cpp *.h *.hpp')
    register_glob_mask(:music, 'Music', '*.mp3 *.mp4 *.wav *.m4a *.aac')
    register_lambda_mask(:dir, 'Dir') do |entry|
      entry.dir?
    end
  end
end

