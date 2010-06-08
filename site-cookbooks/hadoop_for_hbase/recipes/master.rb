#
# Author:: Robert J. Berger (rberger@runa.com)
# Cookbook Name:: hadoop
# Recipe:: master
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
Chef::Log.debug("Top of hadoop::master")

search(:apps) do |app|
  next unless app['hadoop_master_role']
  (app['hadoop_master_role'] & node.run_list.roles).each do |hadoop_role|
    hadoop = app[:hadoop]
    hadoop_dir = hadoop[:home]
    
    execute "Format hadoop file system" do
      command "#{hadoop_dir}/bin/hadoop namenode -format"
      creates "#{hadoop_dir}/dfs/name"
    end

    template "/etc/init.d/hadoop_master" do
      source "master_init_d.erb"
      mode 0755
      owner 'root'
      group 'root'
      variables(
        :hadoop_dir => hadoop_dir,
        :hadoop_user => hadoop['user']
      )
    end

    service "hadoop_master" do
      supports :restart => true
      action [ :enable, :start ]
    end
  end
end