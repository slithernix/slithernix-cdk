require 'pathname'

Pathname.glob('./widgets/*.rb').each do |f|
  require f
end
