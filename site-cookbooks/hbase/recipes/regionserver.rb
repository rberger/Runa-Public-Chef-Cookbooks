#
# Author:: Robert J. Berger (rberger@runa.com)
# Cookbook Name:: hbase
# Recipe:: regionserver
#
# Copyright 2010, Runa, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "java"
Chef::Log.debug("Top of hbase::regionserver")

search(:apps) do |app|
  next unless app['hbase_regionserver_role']
  (app['hbase_regionserver_role'] & node.run_list.roles).each do |hbase_role|
    hadoop = app[:hadoop]
    hbase = app[:hbase]
    hbase_dir = hbase[:home]
    
    template "/etc/init.d/hbase_regionserver" do
      source "regionserver_init_d.erb"
      mode 0755
      owner 'root'
      group 'root'
      variables(
        :hbase_dir => hbase_dir,
        :hadoop_user => hadoop['user']
      )
    end

    execute " update hbase_regionserver init file" do
      command "update-rc.d hbase_regionserver defaults 27"
    end
  end
end