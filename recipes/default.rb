#
# Cookbook Name:: nicwaller_hubot
# Recipe:: default
#

include_recipe 'git::default'
include_recipe 'nodejs'

hubot_user = 'hubot'
hubot_group = 'hubot'
hubot_dir = '/opt/hubot'

user hubot_user do
  comment 'Hubot User'
  home hubot_dir
end

group hubot_group do
  members [hubot_user]
end

directory hubot_dir do
  owner hubot_user
  group hubot_group
  recursive false
  mode  0755
end

git hubot_dir do
  repository 'https://github.com/github/hubot.git'
  revision node[cookbook_name]['hubot_version']
  action :checkout
  notifies :run, 'execute[build and install hubot]', :immediately
end

# Amazingly, the Chef 'git' resource allows us to stomp over any files we like, and it will still update the rest

execute 'build and install hubot' do
  command <<-EOH
npm install
bin/hubot -c #{hubot_dir}
chown #{hubot_user}:#{hubot_group} -R #{hubot_dir}
chmod 0755 #{hubot_dir}/bin/hubot
  EOH
  cwd hubot_dir
  environment(
    'PATH' => "#{hubot_dir}/node_modules/.bin:#{ENV['PATH']}"
  )
  action :nothing
end

# We could specify a version constraint here... or just let npm try to work it out. ¯\_(ツ)_/¯
external_scripts = [
  'hubot-ambush',
  'hubot-calculator',
  'hubot-help',
  'hubot-leaderboard',
  'hubot-pager-me',
  'hubot-commit-streak',
  'hubot-thecat',
  'hubot-rss-reader',
  'hubot-google-images',
  'hubot-google-translate',
  'hubot-google-hangouts',
  'hubot-pugme',
  'hubot-rules',
  'hubot-slack',
  'hubot-streetfood',
  'hubot-google',
  'hubot-xkcd',
  'hubot-maps',
]

template "#{hubot_dir}/package.json" do
  source 'package.json.erb'
  owner hubot_user
  group hubot_group
	mode 0444
  variables ({
    'version' => node[cookbook_name]['hubot_version'],
    'dependencies' => external_scripts.map { |package| [package, '*'] }.to_h,
  })
  notifies :run, 'execute[npm install]', :immediately
end

file "#{hubot_dir}/external-scripts.json" do
  owner hubot_user
  group hubot_group
  mode 0444
  content external_scripts.to_json
  notifies :restart, 'service[hubot]', :delayed
end

# TODO: isn't there some other way to ensure coffee-script is available?
execute 'hubot_coffee_script' do
  command 'npm install -g coffee-script'
end

# Now we re-run npm install to pick up the additional dependencies we've requested
execute 'npm install' do
  command 'npm install'
  cwd hubot_dir
  user hubot_user
  group hubot_group
  environment(
    'USER' => hubot_user,
    'HOME' => hubot_dir,
  )
  action :nothing
  notifies :restart, 'service[hubot]', :delayed
end

hubot_environment = {
  'HUBOT_WEATHER_CELSIUS' => 'true',
  'HUBOT_SLACK_TOKEN' => 'xoxb-YOUR-TOKEN-HERE',
}

template '/etc/init.d/hubot' do
  source 'sysvinit.erb'
  mode '0755'
  variables({
    'pidfile'       => '/var/run/hubot',
    'user'          => hubot_user,
    'install_dir'   => hubot_dir,
    'environment'   => hubot_environment,
  })
end

# TODO: use systemd on Ubuntu 16
service 'hubot' do
  action [:enable, :start]
end