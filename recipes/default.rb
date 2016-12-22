#
# Cookbook Name:: nicwaller_hubot
# Recipe:: default
#

include_recipe 'git::default'
include_recipe 'nodejs::default'

# Strangely enough, the nodejs cookbook fails to install npm on Ubuntu 16.04
if node['platform'] == 'ubuntu' && node['platform_version'] == '16.04'
  package 'npm'
else
  include_recipe 'nodejs::npm'
end

# Unconfirmed: Ubuntu 12.04 installs node 0.10 which is too old to run Hubot.
# Too bad though, because it takes a LOOOONG time to compile nodejs. (like half an hour)
if node['platform'] == 'ubuntu' && node['platform_version'] == '14.04' and node['nodejs']['install_method'] == 'package'
  raise 'The nodejs package provided in 14.04 is too old to run HipChat. Please install from source instead.'
end

# TODO: isn't there some other way to ensure coffee-script is available?
execute 'hubot_coffee_script' do
  command 'npm install -g coffee-script'
end

# We could specify a version constraint here... or just let npm try to work it out. ¯\_(ツ)_/¯
# It is an error to include hubot-hipchat or hubot-slack in external_scripts. Don't do it. It's only a dependency.
# todo: throw an exception if somebody tries to do that
external_scripts = {
  # 'hubot-hipchat' => '2.12.0', # This crashes
  # 'hubot-slack' => '4.2.1',
  'hubot-help' => '0.2.0',
  'hubot-pugme' => '0.1.0',
  'hubot-xkcd' => '0.0.3',
}

hubot_instance 'hubot' do
  action :create
  external_scripts external_scripts
  hubot_slack_token 'xoxb-YOUR-TOKEN-HERE'
end