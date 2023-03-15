# Waits for the build status of the VM being provisioned to be 'Installed'
#
# EXPECTED
#   EVM ROOT
#     miq_provision - VM Provisining request to create the Satellite host record for.
#       required options:
#         :satellite_host_id - Satellite Host ID to check the build status for
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
  # Get provisioning object
  prov = $evm.root['miq_provision']
  error('Provisioning request not found') if prov.nil?
  $evm.log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")
  $evm.log(:info, "prov.attributes => {")                               if @DEBUG
  prov.attributes.sort.each { |k,v| $evm.log(:info, "\t#{k} => #{v}") } if @DEBUG
  $evm.log(:info, "}")                                                  if @DEBUG
  
  # get the satellite host id
  satellite_host_id = prov.get_option(:satellite_host_id)
  error("Could not find 'satellite_host_id' on the miq_provision: #{prov}") if satellite_host_id.nil?
  $evm.log(:info, "satellite_host_id => '#{satellite_host_id}'") if @DEBUG
  
  # get the current build status
  satellite_api = get_satellite_api()
  satellite_build_status = satellite_api.resource(:hosts).call(:get_status, { :id => satellite_host_id, :type => 'build' })
  status_label = satellite_build_status['status_label']
  
  # Until the status is installed keep retrying
  $evm.log(:info, "Current VM Satellite Build state: { :status_label => '#{status_label}', :satellite_host_id => '#{satellite_host_id}' }")
  unless status_label == 'Installed'
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  else
    $evm.root['ae_result'] = 'ok'
  end
rescue => err
    $evm.log(:error, "Error checking build status: #{err.message}")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
end
