# Uses time data captured during the VM provisioning process to set custom attributes
# on the VM about the times taken to perform steps of the provisioning process.
#
# Parameters:
# 	ROOT
# 		* miq_provision
#
@DEBUG = false

PROVISIONING_TELEMETRY_PREFIX = "Provisioning: Telemetry:"

# Converts duration of seconds to HH:MM:SS
#
# @param seconds Number of seconds passed
#
# @return duration converted to HH:MM:SS
def seconds_to_time(seconds)
  seconds = seconds.round
  return [seconds / 3600, seconds / 60 % 60, seconds % 60].map { |t| t.to_s.rjust(2,'0') }.join(':')
end

# Get the duration between two times.
#
# @return Duration in HH:MM:SS between to times, or Unknown, if any time is nil
def get_duration(start_time, end_time)
  $evm.log(:info, "get_duration: START: { :start_time => #{start_time}, :end_time => #{:end_time} }") if @DEBUG
  duration = 'Unknown'
  
  start_time = $evm.get_state_var(start_time) if start_time.class == Symbol
  end_time   = $evm.get_state_var(end_time)   if end_time.class   == Symbol
  
  if start_time && end_time
    duration = seconds_to_time(end_time.in_time_zone("UTC") - start_time.in_time_zone("UTC"))

  else
    duration = 'Unknown'
  end
  
  $evm.log(:info, "get_duration: END: { :duration => #{duration}, :start_time => #{start_time}, :end_time => #{:end_time} }") if @DEBUG
  return duration
end

# Set VM custom attribute with provisioning telemetry data
def set_provisioning_telemetry_custom_attribute(vm, description, value)
  vm.custom_set("#{PROVISIONING_TELEMETRY_PREFIX} #{description}", value)
end

begin
  # Get vm from miq_provision object
  prov = $evm.root['miq_provision']
  vm = prov.vm
  error("VM not found") if vm.nil?
  
  # determine how long different steps took
  now                                = Time.now
  duration_task_queue                = get_duration(prov.created_on,                                                   :vm_provisioning_telemetry_on_entry_CustomizeRequest)
  duration_vm_provisioning           = get_duration(:vm_provisioning_telemetry_on_entry_CustomizeRequest,              now)
  duration_vm_clone                  = get_duration(:vm_provisioning_telemetry_on_entry_Provision,                     :vm_provisioning_telemetry_on_exit_CheckProvisioned)
  duration_wait_for_vm_mac_addresses = get_duration(:vm_provisioning_telemetry_on_entry_WaitForVMMACAddresses,         :vm_provisioning_telemetry_on_exit_WaitForVMMACAddresses)
  duration_start_vm                  = get_duration(:vm_provisioning_telemetry_on_entry_StartVM,                       :vm_provisioning_telemetry_on_exit_StartVM)
  duration_wait_for_vm_ip_addresses  = get_duration(:vm_provisioning_telemetry_on_entry_PostSatelliteBuildCompleted_1, :vm_provisioning_telemetry_on_exit_PostSatelliteBuildCompleted_1)
 
  # NOTE: Satellite 6 specific
  duration_wait_for_satellite_build_completed = get_duration(:vm_provisioning_telemetry_on_exit_StartVM, :vm_provisioning_telemetry_on_exit_CheckSatelliteBuildCompleted)
  
  set_provisioning_telemetry_custom_attribute(vm, 'Time: Request Created',               prov.created_on.localtime)
  set_provisioning_telemetry_custom_attribute(vm, 'Time: Request Completed',             now)
  set_provisioning_telemetry_custom_attribute(vm, 'Hour: Request Created',               prov.created_on.localtime.hour)
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: Task Queue',                duration_task_queue)
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: Total VM Provisioning',     duration_vm_provisioning)
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: VM Clone',                  duration_vm_clone)
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: Wait for VM MAC Addresses', duration_wait_for_vm_mac_addresses)
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: Start VM',                  duration_start_vm)
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: Wait for VM IP Addresses',  duration_wait_for_vm_ip_addresses)
  
  # NOTE: Satellite 6 specific
  set_provisioning_telemetry_custom_attribute(vm, 'Duration: Wait for Satellite Build To Complete',  duration_wait_for_satellite_build_completed)
end
