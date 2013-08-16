require 'evidence'

class MingleSaasLogParser
  include Evidence

  def sliced_actions_stream(time_window)
    actions_stream.chunk(&by_time_window(time_window))
  end

  def actions_stream
    Dir['log/dumpling/*'].sort.lazy.map do |dir|
      logs = Dir["#{dir}/*"].select{|f| f=~/mingle-cluster/}.reject(&background_log_files)
      logs.lazy.map do |f|
        File.new(f).lazy.map(&parse_log(request_log_pattern)).compact.
          map(&rails_action_parser(pid, message)).compact.
          map(&request_timestamp_parser)
      end.flat_map { |a| a }.sort_by {|a| a[:request][:timestamp]}
    end.flat_map {|a| a}
  end

  def background_log_files
    lambda do |f|
      File.new(f).first(100).any? do |l|
        l =~ background_log_pattern
      end
    end
  end

  def pid
    lambda {|log| "#{log[:host_name]}-#{log[:thread_label]}"}
  end

  def message
    lambda {|log| log[:message]}
  end

  def request_log_pattern
    /^
      \w{3}\s+\d+\s+\d{2}\:\d{2}\:\d{2}\s+
      (?<host_name>[^\s]+)\s+
      [-_\w]+\:\s+
      INFO\s+
      \[(?<timestamp>[^\]]+)\]\s+
      \[(?<thread_label>[^\]]+)\]\s+
      \[(?<log4j_label>[^\]]+)\]\s+
      \[tenant\:(?<tenant>[^\]]*)\]\s+
      (?<message>.*)
    $/x
  end

  def background_log_pattern
    /^
      \w{3}\s+\d+\s+\d{2}\:\d{2}\:\d{2}\s+
      (?<host_name>[^\s]+)\s+
      [-_\w]+\:\s+
      INFO\s+
      \[(?<timestamp>[^\]]+)\]\s+
      \[[-_\d\w]+\[(?<thread_label>[^\]]+)\]\]\s+
      \[(?<log4j_label>[^\]]+)\]\s+
      \[tenant\:(?<tenant>[^\]]*)\]\s+
      (?<message>.*)
    $/x
  end
end
