
desc "show actions in request time order by given log dir"
task :actions, [:log_dirs] do |_, args|
  MingleSaasLogParser.new.actions_stream(log_dirs(args)).each do |action|
    timestamp = action[:request][:timestamp]
    puts "#{timestamp}: #{action[:response][:completed_time]} #{action[:response][:url]}"
  end
end
