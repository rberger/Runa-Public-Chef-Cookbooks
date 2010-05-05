#
# Author:: Robert J. Berger (rberger@runa.com)
# Cookbook Name:: hadoop
# Recipe:: slave
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
Chef::Log.debug("Top of hadoop::slave")

search(:apps) do |app|
  next unless app['hadoop_slave_role']
  (app['hadoop_slave_role'] & node.run_list.roles).each do |hadoop_role|
    hadoop = app[:hadoop]
    hadoop_dir = hadoop[:home]

    template "/etc/init.d/hadoop_datanode" do
      source "slave_datanode_init_d.erb"
      mode 0755
      owner 'root'
      group 'root'
      variables(
        :hadoop_dir => hadoop_dir,
        :hadoop_user => hadoop['user']
      )
    end
    
    execute " update hadoop_datanode init file" do
      command "update-rc.d hadoop_datanode defaults 25"
    end

    template "/etc/init.d/hadoop_tasktracker" do
      source "slave_tasktracker_init_d.erb"
      mode 0755
      owner 'root'
      group 'root'
      variables(
        :hadoop_dir => hadoop_dir,
        :hadoop_user => hadoop['user']
      )
    end

    execute " update hadoop_tasktracker init file" do
      command "update-rc.d hadoop_tasktracker defaults 26"
    end
  end
end