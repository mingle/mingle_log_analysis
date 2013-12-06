
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
task :processing_rate, [:log_dirs, :threshold, :logdetails, :start_at] do |_, args|
  dirs = log_dirs(args)
  threshold = (args.threshold || 3).to_i
  logdetails = args.logdetails == 'true'
  start_at = args.start_at ? Time.parse(args.start_at) : nil
  stream = MingleSaasLogParser.new.actions_stream(dirs).map(&request_processing_analysis).compact
  File.open('out/processing_rate', 'w') do |f|
    stream.each do |time, processing|
      if start_at && time < start_at
        next
      end
      t = time.strftime("%Y-%m-%d %H:%M:%S")
      if processing.size > threshold
        puts "#{t}: #{'.' * processing.size}"
        if logdetails
          processing.each do |log|
            # puts log[:action].inspect
            puts "\t#{log[:action][:request][:remote_addr]} #{log[:action][:response][:completed_time].to_f/1000}s since #{log[:action][:request][:timestamp]}"
          end
        end
      end
      f.write("#{t},#{processing.size}\n")
    end
  end
end


task :processing_rate_per_client, [:log_dirs] do |_, args|
  dirs = log_dirs(args)
  threshold = 2
  logdetails = false
  stream = MingleSaasLogParser.new.actions_stream(dirs).map(&request_processing_analysis).compact
  File.open('out/processing_rate_per_client', 'w') do |f|
    stream.each do |time, processing|
      t = time.strftime("%Y-%m-%d %H:%M:%S")
      gg = processing.group_by do |a|
        a[:action][:request][:remote_addr]
      end
      gg.select do |remote_addr, actions|
        if actions.size > threshold
          puts "#{t} (#{remote_addr}): #{'.' * actions.size}"
          if logdetails
            actions.each do |log|
              # puts log[:action].inspect
              puts "\t#{log[:action][:request][:remote_addr]} #{log[:action][:response][:completed_time].to_f/1000}s since #{log[:action][:request][:timestamp]}"
            end
          end
          f.write("#{t},#{remote_addr},#{processing.size}\n")
        end
      end

    end
  end
end
