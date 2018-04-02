# IMPLIMENTORS: intended to be overwritten.
#
# Sets additional dialog options on the given serivce.
#
@DEBUG = false

require 'apipie-bindings'

# IMPLIMENTORS: intended to be overwritten
#
# @param dialog_options Hash Dialog options set by user when creating the service.
#
# @return Hash of custom vm_fields to set on any vm provisioning requests created for the service being created
def get_custom_vm_fields(dialog_options)
  custom_vm_fields = {
    :placement_auto => true,
    :vm_auto_start  => false,
    :vm_name        => 'changeme'
  }
  
  return custom_vm_fields
end

# IMPLIMENTORS: intended to be overwritten
#
# @param dialog_options Hash Dialog options set by user when creating the service.
#
# @return Hash of custom custom additional_values (ws_values) to set on any vm provisioning requests created for the service being created
def get_custom_additional_values(dialog_options)
  # set base custom additional values
  custom_additional_values = {
    :custom_provision_type => 'satellite'
  }
  
  # ensure satellite_domain_id is set
  dialog_satellite_domain_id = dialog_options[:satellite_domain_id]
  if !dialog_satellite_domain_id.blank?
    custom_additional_values[:satellite_domain_id] = dialog_satellite_domain_id
  else
    domain_name = dialog_options[:domain_name]
    $evm.log(:info, "domain_name => '#{domain_name}'") if @DEBUG
    if !domain_name.blank?
      satellite_api ||= get_satellite_api()
    
      # query satellite for the domain id
      satellite_domains = satellite_api.resource(:domains).call(:index)['results']
      satellite_domain  = satellite_domains.find { |domain| domain['name'] == domain_name }
      error("Could not find Satellite Domain with name: '#{domain_name}'") if satellite_domain.nil?
    
      # set the additional dialog option
      custom_additional_values[:satellite_domain_id] = satellite_domain['id']
    else
      error("One of <satellite_domain_id, domain_name> must be supplied as dialog options.")
    end
  end
  
  # ensure satellite_location_id is set
  # NOTE:
  #   if not provided then will rely on register_satellite to determine it based
  #   on a location tag on the provider that owns the template being provisioned
  dialog_satellite_location_id = dialog_options[:satellite_location_id]
  if !dialog_satellite_location_id.blank?
    custom_additional_values[:satellite_location_id] = dialog_satellite_location_id
  end
  
  # ensure satellite_hostgroup_id is set
  dialog_satellite_hostgroup_id = dialog_options[:satellite_hostgroup_id]
  if !dialog_satellite_hostgroup_id.nil?
    custom_additional_values[:satellite_hostgroup_id] = dialog_satellite_hostgroup_id
  else
    satellite_api ||= get_satellite_api()
    error("satellite_hostgroup_id dialog option must be set.")
  end
  
  return custom_additional_values
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

# IMPLIMENTORS: do not modify
def dump_object(object_string, object)
  $evm.log("info", "Listing #{object_string} Attributes:") 
  object.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# IMPLIMENTORS: do not modify
def dump_current
  $evm.log("info", "Listing Current Object Attributes:") 
  $evm.current.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# IMPLIMENTORS: do not modify
def dump_root
  $evm.log("info", "Listing Root Object Attributes:") 
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# IMPLIMENTORS: do not modify
def error(msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg
  $evm.log(:error, msg)
  exit MIQ_OK
end

# IMPLIMENTORS: do not modify
def yaml_data(task, option)
  task.get_option(option).nil? ? nil : YAML.load(task.get_option(option))
end

# IMPLIMENTORS: do not modify
begin
  dump_current() if @DEBUG
  dump_root()    if @DEBUG
  
  # get options and tags
  $evm.log(:info, "$evm.root['vmdb_object_type'] => '#{$evm.root['vmdb_object_type']}'.") if @DEBUG
  case $evm.root['vmdb_object_type']
  when 'service_template_provision_task'
    task = $evm.root['service_template_provision_task']
    dump_object("service_template_provision_task", task) if @DEBUG

    dialog_options = yaml_data(task, :parsed_dialog_options)
    dialog_options = dialog_options[0] if !dialog_options[0].nil?
  else
    error("Can not handle vmdb_object_type: #{$evm.root['vmdb_object_type']}")
  end
  $evm.log(:info, "dialog_options => #{dialog_options}") if @DEBUG
  
  # get the custom options
  custom_vm_fields         = get_custom_vm_fields(dialog_options)
  custom_additional_values = get_custom_additional_values(dialog_options)
  
  # set the custom options on the task
  task.set_option(:custom_vm_fields, custom_vm_fields)
  task.set_option(:custom_additional_values, custom_additional_values)
  $evm.log(:info, "Set :custom_vm_fields         => #{custom_vm_fields}")         if @DEBUG
  $evm.log(:info, "Set :custom_additional_values => #{custom_additional_values}") if @DEBUG
  
  # TODO: move me somewhere else
  task.set_option(:target_name, dialog_options[:service_name])
  task.set_option(:description, dialog_options[:service_name])
end
