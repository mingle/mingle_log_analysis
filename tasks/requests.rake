
desc "Show all requests that completed time is larger than given threshold"
task :slow_requests, [:threshold] do |_, args|
  threshold = args.threshold.to_i * 1000
  stream = MingleSaasLogParser.new.actions_stream.select{|a| a[:response][:completed_time].to_i > threshold}.each do |a|
    puts "#{a[:request][:timestamp]} #{a[:request][:controller]}##{a[:request][:action]} => #{a[:response][:completed_time]}"
    puts "\t#{a[:request][:remote_addr]}"
    puts "\t#{a[:response][:url]}"
  end
end
