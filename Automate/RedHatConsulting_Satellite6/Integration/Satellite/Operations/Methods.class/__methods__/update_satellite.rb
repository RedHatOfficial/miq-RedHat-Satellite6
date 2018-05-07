# Update the Satellite Host Record based on current VM information.
#   * MAC
#   * IP
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

# Notify and log a warning message.
#
# @param msg Message to warn with
def warn(msg)
  $evm.create_notification(:level => 'warning', :message => msg)
  $evm.log(:warn, msg)
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

# Get the Satellite host record for a given host name
#
# @param satellite_api ApipieBinding Sattellite API object
# @param name          String        Name of the host to find the Satelilte host record for
#
# @return Hash Satellite host record for the given host name returned from Satellite API
def get_satellite_host_record(satellite_api, name)
  satellite_host_record = nil
  begin
    satellite_index_result = satellite_api.resource(:hosts).call(:index, {:search => "#{name}"})
    if !satellite_index_result['results'].empty?
      satellite_host_record = satellite_index_result['results'].first
      
      # get the full record
      satellite_host_record = satellite_api.resource(:hosts).call(:show, {:id => satellite_host_record['id']})
      
      # NOTE: hopefully this never happens
      # warn if found more then one result
      if satellite_index_result['results'].length > 1
        $evm.log(:warn, "More then one Satellite host record found for Host <#{name}>, using first one.")
      end
    end
  rescue RestClient::UnprocessableEntity => e
    error("Error finding Satellite host record for Host <#{name}>. Received an UnprocessableEntity error from Satellite. Check /var/log/foreman/production.log on Satellite for more info.")
  rescue Exception => e
    error("Error finding Satellite host record for Host <#{name}>: #{e.message}")
  end
  
  return satellite_host_record
end

begin
  # get the VM
  vm,options = get_vm_and_options()
  error('VM not found') if vm.nil?
  $evm.log(:info, "vm => #{vm}") if @DEBUG
  
  # get the satellite host record id
  satellite_api         = get_satellite_api()
  satellite_host_record = get_satellite_host_record(satellite_api, vm.name)
  
  # if a satellite host record is found, then check if it needs to be updated
  # else just ignore
  if !satellite_host_record.blank?
    satellite_host_ip         = satellite_host_record['ip']
    satellite_host_mac        = satellite_host_record['mac']
    satellite_host_interfaces = satellite_host_record['interfaces']
    
    # if Satellite Host record does not have IP or MAC and isn't already managed, then update the host record
    if (satellite_host_ip.blank? || satellite_host_mac.blank?) && !satellite_host_interfaces.first['managed']
      # NOTE: assume use first IP and MAC
      vm_mac_address = vm.mac_addresses.first
      vm_ip_address  = vm.ipaddresses.first
      new_satellite_host_record = {
        :mac                   => vm_mac_address,
        :ip                    => vm_ip_address,
        :interfaces_attributes => satellite_host_interfaces.clone
      }
      
      # update interface so it is managed
      # NOTE: making assumptionn to update first interface
      new_satellite_host_record[:interfaces_attributes][0][:mac]     = vm_mac_address
      new_satellite_host_record[:interfaces_attributes][0][:ip]      = vm_ip_address
      new_satellite_host_record[:interfaces_attributes][0][:managed] = true
    
      # update the host record
      satellite_host_id = satellite_host_record['id']
      $evm.log(:info, "satellite_host_id => '#{satellite_host_id}'") if @DEBUG
      begin
        $evm.log(:info, "Update Satellite Host Record <#{satellite_host_id}> for Host <#{vm.name}>: #{new_satellite_host_record}")
        result = satellite_api.resource(:hosts).call(:update, { :id => satellite_host_id, :host => new_satellite_host_record})
        $evm.log(:info, "Update Satellite Host Record <#{satellite_host_id}> for Host <#{vm.name}>: #{result}")
      rescue RestClient::NotFound
        warn("No Satellite Host Record <#{satellite_host_id}> to update for Host <#{vm.name}>.")
      rescue => e
        warn("Unexpected error when unregistering Satellite Host Record <#{satellite_host_id}> to unregister for Host <#{vm.name}>: #{e.message}")
      end
    end
  else
    $evm.log(:info, "No Satellite Host Record to udpate found for Host <#{vm.name}>. Skipping and ignoring.")
  end
end
