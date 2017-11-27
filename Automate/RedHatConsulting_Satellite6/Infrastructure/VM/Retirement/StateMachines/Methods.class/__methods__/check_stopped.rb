# Checks that a Vmware VM has been stopped before CheckPreRetirement
# This is to work around the "unknown" status being returned
# EXPECTED
#   EVM ROOT
#     vm - VM to check power state for
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

def check_power_state(vm)
  ems = vm.ext_management_system if vm
  if vm.nil? || ems.nil?
    $evm.log('info', "Skipping check pre retirement for VM:<#{vm.try(:name)}> on EMS:<#{ems.try(:name)}>")
    return
  end

  power_state = vm.power_state
  $evm.log('info', "VM:<#{vm.name}> on Provider:<#{ems.name}> has Power State:<#{power_state}>")

  # If VM is powered off or suspended exit

  if %w(off suspended).include?(power_state)
    $evm.root['ae_result'] = 'ok'
  elsif power_state == "never"
    # If never then this VM is a template so exit the retirement state machine
    $evm.root['ae_result'] = 'error'
  else
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = '60.seconds'
  end
end

begin
  vm = $evm.root['vm']
  
  check_power_state(vm)
end
