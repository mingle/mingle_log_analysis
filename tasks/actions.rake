
desc "show actions in request time order by given log dir"
task :actions, [:log_dirs] do |_, args|
  MingleSaasLogParser.new.actions_stream(log_dirs(args)).each do |action|
    timestamp = action[:request][:timestamp]
    puts "#{timestamp}: #{action[:response][:completed_time]} #{action[:response][:url]}"
  end
end

task :redirect_actions, [:log_dirs] do |_, args|
  data = Hash.new{|h,k|h[k]=0}
  puts ""
  count = 0
  MingleSaasLogParser.new.actions_stream(log_dirs(args)).each do |action|
    next if action[:request][:format] == 'xml'
    count += 1
    if action[:response][:code] == '302'
      data[request_action(action)] += 1
      print '.'
    end
  end
  redirect_count = data.values.reduce(:+)
  puts "[DEBUG]data => #{data.inspect}"
  puts count
  puts redirect_count
  puts redirect_count.to_f/count
end

task :cards_list do
  time_window = 3600
  MingleSaasLogParser.new.sliced_actions_stream(time_window).each do |range, actions|
    rate = cards_list_redirect_rate(actions)
    puts "#{range}: #{"%.2f" % (rate * 100)}"
  end
end

def cards_list_redirect_rate(actions)
  count = 0
  redirect_count = 0
  actions.each do |action|
    next if action[:request][:format] == 'xml'
    case request_action(action)
    when 'CardsController#list'
      count += 1
    when 'FavoritesController#show'
      redirect_log = action[:logs].detect{|l| l[:message] =~ /Redirected to https:\/\//}
      if redirect_log && redirect_log[:message] =~ /\/cards\?/
        redirect_count += 1
      end
    end
  end
  redirect_count.to_f/count
end
