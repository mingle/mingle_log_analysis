require 'evidence'

class MingleSaasLogParser
  include Evidence

  def initialize(log_files)
    @files = Dir[log_files].select{|f| f =~ /mingle-cluster/}
  end

  def actions_stream
    stream(request_log_stream, rails_action_parser(pid, message))
  end

  def request_log_stream
    logs = @files.reject(&background_log_files).map do |f|
      stream(File.new(f), log_parser(request_log_pattern))
    end
    puts "request log files: #{logs.size}"
    merge_streams(logs, lambda {|log1, log2| log1[:timestamp] <=> log2[:timestamp]})
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
      [\w-_]+\:\s+
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
      [\w-_]+\:\s+
      INFO\s+
      \[(?<timestamp>[^\]]+)\]\s+
      \[[\w-_\d]+\[(?<thread_label>[^\]]+)\]\]\s+
      \[(?<log4j_label>[^\]]+)\]\s+
      \[tenant\:(?<tenant>[^\]]*)\]\s+
      (?<message>.*)
    $/x
  end
end
