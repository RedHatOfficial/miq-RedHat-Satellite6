# Starts / Powers on VM and then waits for the VM to be in a powerd on state.
#
# EXPECTED
#   EVM ROOT
#     miq_provision - VM Provisining request contianing the VM to start.
#
# @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/customising_vm_provisioning/chapter.html#_start_vm
#
@DEBUG = false

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
  # Get provisioning object
  prov = $evm.root['miq_provision']
  error('Provisioning request not found') if prov.nil?
  $evm.log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")
  $evm.log(:info, "prov.attributes => {")                               if @DEBUG
  prov.attributes.sort.each { |k,v| $evm.log(:info, "\t#{k} => #{v}") } if @DEBUG
  $evm.log(:info, "}")                                                  if @DEBUG
  
  # get the VM
  vm = prov.vm
  error('VM on provisining request not found') if vm.nil?
  $evm.log(:info, "vm = #{vm}") if @DEBUG
  
  $evm.log(:info, "Current VM power state = #{vm.power_state}")
  unless vm.power_state == 'on'
    vm.start
    vm.refresh
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  else
    $evm.root['ae_result'] = 'ok'
  end
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
end
