# Determine the provision type to use for the miq_provision in the VMProvision_*/* state machine
#
# The default behavior of the "out-of-the-box" state machine of using $evm.root['miq_provision'].provision_type
# can be overridden if $evm.root['miq_provision'].get_option(:custom_provision_type) is set.
#
# EXPECTED
#   EVM ROOT
#     miq_provision - Provisining request to determine the provision type for
#
# SETS
#   EVM OBJECT
#     provision_type - Provision type to use in the VMProvision_*/* state machine
#
@DEBUG = false

# Logs all $evm.root attributes
def dump_root()
  $evm.log(:info, "$evm.root.attributes => {")
  $evm.root.attributes.sort.each { |k,v| $evm.log(:info, "\t#{k} => #{v}") }
  $evm.log(:info, "}")
end

# Logs all the attributes from a given attribute on $evm.root
#
# @param root_attribute Attribute on $evm.root to log all of the attributes for
def dump_root_attribute(root_attribute)
  $evm.log(:info, "$evm.root['#{root_attribute}'].attributes => {")
  $evm.root[root_attribute].attributes.sort.each { |k,v| $evm.log(:info, "\t#{k} => #{v}") }
  $evm.log(:info, "}")
end

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
  $evm.log(:info, "START - get_provision_type") if @DEBUG
  dump_root()                                   if @DEBUG
  dump_root_attribute('miq_provision')          if @DEBUG
  
  # get the provision object
  prov = $evm.root['miq_provision']
  error("$evm.root['miq_provision'] not found") if prov.nil?
  
  # find custom provision type in the provision options if it is there
  custom_provision_type = prov.get_option(:custom_provision_type)
  $evm.log(:info, "custom_provision_type => '#{custom_provision_type}'") if @DEBUG

  # if a custom provision type is set use that as the provsion type
  # else use the "normal" miq_provision.provision_type
  if custom_provision_type.nil?
    $evm.object['provision_type'] = $evm.root['miq_provision'].provision_type
  else
    $evm.object['provision_type'] = custom_provision_type
  end
  
  $evm.log(:info, "$evm.object['provision_type'] => '#{$evm.object['provision_type']}'")
  $evm.log(:info, "END - get_provision_type") if @DEBUG
end
