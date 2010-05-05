#
# Cookbook Name:: hbase
# Recipe:: default
#
# Copyright 2010, Runa Inc.
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

Chef::Log.debug("Top of hbase::default")

search(:apps) do |app|
  next unless app['hbase_master_role'] || app['hbase_regionserver_role']
  (node.run_list.roles & (app['hbase_master_role'] | app['hbase_regionserver_role'])).each do |hbase_role|
    Chef::Log.debug("hbase_role: #{hbase_role.inspect}")
    top = app['hbase']['top']
    hadoop = app[:hadoop]
    hadoop_dir = hadoop[:home]
    hadoop_user_home = hadoop[:user_home]
    hbase = app[:hbase]
    hbase_dir = hbase[:home]
    zookeeper = app[:zookeeper]
    environment = node[:app_environment]
    i_am_master = (node.run_list.roles & app['hbase_master_role']) ? true : false 
    
    # Place to put tars
    directory "#{top}/tars" do
      owner "#{app['owner']}"
      group "#{app['group']}"
      mode "0755"
      recursive true
      action :create
      not_if "test -d #{top}/tars"
    end

    remote_file "#{top}/tars/hbase-#{hbase[:revision][environment]}.tar.gz" do
      source "http://runa-pkgs.s3.amazonaws.com/hbase-#{hbase[:revision][environment]}.tar.gz"
      mode "0744"
      not_if "test -f #{top}/tars/hbase-#{hbase[:revision][environment]}.tar.gz"
    end

    directory "#{top}/pkgs" do
      owner "#{app['owner']}"
      group "#{app['group']}"
      mode "0755"
      recursive true
      action :create
      not_if "test -d #{top}/pkgs"
    end
    
    execute "Un tar hbase-#{hbase[:revision][environment]}.tar.gz" do
      cwd "#{top}/pkgs"
      user "#{app['owner']}"
      command "tar -xvvzf #{top}/tars/hbase-#{hbase[:revision][environment]}.tar.gz"
      creates "#{top}/pkgs/hbase-#{hbase[:revision][environment]}"  
      action :run
    end

    link "#{hbase_dir}" do
      to "#{top}/pkgs/hbase-#{hbase[:revision][environment]}"
    end

    directory "#{hbase_dir}/logs" do
      owner hadoop[:user]
      group hadoop[:group]
      mode "0755"
      recursive true
      action :create
      not_if "test -d #{hbase_dir}/logs"
    end
    
    execute "Changing the ownership group for Hbase folders" do
      command "chown -R #{hadoop[:user]}:#{hadoop[:group]} #{hbase_dir}/"
      action :run
    end

    # Get the node of the hbase master
    hbase_master = nil
    # If we are the hbase master
    if node.run_list.roles.include?(app["hbase_master_role"][0])
      hbase_master = node
    else
    # Find the hbase master
      results = search(:node, "run_list:role\\[#{app["hbase_master_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1)
      rows = results[0]
      if rows.length == 1
        hbase_master = rows[0]
      end
    end

    # Get the zookeeper nodes
    zookeepers = search(:node, "run_list:role\\[#{app["zookeeper_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1)

    template "#{hbase_dir}/conf/hbase-site.xml" do
      source "hbase-site.xml.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
        :hbase_master_host => hbase_master['fqdn'],
        :zookeeper_quorum => zookeepers[0].map{ |zk| zk['fqdn'] }.join(",")
      )
    end

    template "#{hbase_dir}/conf/hbase-env.sh" do
      source "hbase-env.sh.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
        :hbase_dir => hbase_dir
      )
    end

    # Get the regionserver nodes. Try several times to cover the lag of the regionservers starting
    loop_count = i_am_master ? 10 : 0
    regionservers = []
    while loop_count > 0
      search(:node, "run_list:role\\[#{app["hbase_regionserver_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1)  do |regionserver|
        regionservers << regionserver['fqdn'].strip unless regionserver.include?(regionserver['fqdn'].strip)
      end

      break unless regionservers.empty?
      sleep 20 * loop_count
      loop_count -= 1
    end

    Chef::Log.debug("Before template conf/regionservers")
    template "#{hbase_dir}/conf/regionservers" do
      source "regionservers.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
        :regionservers => regionservers
      )
    end
  end
end