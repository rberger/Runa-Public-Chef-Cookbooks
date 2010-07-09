#
# Cookbook Name:: leiningen
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
execute "lein_self_install" do
  command "lein self-install"
  user "root"
  group "root"
  action :nothing
end

remote_file "/usr/local/bin/lein" do
  source "http://github.com/technomancy/leiningen/raw/stable/bin/lein"
  mode "755"
  # checksum "87feb27f7ec25fc7cc3d6427f369feb710d01278"
  owner "root"
  group "root"
  backup false
  notifies :run, resources(:execute => "lein_self_install"), :immediately
end

