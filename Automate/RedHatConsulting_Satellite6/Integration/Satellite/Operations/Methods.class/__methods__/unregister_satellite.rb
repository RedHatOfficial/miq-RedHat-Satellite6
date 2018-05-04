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
      satellite_host_record  = satellite_index_result['results'][0]
      
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
  vm = $evm.root['vm']
  error('VM not found') if vm.nil?
  $evm.log(:info, "vm => #{vm}") if @DEBUG
  
  # get the satellite host record id
  satellite_api         = get_satellite_api()
  satellite_host_record = get_satellite_host_record(satellite_api, vm.name)
  
  # if a satellite host record is found, then retire it
  # else just ignore
  if !satellite_host_record.blank?
    satellite_host_id     = satellite_host_record['id']
    $evm.log(:info, "satellite_host_id => '#{satellite_host_id}'") if @DEBUG
  
    begin
      $evm.log(:info, "Unregister Satellite Host Record <#{satellite_host_id}> for Host <#{vm.name}>")
      result = satellite_api.resource(:hosts).call(:destroy, { :id => satellite_host_id})
      $evm.log(:info, "Unregistered Satellite Host Record <#{satellite_host_id}> for Host <#{vm.name}>")
    rescue RestClient::NotFound
      warn("No Satellite Host Record <#{satellite_host_id}> to unregister for Host <#{vm.name}>")
    rescue => e
      warn("Unexpected error when unregistering Satellite Host Record <#{satellite_host_id}> to unregister for Host <#{vm.name}>: #{e.message}")
    end
  else
    $evm.log(:info, "No Satellite Host Record to unregister found for Host <#{vm.name}>. Skipping and ignoring.")
  end
end
