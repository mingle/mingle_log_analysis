
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'time'
require 'evidence'
require 'mingle_saas_log_parser'
require 'json'
require 'fileutils'
require 'statsample'

def dumpling_logs
  @dumpling_logs ||= MingleSaasLogParser.new
end

def output(name, data)
  FileUtils.mkdir_p('out')
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
  def avg_response_times(avg_time_window)
    lambda do |args|
      range, actions = args
      avgs = actions.lazy.chunk(&Evidence.by_time_window(avg_time_window)).map do |args|
        range, avg_actions = args
        avg_actions.map {|a|a[:response][:completed_time].to_i}.to_scale.mean
      end
      {range: range, avgs: avgs}
    end
  end

  desc "response times, default range window: 1 day, default avg response time window: 60 seconds"
  task :response_times do
    time_window = 3600 * 24 # 1 day
    avg_time_window = 60    # 1 minute

    stream = dumpling_logs.sliced_actions_stream(time_window).map(&avg_response_times(avg_time_window))
    stream.each do |stats|
      t1 = stats[:range].min.strftime("%m-%d %H:%M")
      t2 = stats[:range].max.strftime("%m-%d %H:%M")
      tt = "from #{t1} to #{t2}"
      fname = "responses_#{avg_time_window}_#{tt.gsub(/[^\d\w]/, '_')}"
      puts fname
      r = {
        title: "Avg Response Time (Range: #{avg_time_window}) #{tt}",
        data: stats[:avgs].force
      }
      output(fname, r.to_json)
    end
  end

  def processing_rate_analysis
    processing = []
    prev = nil
    lambda do |action|
      timestamp = action[:request][:timestamp]
      prev ||= timestamp
      processing << {action: action, completed_at: timestamp + action[:response][:completed_time].to_i / 1000}
      if prev < timestamp
        prev = timestamp
        processing.reject! { |pa| pa[:completed_at] < timestamp }
        [timestamp, processing.size]
      end
    end
  end

  task :processing_rate do
    stream = dumpling_logs.actions_stream.map(&processing_rate_analysis).compact
    File.open('out/processing_rate', 'w') do |f|
      stream.each do |time, rate|
        t = time.strftime("%Y-%m-%d %H:%M:%S")
        puts "#{t}: #{'.' * rate}" if rate > 2
        f.write("#{t},#{rate}\n")
      end
    end
  end

  desc "output little's law analysis, default timewindow 3600 seconds"
  task :littles_law, [:time_window] do |_, args|
    time_window = (args.time_window || 3600).to_i
    stream = dumpling_logs.sliced_actions_stream(time_window).map(&Evidence.littles_law_analysis)
    data = stream.map do |stats|
      t1 = stats[:range].min.strftime("%m-%d %H:%M")
      t2 = stats[:range].max.strftime("%H:%M")
      "#{t1}-#{t2} #{stats[:value]}".tap{|r| puts r}
    end
    output('littles_law', data.to_a)
  end
end
