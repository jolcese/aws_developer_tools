define :cli_tools, :extension => '.zip' do
  require 'fileutils'

  package 'unzip'

  remote_file "/tmp/#{params[:name] + params[:extension]}" do
    source params[:source]
    use_conditional_get !node['aws_developer_tools']['force_download?']
    use_etag true
    use_last_modified false
    notifies :run, 'execute[cleanup old install ' + params[:name] + ']', :immediately
  end

  execute "cleanup old install #{params[:name]}" do
    cwd '/tmp'
    command "rm -rf #{params[:name]} && mkdir #{params[:name]}"
    action 'nothing'
    notifies :run, 'execute[extract the aws tool ' + params[:name] + ']', :immediately
  end

  execute "extract the aws tool #{params[:name]}" do
    cwd "/tmp/#{params[:name]}"
    command "unzip -o ../#{params[:name] + params[:extension]}"
    action 'nothing'
    notifies :run, 'ruby_block[copy the tools to the target directory ' + params[:name] + ']', :immediately
  end

  ruby_block "copy the tools to the target directory #{params[:name]}" do
    block do
      FileUtils.cd("/tmp/#{params[:name]}") do
        source = Dir['*'].detect { |file| File.directory? file }
        target = node['aws_developer_tools'][params[:name]]['install_target']

        Chef::Log.info "Checking for tools in #{source}"

        if source
          FileUtils.mkdir_p target

          FileUtils.cd(source) do
            Chef::Log.info "Attempting to copy files from #{FileUtils.pwd}"

            FileUtils.cp_r('.', target)
          end
        end
      end
    end
    action 'nothing'
    notifies :create, 'template[ec2_tools ' + params[:name] + ']', :immediately
    notifies :create, 'template[location ' + params[:name] + ']', :immediately
    notifies :create, 'template[' + params[:name] + '.sh]', :immediately
    notifies :create, 'template[aws_tools.sh ' + params[:name] + ']', :immediately
  end

  template "ec2_tools #{params[:name]}" do
    source "ec2_tools.sh.erb"
    path "/etc/profile.d/ec2_tools.sh"
    mode 0755
    only_if { AwsDeveloperTools.type?(params[:name]) == :ec2 }
    action 'nothing'
  end

  template "location #{params[:name]}" do
    source "credentials.erb"
    path "#{node['aws_developer_tools']['aws_tools_credentials']['location']}"
    mode node['aws_developer_tools']['aws_tools_credentials']['permission']
    not_if { AwsDeveloperTools.type?(params[:name]) == :ec2 }
    action 'nothing'
  end

  template "#{params[:name]}.sh" do
    source "#{params[:name]}.sh.erb"
    path "/etc/profile.d/#{params[:name]}.sh"
    mode 0755
    not_if { AwsDeveloperTools.type?(params[:name]) == :ec2 }
    action 'nothing'
  end

  template "aws_tools.sh #{params[:name]}" do
    source "aws_tools.sh.erb"
    path "/etc/profile.d/aws_tools.sh #{params[:name]}"
    mode 0755
    not_if { AwsDeveloperTools.type?(params[:name]) == :ec2 }
    action 'nothing'
  end

end
