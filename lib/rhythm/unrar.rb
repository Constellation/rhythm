
  #     if entry[:has_exttime]
  #       temp = fd.read(2)
  #       access_mask = temp[0] >> 4
  #       modified_mask = temp[1] >> 4
  #       create_mask = temp[1] & 0xf
  #       unless (modified_mask & 8).zero?
  #         entry[:mtime] = []
  #         num = (modified_mask & 3)
  #         num.times do |i|
  #           entry[:mtime] << fd.read(1)
  #         end
  #         entry[:mtime] << ((modified_mask & 4).zero?)? 0 : 1
  #       end
  #       unless (create_mask & 8).zero?
  #         temp = fd.read(4)
  #         entry[:ctime] = dostime2unixtime(temp[0] + (temp[1] << 8) + (temp[2] << 16) + (temp[3] << 24))
  #         entry[:ctime_l] = []
  #         num = (create_mask & 3)
  #         num.times do |i|
  #           entry[:ctime_l] << fd.read(1)
  #         end
  #         entry[:ctime_l] << ((create_mask & 4).zero?)? 0 : 1
  #       end
  #       unless (access_mask & 8).zero?
  #         temp = fd.read(4)
  #         entry[:atime] = dostime2unixtime(temp[0] + (temp[1] << 8) + (temp[2] << 16) + (temp[3] << 24))
  #         entry[:atime_l] = []
  #         num = (create_mask & 3)
  #         num.times do |i|
  #           entry[:atime_l] << fd.read(1)
  #         end
  #         entry[:atime_l] << ((create_mask & 4).zero?)? 0 : 1
  #       end
  #     end

