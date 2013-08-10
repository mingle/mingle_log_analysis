
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'time'
require 'evidence'
require 'mingle_saas_log_parser'

namespace :analysis do
  task :count do
    counter = lambda do |block|
      count = 0
      lambda {|log| block.call(count += 1)}
    end
    parser = MingleSaasLogParser.new('log/dumpling/**/mingle-cluster*')
    Evidence.stream(parser.request_log_stream, counter).each do |count|
      puts "#{Time.now}: #{count}"
    end
  end

  task :littles_law, [:time_window, :output] do |_, args|
    output = args.output || 'littles_law.out'
    time_window = (args.time_window || 3600).to_i
    parser = MingleSaasLogParser.new('log/dumpling/**/mingle-cluster*')
    File.open(File.join('out', output), 'w') do |f|
      Evidence.stream(parser.actions_stream, Evidence.littles_law_analysis(time_window)).each do |start_time, end_time, avg_stay_in_system|
        t1 = start_time.strftime("%m-%d %H:%M")
        t2 = end_time.strftime("%H:%M")
        f.write("#{t1}-#{t2} #{avg_stay_in_system}\n".tap{|r| puts r})
      end
    end
  end
end
