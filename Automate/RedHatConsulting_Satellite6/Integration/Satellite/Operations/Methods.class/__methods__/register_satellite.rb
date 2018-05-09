# Creates a Satellite host record for the given VM provisining request.
# The created host record is in build mode.
#
# EXPECTED
# @param miq_provision             Required. VM Provisining request to create the Satellite host record for.
# @param satellite_organization_id Required. Satellite Organization ID to register the VM with
# @param satellite_hostgroup_id    Required. Satellite Hostgroup ID to register the VM with
# @param satellite_domain_id       Required. Satellite Domain ID to register the VM with
# @param satellite_location_id     Optional. Satellite Location ID to register the VM with
#
# @see https://www.theforeman.org/api/1.14/index.html - POST /api/hosts 
#
@DEBUG = false

require 'apipie-bindings'

def dump_object(object_string, object)
  $evm.log("info", "Listing #{object_string} Attributes:") 
  object.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_current
  $evm.log("info", "Listing Current Object Attributes:") 
  $evm.current.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_root
  $evm.log("info", "Listing Root Object Attributes:") 
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

# There are many ways to attempt to pass parameters in Automate.
# This function checks all of them in priorty order as well as checking for symbol or string.
#
# Order:
#   1. Inputs
#   2. Current
#   3. Object
#   4. Root
#   5. State
#
# @return Value for the given parameter or nil if none is found
def get_param(param)  
  # check if inputs has been set for given param
  param_value ||= $evm.inputs[param.to_sym]
  param_value ||= $evm.inputs[param.to_s]
  
  # else check if current has been set for given param
  param_value ||= $evm.current[param.to_sym]
  param_value ||= $evm.current[param.to_s]
 
  # else cehck if current has been set for given param
  param_value ||= $evm.object[param.to_sym]
  param_value ||= $evm.object[param.to_s]
  
  # else check if param on root has been set for given param
  param_value ||= $evm.root[param.to_sym]
  param_value ||= $evm.root[param.to_s]
  
  # check if state has been set for given param
  param_value ||= $evm.get_state_var(param.to_sym)
  param_value ||= $evm.get_state_var(param.to_s)

  $evm.log(:info, "{ '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
end

# Function for getting the current VM and associated options based on the vmdb_object_type.
#
# Supported vmdb_object_types
#   * miq_provision
#   * vm
#   * automation_task
#
# @return vm,options
def get_vm_and_options()
  $evm.log(:info, "$evm.root['vmdb_object_type'] => '#{$evm.root['vmdb_object_type']}'.")
  case $evm.root['vmdb_object_type']
    when 'miq_provision'
      # get root object
      $evm.log(:info, "Get VM and dialog attributes from $evm.root['miq_provision']") if @DEBUG
      miq_provision = $evm.root['miq_provision']
      dump_object('miq_provision', miq_provision) if @DEBUG
      
      # get VM
      vm = miq_provision.vm
    
      # get options
      options = miq_provision.options
      #merge the ws_values, dialog, top level options into one list to make it easier to search
      options = options.merge(options[:ws_values]) if options[:ws_values]
      options = options.merge(options[:dialog])    if options[:dialog]
    when 'vm'
      # get root objet & VM
      $evm.log(:info, "Get VM from paramater and dialog attributes form $evm.root") if @DEBUG
      vm = get_param(:vm)
      dump_object('vm', vm) if @DEBUG
    
      # get options
      options = $evm.root.attributes
      #merge the ws_values, dialog, top level options into one list to make it easier to search
      options = options.merge(options[:ws_values]) if options[:ws_values]
      options = options.merge(options[:dialog])    if options[:dialog]
    when 'automation_task'
      # get root objet
      $evm.log(:info, "Get VM from paramater and dialog attributes form $evm.root") if @DEBUG
      automation_task = $evm.root['automation_task']
      dump_object('automation_task', automation_task) if @DEBUG
      
      # get VM
      vm  = get_param(:vm)
      
      # get options
      options = get_param(:options)
      options = JSON.load(options)     if options && options.class == String
      options = options.symbolize_keys if options
      #merge the ws_values, dialog, top level options into one list to make it easier to search
      options = options.merge(options[:ws_values]) if options[:ws_values]
      options = options.merge(options[:dialog])    if options[:dialog]
    else
      error("Can not handle vmdb_object_type: #{$evm.root['vmdb_object_type']}")
  end
  
  # standerdize the option keys
  options = options.symbolize_keys()
  
  return vm,options
end

# Get the network configuration for a given network
#
# @param network_name Name of the network to get the configuraiton for
# @return Hash Configuration information about the given network
#                network_purpose
#                network_address_space
#                network_gateway
#                network_nameservers
#                network_ddi_provider
@network_configurations         = {}
@missing_network_configurations = {}
NETWORK_CONFIGURATION_URI       = 'Infrastructure/Network/Configuration'.freeze
def get_network_configuration(network_name)
  if @network_configurations[network_name].blank? && @missing_network_configurations[network_name].blank?
    begin
      escaped_network_name                  = network_name.gsub(/[^a-zA-Z0-9_\.\-]/, '_')
      @network_configurations[network_name] = $evm.instantiate("#{NETWORK_CONFIGURATION_URI}/#{escaped_network_name}")
    rescue
      @missing_network_configurations[network_name] = "WARN: No network configuration exists"
      $evm.log(:warn, "No network configuration for Network <#{network_name}> (escaped <#{escaped_network_name}>) exists")
    end
  end
  return @network_configurations[network_name]
end

# Gets an ApiPie binding to the Satellite API.
#
# @return ApipieBindings to the Satellite API
SATELLITE_CONFIG_URI = 'Integration/Satellite/Configuration/default'
def get_satellite_api()
  satellite_config = $evm.instantiate(SATELLITE_CONFIG_URI)
  error("Satellite Configuration not found") if satellite_config.nil?
  
  satellite_server   = satellite_config['satellite_server']
  satellite_username = satellite_config['satellite_username']
  satellite_password = satellite_config.decrypt('satellite_password')
  
  $evm.log(:info, "satellite_server   = #{satellite_server}") if @DEBUG
  $evm.log(:info, "satellite_username = #{satellite_username}") if @DEBUG
  
  error("Satellite Server configuration not found")   if satellite_server.nil?
  error("Satellite User configuration not found")     if satellite_username.nil?
  error("Satellite Password configuration not found") if satellite_password.nil?
  
  satellite_api = ApipieBindings::API.new({:uri => satellite_server, :username => satellite_username, :password => satellite_password, :api_version => 2})
  $evm.log(:info, "satellite_api = #{satellite_api}") if @DEBUG
  return satellite_api
end

# Takes a string and makes it a valid tag name
#
# @param str String to turn into a valid Tag name
#
# @return Given string transformed into a valid Tag name
def to_tag_name(str)
  return str.downcase.gsub(/[^a-z0-9_]+/,'_')
end

begin
  dump_root()    if @DEBUG
  dump_current() if @DEBUG
  
  error("Expecting vmdb_object_type to be <miq_provision>") if $evm.root['vmdb_object_type'] != 'miq_provision'
  
  miq_provision = $evm.root['miq_provision']
  satellite_api = get_satellite_api()
  vm,options    = get_vm_and_options()
  vm_name       = vm ? vm.name : (options[:vm_target_name] || options[:vm_target_hostname] || options[:vm_name])
  provider      = vm.nil? ? miq_provision.source.ext_management_system : vm.ext_management_system
  
  # get satellite options
  satellite_organization_id = options[:satellite_organization_id]
  satellite_location_id     = options[:satellite_location_id]
  satellite_hostgroup_id    = options[:satellite_hostgroup_id]
  satellite_domain_id       = options[:satellite_domain_id]
  error("Required miq_provision option <satellite_organization_id> not found") if satellite_organization_id.blank?
  error("Required miq_provision option <satellite_hostgroup_id> not found")    if satellite_hostgroup_id.blank?
  
  # if satellite location id not set as a provisioning option then
  #   determine if VM owning provider has a location tag, and if so, use that
  if satellite_location_id.blank?
    provider_location_tags = provider.tags(:location)
    $evm.log(:info, "provider_location_tags => #{provider_location_tags}") if @DEBUG
    
    location_index = satellite_api.resource(:locations).call(:index)
    $evm.log(:info, "location_index => #{location_index}") if @DEBUG
    satellite_location = nil
    provider_location_tags.each do |tag|
      satellite_location = location_index['results'].find { |location| to_tag_name(location['title']) == tag }
      break if !satellite_location.blank?
    end
    
    if !satellite_location.blank?
      satellite_location_id = satellite_location['id']
    end
  end
  error("Either miq_provision option <satellite_location_id> or a <:location> Tag " +
        "on the VM provider <#{provider.name}> matching a Satellite Location must be set.") if satellite_location_id.blank?
  
  if satellite_domain_id.blank?
    domain_name = options[:domain_name]
    $evm.log(:info, "domain_name => '#{domain_name}'") if @DEBUG
    error("Either miq_provision option <satellite_domain_id> or <domain_name> must be provided.") if domain_name.blank?
    

    # query satellite for the domain id
    satellite_domains = satellite_api.resource(:domains).call(:index)['results']
    satellite_domain  = satellite_domains.find { |domain| domain['name'] == domain_name }
    error("Could not find Satellite Domain <#{domain_name}>") if satellite_domain.nil?
    
    if !satellite_domain.blank?
      satellite_domain_id = satellite_domain['id']
    end
  end
  
  $evm.log(:info, "satellite_organization_id => #{satellite_organization_id}") if @DEBUG
  $evm.log(:info, "satellite_hostgroup_id    => #{satellite_hostgroup_id}")    if @DEBUG
  $evm.log(:info, "satellite_domain_id       => #{satellite_domain_id}")       if @DEBUG
  $evm.log(:info, "satellite_location_id     => #{satellite_location_id}")     if @DEBUG
  
  # determine satellite subnet
  network_name                  = options[:network_name] || miq_provision.get_option(:network_name) ||
                                  miq_provision.get_option(:vlan) || $evm.vmdb(:cloud_subnet).find_by_id(miq_provision.get_option(:cloud_subnet)).name
  $evm.log(:info, "network_name => #{network_name}") if @DEBUG
  network_configuration         = get_network_configuration(network_name)
  network_address_space         = network_configuration['network_address_space']
  network_address, network_cidr = network_address_space.split('/')
  network_netmask               = IPAddr.new('255.255.255.255').mask(network_cidr).to_s
  satelltie_subnet_results      = satellite_api.resource(:subnets).call(
    :index,
    {
      :organization_id => satellite_organization_id,
      :location_id     => satellite_location_id,
      :domain_id       => satellite_domain_id,
      :search          => "network = #{network_address} and mask = #{network_netmask}"
    }
  )
  if satelltie_subnet_results['results'].empty?
    $evm.log(:warn, "Did not find Satellite Subnet for network address <#{network_address}> with network netmask <#{network_netmask}> " +
                    "in Satelllite Organization <#{satellite_organization_id}>, in Satellite Location <#{satellite_location_id}>, " +
                    "in Satellite Domain <#{satellite_domain_id}>. " +
                    "Ignore, will not specify Satellite subnet ID in new host record creation.")
  else
    satellite_subnet = satelltie_subnet_results['results'][0]
    
    # NOTE: this should never happen, but warn in case it does
    if satelltie_subnet_results['results'].length > 1
       $evm.log(:warn, "Found more then one Satellite Subnet for network address <#{network_address}> with network netmask <#{network_netmask}> " +
                       "in Satelllite Organization <#{satellite_organization_id}>, in Satellite Location <#{satellite_location_id}>, " +
                       "in Satellite Domain <#{satellite_domain_id}>. " +
                       "Ignore, will use first resultin new host record creation.")
    end
  end
  
  # determine owner
  satellite_config      = $evm.instantiate(SATELLITE_CONFIG_URI)
  satellite_owner_group = satellite_config['satellite_owner_group']
  if !satellite_owner_group.nil?
    satellite_usergroups_result = satellite_api.resource(:usergroups).call(:index, {:search => "#{satellite_owner_group}"})
    satellite_usergroup         = satellite_usergroups_result['results'].first
  end
  
  # create the new host request
  vm_mac = vm.nil? ? nil : vm.mac_addresses.first
  new_host_request = {
    :name                  => vm_name,
    :owner_type            => satellite_usergroup.blank? ? 'User' : 'Usergroup', # NOTE: docs say 'user' and 'usergroup' but Foreman requires 'User' or 'Usergroup'
    :owner_id              => satellite_usergroup.blank? ? nil    : satellite_usergroup['id'],
    :organization_id       => satellite_organization_id,
    :location_id           => satellite_location_id,
    :hostgroup_id          => satellite_hostgroup_id,
    :domain_id             => satellite_domain_id,
    :managed               => true,
    :build                 => true,
    :provision_method      => 'build',
    :mac                   => vm_mac,
    :interfaces_attributes => [
      { :identifier => 'eth0',
        :primary    => true,
        :provision  => true,
        :managed    => !vm_mac.nil?, # only manage interface if mac address given
        :mac        => vm_mac,
        :domain_id  => satellite_domain_id,
        :subnet_id  => satellite_subnet.nil? ? nil : satellite_subnet['id']
      }
    ]
  }
  $evm.log(:info, "new_host_request => #{new_host_request}")
  
  # create Satellite Host record
  begin
    satellite_host_record = satellite_api.resource(:hosts).call(:create, { :host => new_host_request })
    $evm.log(:info, "satellite_host_record => #{satellite_host_record}")
  rescue RestClient::UnprocessableEntity => e
    error("Received an UnprocessableEntity error from Satellite. Check /var/log/foreman/production.log on Satellite for more info.")
  rescue Exception => e
    error("Error creating Satellite host record: #{e.message}")
  end
  
  # store the satellite host record id for future use
  miq_provision = $evm.root['miq_provision']
  miq_provision.set_option(:satellite_host_id, satellite_host_record['id']) if miq_provision
  
  # set custom attribute on VM if the VM exists
  vm.custom_set('satellite_host_id', satellite_host_record['id']) if vm
end
