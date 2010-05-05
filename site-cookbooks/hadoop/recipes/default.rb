#
# Cookbook Name:: hadoop
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
include_recipe "ssh_known_hosts"
Chef::Log.debug("Top of hadoop::default")

search(:apps) do |app|
  next unless app['hbase_master_role'] || app['hbase_regionserver_role']
  (node.run_list.roles & (app['hbase_master_role'] | app['hbase_regionserver_role'])).each do |hadoop_role|
    top = app['hadoop']['top']
    hadoop = app[:hadoop]
    hadoop_dir = hadoop[:home]
    hadoop_user_home = hadoop[:user_home]
    hbase = app[:hbase]
    hbase_dir = hbase[:home]
    zookeeper = app[:zookeeper]
    environment = node[:app_environment]
    i_am_master = (node.run_list.roles & app['hadoop_master_role']) ? true : false 
    
    Chef::Log.debug("Hadoop Before dir: app['id']: #{app['id'].inspect} #{top}/tars")
    # Place to put tars
    directory "#{top}/tars" do
      Chef::Log.debug("Hadoop Inside directory #{top}/tars")
      owner "#{app['owner']}"
      Chef::Log.debug("app['group']: #{app['group'].inspect}")
      group "#{app['group']}"
      mode "0755"
      recursive true
      action :create
      not_if "test -d #{top}/tars"
    end
    
    directory "#{top}/pkgs" do
      Chef::Log.debug("Hadoop Inside directory #{top}/pkgs")
      owner "#{app['owner']}"
      Chef::Log.debug("app['group']: #{app['group'].inspect}")
      group "#{app['group']}"
      mode "0755"
      recursive true
      action :create
      not_if "test -d #{top}/pkgs"
    end
    
    remote_file "#{top}/tars/hadoop-#{hadoop['revision'][environment]}.tar.gz" do
      source "http://runa-pkgs.s3.amazonaws.com/hadoop-#{hadoop['revision'][environment]}.tar.gz"
      mode "0744"
      not_if "test -f #{top}/tars/hadoop-#{hadoop['revision'][environment]}.tar.gz"
    end

    execute "Un tar hadoop-#{hadoop['revision'][environment]}.tar.gz" do
      cwd "#{top}/pkgs"
      command "tar -xvvzf #{top}/tars/hadoop-#{hadoop['revision'][environment]}.tar.gz"
      creates "#{top}/pkgs/hadoop-#{hadoop['revision'][environment]}"  
      user "#{app['owner']}"
      action :run
    end

    link "#{hadoop_dir}" do
      to "#{top}/pkgs/hadoop-#{hadoop['revision'][environment]}"
    end

    #Creating Hadoop User

    user hadoop[:user] do
      comment "Hadoop User"
      home "#{hadoop_user_home}"
      shell "/bin/bash"
      supports :manage_home => true
    end

    directory "#{hadoop_user_home}/.ssh" do
      owner hadoop[:user]
      group hadoop[:group]
      mode "0700"
      action :create
    end

    directory "#{hadoop_dir}/logs" do
      owner hadoop[:user]
      group hadoop[:group]
      mode "0755"
      recursive true
      action :create
      not_if "test -d #{hadoop_dir}/logs"
    end
    
    # Change the owner to Hadoop User
    execute "Changing the ownership / group for Hadoop folders" do
      command "chown -R #{hadoop[:user]}:#{hadoop[:group]} #{hadoop_dir}/"
      action :run
    end

    #Upload Keys for Hadoop User
    remote_file "#{hadoop_user_home}/.ssh/id_dsa" do
      owner hadoop[:user]
      group hadoop[:group]
      source "id_dsa_hadoop"
      mode "0600"
      checksum "a8b3039e1c526b476f7d641069dbee6c989a6ac418158a111f06a093613df9a4"
    end

    remote_file "#{hadoop_user_home}/.ssh/id_dsa.pub" do
      owner hadoop[:user]
      group hadoop[:group]
      source "id_dsa_hadoop.pub"
      mode "0600"
      checksum "43c8bc32cd8ff5c494b0dae24af90215222b650a8b4a07a79e8854aa4fce8a13"
    end

    file "#{hadoop_user_home}/.ssh/authorized_keys" do
      owner hadoop[:user]
      group hadoop[:group]
      mode "0600"
    end
    
    execute "Appending to Authorized Keys" do
      command "cat #{hadoop_user_home}/.ssh/id_dsa.pub >> #{hadoop_user_home}/.ssh/authorized_keys"
      user hadoop[:user]
      group hadoop[:group]
      action :run
      not_if "grep -q 'hadoop_user' #{hadoop_user_home}/.ssh/authorized_keys"
    end

    template "#{hadoop_dir}/conf/hadoop-env.sh" do
      source "hadoop-env.sh.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
        :hbase_home => hbase_dir,
        :hbase_version => hbase[:revision][environment],
        :zookeeper_version => zookeeper[:revision][environment]
      )
    end

    # Get the node of the hadoop master
    hadoop_master = nil
    # If we are the hadoop master
    if node.run_list.roles.include?(app["hadoop_master_role"][0])
      hadoop_master = node
    else
    # Find the hadoop master
      results = search(:node, "run_list:role\\[#{app["hadoop_master_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1)
      Chef::Log.debug("------ results.length: #{results.length}")
      rows = results[0]
      Chef::Log.debug("------ results.length: #{results.length}")
      if rows.length == 1
        hadoop_master = rows[0]
      end
    end

    Chef::Log.debug("Before template #{hadoop_dir}/conf/core-site.xml")
    template "#{hadoop_dir}/conf/core-site.xml" do
      source "core-site.xml.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
        :hadoop_master_host => hadoop_master['fqdn']
      )
    end

    template "#{hadoop_dir}/conf/hadoop-metrics.properties" do
      source "hadoop-metrics.properties.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
        :hadoop_master_host => hadoop_master['fqdn']
      )
    end

    template "#{hadoop_dir}/conf/hdfs-site.xml" do
      source "hdfs-site.xml.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
      :hadoop_master_host => hadoop_master['fqdn'],
      :dfs_name_dir => "#{hadoop_dir}/dfs/name",
      :dfs_data_dir => "#{hadoop_dir}/dfs/data",
      :dfs_data_max_xcievers => 2048
      )
    end

    template "#{hadoop_dir}/conf/mapred-site.xml" do
      source "mapred-site.xml.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
      :hadoop_master_host => hadoop_master['fqdn']
      )
    end
    
    # Get the master nodes
    masters =[]
    search(:node, "run_list:role\\[#{app["hadoop_master_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1) do |master|
      masters << master['fqdn'].strip unless masters.include?(master['fqdn'].strip)
    end
    template "#{hadoop_dir}/conf/masters" do
      source "masters.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
      :masters => masters
      )
    end

    # Get the slave nodes. Try several times to cover the lag of the slaves starting
    loop_count = i_am_master ? 10 : 0
    slaves = []
    while loop_count > 0
      search(:node, "run_list:role\\[#{app["hadoop_slave_role"][0]}\\] AND app_environment:#{node[:app_environment]}", nil, 0, 1) do |slave|
        slaves << slave['fqdn'].strip unless slaves.include?(slave['fqdn'].strip)
      end
      
      break unless slaves.empty?
      sleep 20 * loop_count
      loop_count -= 1
    end
    template "#{hadoop_dir}/conf/slaves" do
      source "slaves.erb"
      mode 0664
      owner hadoop[:user]
      group hadoop[:group]
      variables(
      :slaves => slaves
      )
    end
  end
end