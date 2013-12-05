
desc "response times, default range window: 1 day, default avg response time window: 60 seconds"
task :response_times do
  time_window = 3600 * 24 # 1 day
  avg_time_window = 60    # 1 minute

  stream = MingleSaasLogParser.new.sliced_actions_stream(time_window).map do |args|
    range, actions = args
    avgs = actions.lazy.chunk(&Evidence.by_time_window(avg_time_window)).map do |args|
      range, avg_actions = args
      avg_actions.map {|a|a[:response][:completed_time].to_i}.to_scale.mean
    end
    {range: range, avgs: avgs}
  end

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
