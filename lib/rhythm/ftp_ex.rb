# -*- coding: utf-8 -*-
# ftpにごく小数の拡張を加えたもの
require 'net/ftp'
module Net
  class FTP
    def feat
      resp = sendcmd("FEAT")
      if resp[0, 3] != "211"
        raise FTPReplyError, resp
      end
      resp = resp.split(/\s*(?:\r\n|\n|\r)\s*/)
      if resp.size > 2
        return resp[1, resp.size-2]
      else
        return []
      end
    end

    def mdtm filename
      voidcmd("TYPE I")
      resp = sendcmd("MDTM " + filename)
      if resp[0, 3] != "213"
        raise FTPReplyError, resp
      end
      return resp[3..-1].strip.to_i
    end
  end
end


