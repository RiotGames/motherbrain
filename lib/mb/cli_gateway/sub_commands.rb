Dir["#{File.dirname(__FILE__)}/sub_commands/*.rb"].sort.each do |path|
  require "mb/cli_gateway/sub_commands/#{File.basename(path, '.rb')}"
end
