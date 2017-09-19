# If the given VM has `satellite_host_id` custom attribute set then unregister that VM from satellite.
#
# EXPECTED
#   EVM ROOT
#     vm - VM to unregister from Satellite if it has the `satellite_host_id` custom attribute set
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

# Notify and log a warning message.
#
# @param msg Message to warn with
def warn(msg)
  $evm.create_notification(:level => 'warning', :message => msg)
  $evm.log(:warn, msg)
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
  vm = $evm.root['vm']
  error('VM not found') if vm.nil?
  $evm.log(:info, "vm => #{vm}") if @DEBUG
  
  satellite_host_id = vm.custom_get('satellite_host_id')
  $evm.log(:info, "satellite_host_id => '#{satellite_host_id}'") if @DEBUG
  
  # if there is a satellite_host_id custom attribute set unregister that host from Satellite
  # else do nothing
  if !satellite_host_id.nil?
    satellite_api = get_satellite_api()
    
    begin
      $evm.log(:info, "Unregister Satellite Host: { :id => '#{satellite_host_id}' }")
      result = satellite_api.resource(:hosts).call(:destroy, { :id => satellite_host_id})
      $evm.log(:info, "Unregistered Satellite Host: { :id => '#{satellite_host_id}', result => #{result} }")
    rescue RestClient::NotFound
      warn("No Satellite host [#{satellite_host_id}] to unregister for VM [#{$evm.root['vm'].name}]")
    rescue => e
      warn("Unexpected error when unregistering Satellite host [#{satellite_host_id}] for VM [#{$evm.root['vm'].name}]: #{e.message}")
    end
  else
    $evm.log(:info, "VM '#{vm.name}' does not have 'satellite_host_id' custom attribute set, therefor not unregistering from Satellite.")
  end
end
