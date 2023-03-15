# Populates a dynamic drop down with the Locations from Satellite.
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
  
  satellite_api = ApipieBindings::API.new({:uri => satellite_server, :username => satellite_username, :password => satellite_password, :api_version => 2, :apidoc_cache_dir => "/tmp/foreman" }, {:verify_ssl => false})
  $evm.log(:info, "satellite_api = #{satellite_api}") if @DEBUG
  return satellite_api
end

begin
  # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
  exit MIQ_OK unless $evm.root['vmdb_object_type']
  
  satellite_api = get_satellite_api()
  error('Could not get Satellite API') if satellite_api.nil?
  
  location_index = satellite_api.resource(:locations).call(:index)
  $evm.log(:info, "location_index => #{location_index}") if @DEBUG
  
  $evm.log(:info, "default value id => #{location_index['results'][0]['id']}") if @DEBUG
  
  dialog_field                  = $evm.object
  dialog_field["sort_by"]       = "value"
  dialog_field["sort_order"]    = "ascending"
  dialog_field["data_type"]     = "integer"
  dialog_field["required"]      = true
  dialog_field['default_value'] = location_index['results'][0]['id']
  dialog_field["values"]        = Hash[ *location_index['results'].collect { |item| [item['id'], item['title']] }.flatten ]
end
