#!/usr/bin/env ruby
require 'rubygems'
require 'thor'
require 'fog'
require 'pp'

class CloudfileTools < Thor

  ## server params
  #@rackspace_username = ARGV
  #@rackspace_api_key  = ARGV
  #@flavor             = ""
  #@image              = ""
  #@name               = ""
  #@key_private        = ""
  #@key_public         = ""

  class_option :user, :aliases => "-u", :desc => "rackspace username"                
  class_option :key, :aliases => "-k", :desc => "rackspace API key"
  class_option :config_file, :default => "./config.yml", :aliases => "-c", :desc => "file of configuration options"
  
  no_tasks do  
    def connect  
      if options['user'] && options['key']
        # assemble hash of rackspace api credentials
        @@rackspace_credentials = {
          :provider           => 'Rackspace',
          :rackspace_username => options['user'],
          :rackspace_api_key  => options['key']
        }    
      else
        exit
      end    
    end  
  end
  ## 
  ## start command
  ##
  desc "start", "start server build"
  ## command options
  method_option :image_id, :required => true, :aliases => "-i", :desc => "which server image to use"                
  method_option :flavor_id, :required => true, :aliases => "-f", :desc => "server flavor to use"      
  method_option :name, :required => true, :aliases => "-n", :desc => "server name to use"      

  def start
    # code to build server
    puts "rackspace server build"
    puts "===================="
    puts "STARTING....."
    compute = authenticate(options[:config_file])
   
    server = compute.servers.create(
      :image_id        => options['image_id'], 
      :flavor_id       => options['flavor_id'], 
      :name            => options['name']
    )
   
    puts "NEW SERVER INFO"
    puts "===================="
    puts "building new server.....please wait"
    
  
    pp server
    puts "address: " + server.public_ip_address
    puts "root: " + server.password
    server.wait_for { ready? }
    server.private_key = IO.read( File.expand_path('~/.ssh/id_rsa') )
    server.public_key = IO.read( File.expand_path('~/.ssh/id_rsa.pub') )
    server.username = 'root'
    server.setup :password => server.password 
    #server.ssh ["echo '#{user_data}' > /root/bootstrap.sh", "chmod +x /root/bootstrap.sh", "/root/bootstrap.sh &"]
    
    # create a named user for deploys, add them to the user group, set default password
    server.ssh ["groupadd web", "useradd #{@@config['newuser_name']} -g web", "echo #{@@config['newuser_passwd']} | passwd #{@@config['newuser_name']}  --stdin;"]
    server.ssh ["mkdir /home/#{@@config['newuser_name']}/.ssh", "chmod 700 /home/#{@@config['newuser_name']}/.ssh", "chown #{@@config['newuser_name']}.web /home/#{@@config['newuser_name']}/.ssh"]

    puts "===================="
    puts "SERVER READY"
    puts "===================="
  end
  
  ##
  ## list containers
  ##
  method_option :region, :aliases => "-r", :desc => "region"
  desc "list_containers", "list containers"
  def list_containers
    puts "list_containers"    
    puts "===================="
    storage = authenticate(options[:config_file], options[:region]) 
    pp storage.directories    
  end
  
  ##
  ## list files
  ##
  method_option :region, :required => true, :aliases => "-r", :desc => "region"
  method_option :container, :required => true, :aliases => "-c", :desc => "container"
  desc "list_files", "list files in container"
  def list_files
    puts "list_files"    
    puts "===================="
    storage = authenticate(options[:config_file], options[:region]) 
    directory = storage.directories.get(options["container"])
    directory.files.each do |file|
      pp file.key
    end
  end
  
  ##
  ## put file
  ## 
  desc "put_file", "save file to container"
  def put_file
    puts "put file"
    puts "===================="
    # connect
    storage = authenticate(options[:config_file])   

    # open container 
    directory = storage.directories.get(options[:container])

    # check file exists
    File.open(options[:file], "rb") do |io|
      directory.files.create(:key  => File.basename(options[:file]),
                             :body => io)
    end
    #File.open(options[:file])    
    # get file and send to cloudfiles
    #file = directory.files.create(
    #  :key    => File.basename(options[:file]),
    #  :body   => File.open(options[:file])
    #)
  end
  
  
 private
  
  def authenticate(file_name, region = '', service_net = false)
    # load the configuration file with connection parameters
    @@config ||= YAML.load_file(file_name)
    # init the databasedotcom gem with the specified yml config file
    if @@config['user'] && @@config['key']
      rackspace_credentials = {
        :provider           => 'Rackspace',
        :rackspace_username => @@config['user'],
        :rackspace_api_key  => @@config['key']
      }
    end
        
    rackspace_credentials.merge!({:rackspace_region  => region.downcase.to_sym}) if !region.nil?
    rackspace_credentials.merge!({:rackspace_servicenet  => service_net}) if !service_net.nil? 
    
    pp rackspace_credentials
    
    client = Fog::Storage.new(rackspace_credentials)
    return client
  end

  
end

CloudfileTools.start