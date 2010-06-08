maintainer       "Robert J. Berger Runa Inc."
maintainer_email "ops@runa.com"
license          "Apache 2.0"
description      "Installs/Configures hbase using a Databag for configuration. Expects Hadoop to be set up with the hadoop_for_hbase recipe"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

%w{ java hadoop }.each do |cb|
  depends cb
end
