
$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'time'
require 'evidence'
require 'mingle_saas_log_parser'
require 'json'
require 'fileutils'

require 'task_helper'

Dir.glob("./tasks/*.rake").each do |f|
  import f
end
