# Sets the MiqProvision#options[:clone_options][:user_data] field. This allows a custom user data to be pased instead of using a Customization Template.
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

# Notify and log a message.
#
# @param level   Symbol             Level of the notification and log message
# @param message String             Message to notify and log
# @param subject ActiveRecord::Base Subject of the notification
def notify(level, message, subject)
  $evm.create_notification(:level => level, :message => message, :subject => subject)
  log_level = case level
    when :warning
      :warn
    else
      level
  end
  $evm.log(log_level, message)
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
  begin
    satellite_index_result = satellite_api.resource(:hosts).call(:index, {:search => "name=#{name}"})
    if !satellite_index_result['results'].empty?
      satellite_host_record  = satellite_index_result['results'][0]
      
      # NOTE: hopefully this never happens
      # warn if found more then one result
      if satellite_index_result['results'].length > 1
        $evm.log(:warn, "More then one Satellite host record found for Host <#{name}>, using first one.")
      end
    else
      error("Could not find Satellite host entry for Host <#{name}>")
    end
  rescue RestClient::UnprocessableEntity => e
    error("Error finding Satellite host record for Host <#{name}>. Received an UnprocessableEntity error from Satellite. Check /var/log/foreman/production.log on Satellite for more info.")
  rescue Exception => e
    error("Error finding Satellite host record for Host <#{name}>: #{e.message}")
  end
  
  return satellite_host_record
end

begin
  satellite_api = get_satellite_api()
  vm,options    = get_vm_and_options()
  vm_name       = vm ? vm.name : (options[:vm_target_name] || options[:vm_target_hostname] || options[:vm_name])
  
  miq_provision = $evm.root['miq_provision']
  error('Expected provisioning request not found') if miq_provision.nil?
  
  # find the satellite host record
  satellite_host_record = get_satellite_host_record(satellite_api, vm_name)
  
  # find the satellite host record user data template
  begin
    satellite_host_user_data_template_result = satellite_api.resource(:hosts).call(:template, {:id => satellite_host_record['id'], :kind => 'user_data'})
    $evm.log(:info, "satellite_host_user_data_template_result => #{satellite_host_user_data_template_result}") if @DEBUG
  rescue RestClient::UnprocessableEntity => e
    error("Error finding Satellite host user_data template for Satelite host record <#{satellite_host_record['id']}> for VM <#{vm_name}>. Received an UnprocessableEntity error from Satellite. Check /var/log/foreman/production.log on Satellite for more info.")
  rescue Exception => e
    error("Error finding Satellite host user_data template for Satelite host record <#{satellite_host_record['id']}> for VM <#{vm_name}>: #{e.message}")
  end
  
  # set the user data clone option
  clone_options = miq_provision.get_option(:clone_options) || {}
  clone_options[:user_data] = Base64.encode64(satellite_host_user_data_template_result['template'])
  miq_provision.set_option(:clone_options, clone_options)
  $evm.log(:info, "miq_provision.get_option(:clone_options)[:user_data] => #{miq_provision.get_option(:clone_options)[:user_data]}")
end
