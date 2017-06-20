# Customizes the VMware placement after the intitial placement decisions.
#
# EXPECTED
#   EVM ROOT
#     miq_provision - VM Provisining request to customize the placement for.
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

# Get the vm provsining customization configuration.
#
# @return VM provisining configuration
VM_PROVISIONING_CONFIG_URI = 'Infrastructure/VM/Provisioning/Configuration/default'
def get_vm_provisioning_config()
  provisioning_config = $evm.instantiate(VM_PROVISIONING_CONFIG_URI)
  error("VM Provisioning Configuration not found") if provisioning_config.nil?
  
  return provisioning_config
end

begin
  # Get provisioning object
  prov = $evm.root['miq_provision']
  error('Provisioning request not found') if prov.nil?
  $evm.log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")
  $evm.log(:info, "prov.attributes => {")                               if @DEBUG
  prov.attributes.sort.each { |k,v| $evm.log(:info, "\t#{k} => #{v}") } if @DEBUG
  $evm.log(:info, "}")                                                  if @DEBUG
  
  # get the datacenter
  template   = prov.vm_template
  datacenter = template.v_owning_datacenter
  
  # determine cutsomized placement folder
  vm_provisioning_config         = get_vm_provisioning_config()
  vmware_folder                  = vm_provisioning_config['vmware_folder']
  vsphere_fully_qualified_folder = "#{datacenter}/#{vmware_folder}"

  # update placement folder
  $evm.log(:info, "Provisioning object <:placement_folder_name> curent value <#{prov.options[:placement_folder_name].inspect}>") if @DEBUG
  prov.set_folder(vsphere_fully_qualified_folder)
  $evm.log(:info, "Provisioning object <:placement_folder_name> updated with <#{prov.options[:placement_folder_name].inspect}>")
end
