resource_name :hubot_instance
provides :hubot_instance

property :name, String, name_property: true
property :prefix, String, default: '/opt'
property :adapter, String, default: 'slack'
property :external_scripts, Hash, default: Hash.new
property :environment, Hash, default: Hash.new

action :create do

  if external_scripts.key?('hubot-slack') || external_scripts.key?('hubot-hipchat')
    raise 'Adapters are different from external scripts. They are already included in the dependency set, and they do not provide exports in the same format as external scripts. They must not be included this way.'
  end

  if adapter == 'slack' && ! environment.key?('HUBOT_SLACK_TOKEN')
    raise 'Missing HUBOT_SLACK_TOKEN in environment variables'
  end

  if adapter == 'slack'
    Chef::Log.warn('When using hubot-slack, hubot ignores --name and instead uses the name configured on the Slack integration.')
  end

  # The user and group are created in the ::default recipe
  install_user = 'hubot'
  install_group = 'hubot'
  install_dir = "#{prefix}/hubot-#{name}"

  directory install_dir do
    owner install_user
    group install_group
    recursive false
    mode  0755
  end

  template "#{install_dir}/package.json" do
    cookbook 'nicwaller_hubot'
    source 'package.json.erb'
    owner install_user
    group install_group
    mode 0444
    variables ({
      'external_script_dependencies' => external_scripts,
    })
    notifies :run, 'execute[npm install]', :immediately
  end

  # Now we re-run npm install to pick up the additional dependencies we've requested
  # TODO: does this need a unique name, or does the custom resource isolate us?
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

  file "#{install_dir}/external-scripts.json" do
    owner install_user
    group install_group
    mode 0444
    content external_scripts.keys.to_json
    notifies :restart, 'service[hubot]', :delayed
  end

  remote_directory "#{install_dir}/scripts" do
    cookbook 'nicwaller_hubot'
    source 'scripts'
    purge true
    owner install_user
    group install_group
    mode 0555
    files_owner install_user
    files_group install_group
    files_mode 0444
    action :create
    notifies :restart, 'service[hubot]', :delayed
  end

  service_name = "hubot-#{name}"
  hubot_name = name

  template "/etc/init.d/#{service_name}" do
    cookbook 'nicwaller_hubot'
    source 'sysvinit.erb'
    mode '0755'
    variables({
      'hubot_name'    => hubot_name,
      'adapter'       => adapter,
      'pidfile'       => "/var/run/hubot/#{service_name}",
      'logfile'       => "/var/log/hubot/#{service_name}",
      'user'          => install_user,
      'install_dir'   => install_dir,
      'environment'   => environment,
    })
    notifies :restart, 'service[hubot]', :delayed
  end

  # TODO: use systemd on Ubuntu 16
  service 'hubot' do
    service_name service_name
    action [:enable, :start]
  end

end