
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
        [timestamp, processing.dup]
      end
    end
  end

  def warn(msg)
    # puts msg
  end

  task :busy_actions, [:dirs] do |_, args|
    dirs = args.dirs || 'log/dumpling/*'
    stream = dumpling_logs.actions_stream(dirs).map(&processing_rate_analysis).compact
    data = Hash.new {|h,k| h[k] = 0}
    stream.each do |time, processing|
      t = time.strftime("%Y-%m-%d %H:%M:%S")
      if processing.size > 4
        processing.each do |log|
          c = log[:action][:request][:controller]
          a = log[:action][:request][:action]
          f = if f = log[:action][:request][:format]
                " #{f}"
              end
          key = "#{c}##{a}#{f}"
          data[key] += 1
        end
      end
    end
    File.open('out/busy_actions', 'w') do |f|
      data.each do |k, v|
        f.puts("#{k}: #{v}")
      end
    end
  end

  task :busy_actions_chart do
    data = File.new('out/busy_actions').map do |l|
      l.split(': ')
    end.map {|k, v| [k, v.to_i]}
    all = data.map{|k,v| v}.reduce(:+)
    chart = data.sort_by{|k,v| v}.reverse.first(10).map do |k, v|
      # x = (v * 10000/all).to_f/100
      [k.gsub('Controller', ''), v]
    end
    chart.unshift(['Request', 'Count'])
    puts all
    p chart
  end

  task :busy_actions_rate do
    data = File.new('out/busy_actions').map do |l|
      l.split(': ')
    end.map {|k, v| [k, v.to_i]}
    all = data.map{|k,v| v}.reduce(:+)
    data.sort_by{|k,v| v}.reverse.each do |k, v|
      puts "#{k}: #{'%.2f' % (v.to_f * 100/all)}"
    end
  end

  task :processing_rate, [:dirs, :threshold, :logdetails] do |_, args|
    dirs = args.dirs || 'log/**/*'
    threshold = (args.threshold || 3).to_i
    logdetails = args.logdetails == 'true'
    stream = dumpling_logs.actions_stream(dirs).map(&processing_rate_analysis).compact
    File.open('out/processing_rate', 'w') do |f|
      stream.each do |time, processing|
        t = time.strftime("%Y-%m-%d %H:%M:%S")
        if processing.size > threshold
          puts "#{t}: #{'.' * processing.size}"
          if logdetails
            processing.each do |log|
              puts "\t#{log[:action][:response][:url]}"
            end
          end
        end
        f.write("#{t},#{processing.size}\n")
      end
    end
  end

  task :test, [:dirs] do |_, args|
    s = dumpling_logs.actions_stream(args.dirs)
    File.open('test.log', 'w') do |f|
      s.each do |action|
        f.puts action[:logs].last[:origin]
      end
    end
  end

  task :slow_requests, [:threshold] do |_, args|
    threshold = args.threshold.to_i * 1000
    stream = dumpling_logs.actions_stream.select{|a| a[:response][:completed_time].to_i > threshold}.each do |a|
      puts "#{a[:request][:timestamp]} #{a[:request][:controller]}##{a[:request][:action]} => #{a[:response][:completed_time]}"
      puts "\t#{a[:request][:remote_addr]}"
      puts "\t#{a[:response][:url]}"
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
