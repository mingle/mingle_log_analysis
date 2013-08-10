
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'time'
require 'evidence'
require 'mingle_saas_log_parser'

def dumpling_logs
  @dumpling_logs ||= MingleSaasLogParser.new('log/dumpling/**/mingle-cluster*')
end

def output(name, data)
  File.open("out/#{name}", 'w') do |f|
    data.each do |line|
      f.write("#{line}\n")
    end
  end
end

namespace :analysis do
  desc "list count and timestamp when yield the count, use for testing log analysis performance"
  task :count do
    counter = lambda do |block|
      count = 0
      lambda {|log| block.call(count += 1)}
    end
    Evidence.stream(dumpling_logs.request_log_stream, counter).each do |count|
      puts "#{Time.now}: #{count}"
    end
  end

  desc "response distribution, default range window 200 milliseconds"
  task :response_distribution do
    bin_range = 100        # 0.1 second
    time_range = 3600 * 24 # 1 day
    distribution = lambda do |block|
      distribution = Hash.new {|h,k| h[k] = 0}
      start_at, end_at = nil
      lambda do |action|
        end_at = Time.strptime(action[:request][:timestamp], "%Y-%m-%d %H:%M:%S")
        start_at = end_at if start_at.nil?
        bin = action[:response][:completed_time].to_i/bin_range * bin_range
        distribution[bin] += 1
        if end_at - start_at >= time_range
          block.call(start_at..end_at, distribution)

          distribution = Hash.new {|h,k| h[k] = 0}
          start_at, end_at = nil
        end
      end
    end
    Evidence.stream(dumpling_logs.actions_stream, distribution).each do |time_range, distribution|
      t1 = time_range.min.strftime("%m-%d %H:%M")
      t2 = time_range.max.strftime("%m-%d %H:%M")
      tt = "#{t1}-#{t2}"
      puts tt
      p distribution
      output("response_distribution_#{tt}", distribution.keys.sort.map{|k| "#{k} #{distribution[k]}"})
    end
  end

  desc "output little's law analysis, default timewindow 3600 seconds"
  task :littles_law, [:time_window] do |_, args|
    time_window = (args.time_window || 3600).to_i
    data = Evidence.stream(dumpling_logs.actions_stream, Evidence.littles_law_analysis(time_window)).map do |start_time, end_time, avg|
      t1 = start_time.strftime("%m-%d %H:%M")
      t2 = end_time.strftime("%H:%M")
      "#{t1}-#{t2} #{avg}".tap{|r| puts r}
    end
    output('littles_law', data)
  end
end
