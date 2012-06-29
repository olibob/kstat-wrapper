#!/usr/bin/env ruby
# Wed Jun 27 2012
# version: 0.1

require 'optparse'
require 'socket'
#require 'pp'

options = {}

opt_parser = OptionParser.new do |opt|
  opt.banner = "Usage: zcpu [-is] [--info]"
  opt.separator  ""
  opt.separator  "Options"

  options[:sec] = ""
  opt.on( '-s', '--seconds SECONDS', "number of seconds between sequences" ) do |s|
    options[:sec] = s
  end

  options[:ite] = ""
  opt.on( '-i', '--iteration NUMBER', "number of sequences" ) do |i|
    options[:ite] = i
  end

  options[:info] = ""
  opt.on( '--infos', "general information" ) do |info|
    options[:info] = info
  end

  opt.on("-h","--help") do 
    puts opt_parser
    exit
  end
end

opt_parser.parse!
#pp "Options:", options

def zone?
  host = Socket.gethostname

  check = %x[zoneadm list -icv | grep #{host}]
  if searchID = check.match("#{host}")
    id = searchID.pre_match.strip
  end
  id
end

class ORKstat
  def initialize(zoneID)
    @cmdString = %x[kstat -m caps -n cpucaps_zone_#{zoneID}]
    raise "No capping detected" if @cmdString.empty?
  end

  def getCpuUsage
    usage = @cmdString.match(/\s+usage\s+(\d+)/).captures[0].to_f
    value = @cmdString.match(/\s+value\s+(\d+)/).captures[0].to_f
    result = (usage * 100 )/ value
  end

  def getGeneralInfo
    info = {}

    cappingValue = @cmdString.match(/\s+value\s+(\d+)/).captures[0].to_i
    info[:cappingValue] = cappingValue/100

    timeAboveCapping = @cmdString.match(/\s+above_sec\s+(\d+)/).captures[0].to_f
    info[:timeAboveCapping] = timeAboveCapping / (3600 * 24)

    timeBelowCapping = @cmdString.match(/\s+below_sec\s+(\d+)/).captures[0].to_f
    info[:timeBelowCapping] = timeBelowCapping / (3600 * 24)

    info[:ratio] = (timeAboveCapping *100) / timeBelowCapping

    globalCpuCount = %x[psrinfo | wc -l]
    info[:globalCpuCount] = globalCpuCount.to_i
    info[:maxPercent] = cappingValue / globalCpuCount.to_i

    return info
  end
end


if __FILE__ == $0

  # Are we running the script from a zone?
  zoneID = zone?
  if !zoneID
    puts "Looks like you're not in a solaris zone. Bye."
    exit
  end

  iterations = options[:ite].to_i
  iterations = 1 if iterations == 0

  seconds = options[:sec].to_i
  seconds = 1 if seconds == 0

  count = 0
  begin
    zcpu = ORKstat.new(zoneID)

    if (options[:info] != "" and count == 0)
      puts "-"*63
      puts "\t\t General Information"
      puts "-"*63
      puts "Capping (virtual CPU number out of #{zcpu.getGeneralInfo[:globalCpuCount]})\t\t%d Virtual CPUs" % zcpu.getGeneralInfo[:cappingValue]
      puts "Time spent within capping settings\t\t%.2f days" % zcpu.getGeneralInfo[:timeAboveCapping]
      puts "Time spent above capping settings\t\t%.2f days" % zcpu.getGeneralInfo[:timeBelowCapping]
      puts "Ratio of time spent above capping\t\t%.2f %" % zcpu.getGeneralInfo[:ratio]
      puts "Max process percent in tools like prstat\t%.2f %" % zcpu.getGeneralInfo[:maxPercent]
      puts "-"*63
      puts
    end

    puts "Zone CPU Usage: %.2f %" % zcpu.getCpuUsage

    count += 1
    sleep seconds if (seconds and count < iterations)
  end while count < iterations
end