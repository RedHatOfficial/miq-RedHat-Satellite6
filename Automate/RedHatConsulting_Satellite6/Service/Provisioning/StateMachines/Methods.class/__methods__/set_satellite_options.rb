# This method is intended to set provision options related to Satellite based provisioning on the VM Provision tasks
# associated with the current service_template_provision_task.
#
# This function may not need to do anything if all required Satellite options are set via a custom service dialog.
#
# Required Provision Options to be set by either this method or custom service dialog options:
#   satellite_organization_id
#   satellite_location_id
#   satellite_hostgroup_id
#
# NOTE: Intended to be overriden by implimentors.
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
  $evm.log(:info, "START - set_satellite_options") if @DEBUG
  
  satellite_api = get_satellite_api()
  
  task = $evm.root['service_template_provision_task']
  error("$evm.root['service_template_provision_task'] not found") if task.nil?
  
  # determine :satellite_domain_id
  domain_name = task.get_option(:dialog)['dialog_domain_name']
  error("Required :domain_name option is not set on current ServiceTemplateProvisionTask") if domain_name.nil?
  $evm.log(:info, "domain_name => '#{domain_name}'") if @DEBUG
  satellite_domains = satellite_api.resource(:domains).call(:index)['results']
  satellite_domain  = satellite_domains.find { |satellite_domain| satellite_domain['name'] == domain_name }
  error("Could not find Satellite Domain with name: '#{domain_name}'") if satellite_domain.nil?
  
  # Set satellite options
  task.miq_request_tasks.each do |service_provision_task|
    service_provision_task.miq_request_tasks.each do |vm_provision_task|
      # Set :satellite_domain_id option
      vm_provision_task.set_option(:satellite_domain_id, satellite_domain['id'])
      $evm.log(:info, "{ vm_provision_task_id => '#{task.id}', :satellite_domain_id => '#{vm_provision_task.get_option(:satellite_domain_id)}' }") if @DEBUG
      
      # !!!!! IMPLIMENTOR TODO: Impliment business logic here !!!!!!
      $evm.log(:info, "Default implimentation does not do anything, intended to be overwritten by implimentor in a higher domain. { service_provision_task => #{service_provision_task} }")
      #satellite_hostgroup_id =
      #vm_provision_task.set_option(:satellite_hostgroup_id, satellite_hostgroup_id)
      #$evm.log(:info, "{ vm_provision_task_id => #{vm_provision_task.id}, vm_provision_task.get_option(:satellite_hostgroup_id) => '#{vm_provision_task.get_option(:satellite_hostgroup_id)}' }")
    end
  end
  
  $evm.log(:info, "END - set_satellite_options") if @DEBUG
end
