
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'time'
require 'evidence'
require 'mingle_saas_log_parser'
require 'json'
require 'fileutils'

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
  desc "list count and timestamp when yield the count, use for testing log analysis performance"
  task :count do
    counter = lambda do |block|
      count = 0
      lambda {|log| block.call(count += 1)}
    end
    (dumpling_logs.request_log_stream | counter).each do |count|
      puts "#{Time.now}: #{count}"
    end
  end

  def avg_response_times(avg_time_window)
    lambda do |output|
      lambda do |range, actions|
        stream = Evidence.stream(actions) | Evidence.slice_stream(lambda {|action| action[:request][:timestamp]}, avg_time_window)
        avgs = stream.map do |avg_range, avg_actions|
          count = avg_actions.size
          avg = avg_actions.reduce(0) {|memo, log| memo + log[:response][:completed_time].to_i} / count
        end
        output[range, avgs]
      end
    end
  end

  def normal_distribution
    lambda do |output|
      lambda do |range, responses|
        count = responses.size
        medium = responses.reduce(:+) / count
        sum = responses.inject(0) {|accum, i| accum + (i - medium)**2 }
        sample_variance = sum.to_f/count
        sd = Math.sqrt(sample_variance)
        output[range, medium, sd, count]
      end
    end
  end

  desc 'avg response time normal distribution, time_window: one distribution time window, 1 day default; avg_time_window: avg response time for normal distribution, default 60 seconds'
  task :avg_response_distribution, [:time_window, :avg_time_window] do |_, args|
    time_window = 3600 * 24 * (args.time_window || 1) # 1 day
    avg_time_window = args.avg_time_window || 60      # 1 minute
    stream = dumpling_logs.sliced_actions_stream(time_window) | avg_response_times(avg_time_window) | normal_distribution
    stream.each do |range, medium, sd, count|
      t1 = range.min.strftime("%m-%d %H:%M")
      t2 = range.max.strftime("%m-%d %H:%M")
      tt = "from #{t1} to #{t2}"
      puts "#{tt}, medium: #{medium}, SD: #{sd}, count: #{count}"
    end
  end

  desc "response times, default range window: 1 day, default avg response time window: 60 seconds"
  task :response_times do
    time_window = 3600 * 24 # 1 day
    avg_time_window = 60    # 1 minute
    (dumpling_logs.sliced_actions_stream(time_window) | avg_response_times(avg_time_window)).each do |time_range, responses|
      t1 = time_range.min.strftime("%m-%d %H:%M")
      t2 = time_range.max.strftime("%m-%d %H:%M")
      tt = "from #{t1} to #{t2}"
      fname = "responses_#{avg_time_window}_#{tt.gsub(/[^\d\w]/, '_')}"
      puts fname
      r = {
        title: "Avg Response Time (Range: #{avg_time_window}) #{tt}",
        data: responses
      }
      output(fname, r.to_json)
    end
  end

  def processing_rate_analysis
    processing = []
    prev = nil
    lambda do |output|
      lambda do |action|
        timestamp = action[:request][:timestamp]
        prev ||= timestamp
        processing << {action: action, completed_at: timestamp + action[:response][:completed_time].to_i / 1000}
        if prev < timestamp
          prev = timestamp
          processing.reject! { |pa| pa[:completed_at] < timestamp }
          output.call(timestamp, processing.size)
        end
      end
    end
  end
  task :processing_rate do
    stream = dumpling_logs.actions_stream | processing_rate_analysis
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
    stream = dumpling_logs.sliced_actions_stream(time_window) | Evidence.littles_law_analysis
    data = stream.map do |time_range, avg|
      t1 = time_range.min.strftime("%m-%d %H:%M")
      t2 = time_range.max.strftime("%H:%M")
      "#{t1}-#{t2} #{avg}".tap{|r| puts r}
    end
    output('littles_law', data)
  end
end
