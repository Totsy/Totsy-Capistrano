class VarnishClient
  def connect(host, port)
      file = File.open 'varnishsecret'
      varnishsecret = file.read

      @@connection = TCPSocket.new host, port

      hello = @@connection.gets.chomp
      raise "Varnish server connection failure" unless hello

      code = hello.split(/ /).first
      raise "Unexpected response from Varnish" unless code == '107'

      challenge = @@connection.gets.chomp
      raise "Authentication challenge not received from Varnish" unless challenge

      auth = Digest::SHA2.new 256
      auth.update challenge + 0x0a.chr + varnishsecret + challenge + 0x0a.chr

      @@connection.puts "auth #{auth}"

      # discard the next three lines
      i = 3
      until i == 0 do 
          @@connection.gets
          i -= 1
      end

      result = @@connection.gets.chomp
      code = result.split(/ /).first
      raise "Authentication with Varnish failed" unless code == '200'

      # discard the next eight lines
      i = 8
      until i == 0 do 
          @@connection.gets
          i -= 1
      end
  end

  def disconnect
      @@connection.puts "quit"
      @@connection.close
  end

  def command(cmd)
      @@connection.puts cmd

      result = @@connection.gets.chomp
      code = result.split(/ /).first
      raise @@connection.gets.chomp unless code == '200'
  end
end
