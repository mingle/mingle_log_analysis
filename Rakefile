
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'time'
require 'evidence'
require 'mingle_saas_log_parser'
require 'json'

def dumpling_logs
  @dumpling_logs ||= MingleSaasLogParser.new('log/dumpling/**/mingle-cluster*')
end

def output(name, data)
  File.open("out/#{name}", 'w') do |f|
    case data
    when String
      f.write(data)
    when Array
      data.each do |line|
        f.write("#{line}\n")
      end
    else
      raise "Unknown data type #{data.class}"
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

  desc "response times, default range window 200 milliseconds"
  task :response_times do
    time_range = 3600 * 24 # 1 day
    response_times = lambda do |block|
      responses = []
      start_at, end_at = nil
      lambda do |action|
        end_at = Time.strptime(action[:request][:timestamp], "%Y-%m-%d %H:%M:%S")
        start_at = end_at if start_at.nil?
        responses << action[:response][:completed_time].to_i
        if end_at - start_at >= time_range
          block.call(start_at..end_at, responses)
          responses = []
          start_at, end_at = nil
        end
      end
    end

    Evidence.stream(dumpling_logs.actions_stream, response_times).each do |time_range, responses|
      t1 = time_range.min.strftime("%m-%d %H:%M")
      t2 = time_range.max.strftime("%m-%d %H:%M")
      tt = "#{t1}-#{t2}"
      puts tt
      output("responses_#{tt.gsub(/[^\d]/, '_')}", responses.to_json)
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
