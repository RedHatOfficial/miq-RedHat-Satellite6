# Sets :custom_provision_type option on all of the miq_provision_request objects associated with the current service_template_provision_task.
#
# EXPECTED
#   EVM ROOT
#     service_template_provision_task - set to VM to get LDAP entries for
#
# SETS
#   each miq_provision_request
#     :custom_provision_type - Custom provisining type to use for the miq_provision_request
#
@DEBUG = false

VM_PROVISION_TYPE = 'satellite'

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

begin
  $evm.log(:info, "START - set_custom_provision_type") if @DEBUG
  
  task = $evm.root['service_template_provision_task']
  error("$evm.root['service_template_provision_task'] not found") if task.nil?
  
  task.miq_request_tasks.each do |service_provision_task|
    service_provision_task.miq_request_tasks.each do |vm_provision_task|
      vm_provision_task.set_option(:custom_provision_type, VM_PROVISION_TYPE)
      $evm.log(:info, "{ vm_provision_task => #{vm_provision_task}, vm_provision_task.get_option(:custom_provision_type) => '#{vm_provision_task.get_option(:custom_provision_type)}' }") if @DEBUG
    end
  end
  
  $evm.log(:info, "END - set_custom_provision_type") if @DEBUG
end
