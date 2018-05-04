# Get the required Satellite configuration from configured Foreman provider
#
# @return satellite_server
# @return satellite_username
# @return satellite_password 
@DEBUG = false

begin
  satellite_provider = $evm.vmdb(:ManageIQ_Providers_Foreman_Provider).first
  
  if !satellite_provider.nil?
    $evm.object['satellite_username'] = satellite_provider.object_send(:authentication_userid)
    $evm.object['satellite_password'] = satellite_provider.object_send(:authentication_password)
    $evm.object['satellite_server']   = satellite_provider.url
  end
end
