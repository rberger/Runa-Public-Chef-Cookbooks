maintainer       "Robert J. Berger Runa Inc."
maintainer_email "ops@runa.com"
license          "Apache 2.0"
description      "Installs/Configures hadoop for the matching HBase Recipe using a common Databag for configuration"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

%w{ java ssh_known_hosts }.each do |cb|
  depends cb
end
