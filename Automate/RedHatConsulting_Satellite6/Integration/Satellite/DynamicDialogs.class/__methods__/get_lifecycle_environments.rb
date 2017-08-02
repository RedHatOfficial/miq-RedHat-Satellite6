# Populates a dynamic drop down with the Lifecycle Enviornments from a Satellite Organization.
#
@DEBUG = false

require 'apipie-bindings'

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
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

begin
  satellite_api = get_satellite_api()
  
  satellite_organization_id = $evm.root['dialog_satellite_organization_id']
  $evm.log(:info, "satellite_organization_id = #{satellite_organization_id}") if @DEBUG
  
  if !satellite_organization_id.length.zero?
    environments_index = satellite_api.resource(:lifecycle_environments).call(:index,{:organization_id => satellite_organization_id})
    $evm.log(:info, "environments_index = #{environments_index}") if @DEBUG
    dialog_field_values = Hash[ *environments_index['results'].collect { |item| [item['id'], item['name']] }.flatten ]
  else
    dialog_field_values = {}
  end
  
  dialog_field               = $evm.object
  dialog_field["sort_by"]    = "value"
  dialog_field["sort_order"] = "ascending"
  dialog_field["data_type"]  = "integer"
  dialog_field["required"]   = true
  dialog_field["values"]     = dialog_field_values
end
