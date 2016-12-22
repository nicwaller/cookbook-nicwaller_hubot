resource_name :hubot_instance
provides :hubot_instance

property :name, String, default: 'hubot', name_property: true
# It seems like :user is a reserved word that I just can't use.
property :install_user, String, default: 'hubot'
property :install_group, String, default: 'group'
property :install_dir, String, default: '/opt/hubot'
property :git_repository, String, default: 'https://github.com/github/hubot.git'
property :git_revision, String, default: 'v2.19.0'
property :external_scripts, Hash, default: Hash.new
property :environment, Hash, default: Hash.new
property :hubot_slack_token, String

action :create do

  user install_user do
    comment 'Hubot User'
    home install_dir
  end

  group install_group do
    members [install_user]
  end

  directory install_dir do
    owner install_user
    group install_group
    recursive false
    mode  0755
  end

  git install_dir do
    repository git_repository
    revision git_revision
    action :checkout
    notifies :run, 'execute[build and install hubot]', :immediately
  end

  # Amazingly, the Chef 'git' resource allows us to stomp over any files we like, and it will still update the rest

  execute 'build and install hubot' do
    command <<-EOH
  npm install
  bin/hubot -c #{install_dir}
  chown #{install_user}:#{install_group} -R #{install_dir}
  chmod 0755 #{install_dir}/bin/hubot
    EOH
    cwd install_dir
    environment(
      'PATH' => "#{install_dir}/node_modules/.bin:#{ENV['PATH']}"
    )
    action :nothing
  end

  template "#{install_dir}/package.json" do
    source 'package.json.erb'
    owner install_user
    group install_group
    mode 0444
    variables ({
      'version' => git_revision,
      'dependencies' => external_scripts,
    })
    notifies :run, 'execute[npm install]', :immediately
  end

  file "#{install_dir}/external-scripts.json" do
    owner install_user
    group install_group
    mode 0444
    content external_scripts.to_json
    notifies :restart, 'service[hubot]', :delayed
  end

  # Now we re-run npm install to pick up the additional dependencies we've requested
  execute 'npm install' do
    command 'npm install'
    cwd install_dir
    user install_user
    group install_group
    environment(
      'USER' => install_user,
      'HOME' => install_dir,
    )
    action :nothing
    notifies :restart, 'service[hubot]', :delayed
  end

  environment['HUBOT_SLACK_TOKEN'] = hubot_slack_token

  template '/etc/init.d/hubot' do
    source 'sysvinit.erb'
    mode '0755'
    variables({
      'pidfile'       => '/var/run/hubot',
      'user'          => install_user,
      'install_dir'   => install_dir,
      'environment'   => environment,
    })
  end

  # TODO: use systemd on Ubuntu 16
  service 'hubot' do
    action [:enable, :start]
  end

end