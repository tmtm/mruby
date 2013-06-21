#!/usr/bin/env mruby

def getmac(ifname)
  s = IO.popen("ifconfig #{ifname}", "r").read
  unless /lladdr (..:..:..:..:..:..)/ =~ s
    puts "cannot find MAC address of \"#{ifname}\""
    exit 1
  end
  srcmac = $1
  unless /inet (\d+\.\d+\.\d+\.\d+)/ =~ s
    puts "cannot find IP address of \"#{ifname}\""
    exit 1
  end
  srcip = $1
  [ srcmac, srcip ]
end

def send_discover(srcmac, srcip)
  pkt = [
    1,     # op
    1,     # htype
    6,     # hlen=Ethernet
    0,     # hops=0
    12345, # xid
    0,     # secs
    0,     # flags
    0,     # ciaddr
    0,     # yiaddr
    0,     # siaddr
    0      # giaddr
  ].pack("CCCCNnnNNNN")

  maca = srcmac.split(':').map { |o| o.to_i(16) }
  pkt += maca.pack("C6") + 0.chr * 10    # chaddr
  pkt += 0.chr * 64    # sname
  pkt += 0.chr * 128   # file
  pkt += [99, 130, 83, 99].pack("C4")    # magic cookie
  pkt += [53, 1, 1].pack("C*")           # DHCP Message Type = DHCPDISCOVER

  hostname = "dhcpwatcher"
  pkt += [12, hostname.size, hostname ].pack("C2a*") # Hostname
  #p "len=#{pkt.size}", pkt

  begin
    udp = UDPSocket.new(Socket::AF_INET)
    udp.bind(srcip, 68)
    addr = srcip.split('.').map { |x| x.to_i }.pack("C*")
    udp.setsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF, addr)
    udp.send pkt, 0, "255.255.255.255", 67
  rescue=>e
    p e
  ensure
    udp.close
  end
end

def tweet msg
  s = TCPSocket.open($irc[:server], $irc[:port])
  s.puts("NICK #{$irc[:nickname]}")
  s.puts("USER #{$irc[:nickname]} 0 * #{$irc[:nickname]}")
  #s.puts("JOIN #{$irc[:channel]}")
  s.puts("PRIVMSG #{$irc[:channel]} :#{msg}")
  s.puts("QUIT :done.")
  s.close
end

def config type, val
  case type
  when :watch
    $watch = val
  when :irc
    $irc = val
  end
end

def load_config filename
  filename = ARGV[0]
  filename = File.join(Dir.pwd, filename) unless filename[0] == '/'
  load filename
end

if ARGV.size != 1
  puts "usage: dhcpalert.rb <config>"
  exit 1
end
load_config ARGV[0]

srcmac, srcip = getmac($watch[:interface])
puts "srcip=#{srcip}"

pid = fork do
  while Process.ppid != 1
    sleep 1
    begin
      send_discover srcmac, srcip
    rescue => e
      p e
    end
    sleep 9
  end
  p "parent exited"
end
tweet "start"

cap = Pcap::Capture.open_live($watch[:interface], 576)
cap.setfilter("udp and src port 67", true)
while a = cap._dispatch
  a.each { |pkt|
    dstmac = pkt[6, 6].unpack("C*").map { |x| "%02x" % x }.join(':')
    srcip  = pkt[14+12, 4].unpack("C*").map { |x| x.to_s }.join('.')
    unless $watch[:servers].include? srcip
      msg = "#{Time.now} Rogue DHCP server found! ip=#{srcip} mac=#{dstmac}"
      puts msg
      tweet msg
      exit
    end
  }
end
