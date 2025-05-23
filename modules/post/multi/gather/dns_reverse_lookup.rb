##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Post

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Multi Gather DNS Reverse Lookup Scan',
        'Description' => %q{
          Performs DNS reverse lookup using the OS included DNS query command.
        },
        'License' => MSF_LICENSE,
        'Author' => [ 'Carlos Perez <carlos_perez[at]darkoperator.com>'],
        'Platform' => %w[bsd linux osx solaris win],
        'SessionTypes' => [ 'meterpreter', 'shell' ],
        'Notes' => {
          'Stability' => [CRASH_SAFE],
          'SideEffects' => [],
          'Reliability' => []
        }
      )
    )
    register_options(
      [
        OptAddressRange.new('RHOSTS', [true, 'IP Range to perform reverse lookup against.'])
      ]
    )
  end

  def run
    iprange = datastore['RHOSTS']
    print_status("Performing DNS Reverse Lookup for IP range #{iprange}")
    iplst = []

    a = []
    ipadd = Rex::Socket::RangeWalker.new(iprange)
    numip = ipadd.num_ips
    while (iplst.length < numip)
      ipa = ipadd.next_ip
      if !ipa
        break
      end

      iplst << ipa
    end

    case session.platform
    when 'windows'
      cmd = 'nslookup'
    when 'solaris'
      cmd = '/usr/sbin/host'
    else
      cmd = '/usr/bin/host'
    end

    while !iplst.nil? && !iplst.empty?
      1.upto session.max_threads do
        a << framework.threads.spawn("Module(#{refname})", false, iplst.shift) do |ip_add|
          next if ip_add.nil?

          r = cmd_exec(cmd, " #{ip_add}")
          case session.platform
          when 'windows'
            if r =~ /(Name)/
              r.scan(/Name:\s*\S*\s/) do |n|
                hostname = n.split(':    ')
                print_good "\t #{ip_add} is #{hostname[1].chomp("\n")}"
                report_host({
                  host: ip_add,
                  name: hostname[1].strip
                })
              end
            else
              vprint_status("#{ip_add} does not have a Reverse Lookup Record")
            end
          else
            if r !~ /not found/i
              hostname = r.scan(/domain name pointer (\S*)\./).join
              print_good "\t #{ip_add} is #{hostname}"
              report_host({
                host: ip_add,
                name: hostname.strip
              })
            else
              vprint_status("#{ip_add} does not have a Reverse Lookup Record")
            end
          end
        end
        a.map(&:join)
      end
    end
  end
end
