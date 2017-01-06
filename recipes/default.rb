#
# Cookbook Name:: nicwaller_hubot
# Recipe:: default
#

# I would rather put this in the custom resource, but there's a bug in Chef which
# prevents custom resources from being able to reliably include recipes. >:[
include_recipe 'nodejs::default'

# Strangely enough, the nodejs cookbook fails to install npm on Ubuntu 16.04
if node['platform'] == 'ubuntu' && node['platform_version'] == '16.04'
  package 'npm'
else
  include_recipe 'nodejs::npm'
end

# I thought about creating new system users for each Hubot personality... but why?
# So instead I just create one user, the hubot user.
user 'hubot' do
  comment 'Hubot User'
end

group 'hubot' do
  members ['hubot']
end

directory '/var/log/hubot' do
  owner 'hubot'
  group 'hubot'
  mode  0755
  action :create
end

directory '/var/run/hubot' do
  owner 'hubot'
  group 'hubot'
  mode  0755
  action :create
end
