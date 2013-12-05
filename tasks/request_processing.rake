
# stream analysis how many requests are processing on server when new
# request hit server
def request_processing_analysis
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

desc "busy actions: processing more than number of threshold actions at any time"
task :busy_actions, [:log_dirs,:threshold] do |_, args|
  threshold = args.threshold || 4
  stream = MingleSaasLogParser.new.actions_stream(log_dirs(args)).map(&request_processing_analysis).compact
  data = Hash.new {|h,k| h[k] = 0}
  stream.each do |time, processing|
    t = time.strftime("%Y-%m-%d %H:%M:%S")
    if processing.size > threshold
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

desc "Find out how many requests were processing on server for each time when a new request hit server"
task :processing_rate, [:log_dirs, :threshold, :logdetails] do |_, args|
  dirs = args.log_dirs || 'log/**/*'
  threshold = (args.threshold || 3).to_i
  logdetails = args.logdetails == 'true'
  stream = MingleSaasLogParser.new.actions_stream(dirs).map(&request_processing_analysis).compact
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
