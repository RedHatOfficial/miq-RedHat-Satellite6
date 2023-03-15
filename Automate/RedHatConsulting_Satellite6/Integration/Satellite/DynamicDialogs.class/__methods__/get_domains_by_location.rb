# Populates a dynamic drop down with the Domains from Satellite based on selected Location.
#
@DEBUG = false

require 'apipie-bindings'

def dump_object(object_string, object)
  $evm.log("info", "Listing #{object_string} Attributes:") 
  object.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_current
  $evm.log("info", "Listing Current Object Attributes:") 
  $evm.current.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_root
  $evm.log("info", "Listing Root Object Attributes:") 
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
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

# There are many ways to attempt to pass parameters in Automate.
# This function checks all of them in priorty order as well as checking for symbol or string.
#
# Order:
#   1. Inputs
#   2. Current
#   3. Object
#   4. Root
#   5. State
#
# @return Value for the given parameter or nil if none is found
def get_param(param)  
  # check if inputs has been set for given param
  param_value ||= $evm.inputs[param.to_sym]
  param_value ||= $evm.inputs[param.to_s]
  
  # else check if current has been set for given param
  param_value ||= $evm.current[param.to_sym]
  param_value ||= $evm.current[param.to_s]
 
  # else cehck if current has been set for given param
  param_value ||= $evm.object[param.to_sym]
  param_value ||= $evm.object[param.to_s]
  
  # else check if param on root has been set for given param
  param_value ||= $evm.root[param.to_sym]
  param_value ||= $evm.root[param.to_s]
  
  # check if state has been set for given param
  param_value ||= $evm.get_state_var(param.to_sym)
  param_value ||= $evm.get_state_var(param.to_s)

  $evm.log(:info, "{ '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
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

# Takes a string and makes it a valid tag name
#
# @param str String to turn into a valid Tag name
#
# @return Given string transformed into a valid Tag name
def to_tag_name(str)
  return str.downcase.gsub(/[^a-z0-9_]+/,'_')
end

# @param visible_and_required Boolean true if the dialog element is visible and required, false if hidden
# @param values               Hash    Values for the dialog element
# @param default_value        String  
def return_dialog_element(visible_and_required, values, default_value = nil)
  # create dialog element
  dialog_field = $evm.object
  dialog_field['data_type']     = "string"
  dialog_field['visible']       = visible_and_required
  dialog_field['required']      = visible_and_required
  dialog_field['values']        = values
  dialog_field['default_value'] = default_value
  $evm.log(:info, "dialog_field['values'] => #{dialog_field['values']}") if @DEBUG
  
  exit MIQ_OK
end

begin
  dump_root()    if @DEBUG
  dump_current() if @DEBUG
  
  # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
  exit MIQ_OK unless $evm.root['vmdb_object_type']
  
  # get the location tags
  location_tags = get_param(:dialog_location_tags)
  location_tags = location_tags.delete_if { |location_tag| location_tag.nil? || location_tag == "NaN" } if !location_tags.blank?
  $evm.log(:info, "location_tags => #{location_tags}") if @DEBUG
  
  # if no location tags selected then hide dialog element
  return_dialog_element(false, {}) if location_tags.empty?
  
  # verify a locaiton is selected for the given index
  location_index = get_param(:location_index)
  return_dialog_element(false, {}) if location_index >= location_tags.length
  $evm.log(:info, "location_index => #{location_index}") if @DEBUG
  
  # get the location tag
  location_tag_name = location_tags[location_index]
  $evm.log(:info, "location_tag_name => #{location_tag_name}") if @DEBUG
  location_tag  = $evm.vmdb(:classification).find_by_name(location_tag_name)
  
  # get satellite API
  satellite_api = get_satellite_api()
  error('Could not get Satellite API') if satellite_api.nil?
  
  # get the satellite location
  location_index = satellite_api.resource(:locations).call(:index)
  $evm.log(:info, "location_index => #{location_index}") if @DEBUG
  satellite_location = location_index['results'].find { |location| to_tag_name(location['title']) == location_tag.name }
  return_dialog_element(true, { nil => "ERROR: Could not find Satellite Location for Location Tag <#{location_tag.description}>" }) if satellite_location.blank?
  $evm.log(:info, "satellite_location => #{satellite_location}") if @DEBUG
  
  # get the domains for the selected location
  domains_index = satellite_api.resource(:domains).call(:index, { :location_id => satellite_location['id'] })
  $evm.log(:info, "domains_index => #{domains_index}") if @DEBUG
  return_dialog_element(true, { nil => "ERROR: Could not find Satellite Domains for Satellite Location <#{satellite_location['title']}>" }) if domains_index['results'].empty?
  
  # return results
  return_dialog_element(
    true,
    Hash[ *domains_index['results'].collect { |item| [item['name'], "#{item['name']} (#{location_tag.description})" ] }.flatten ],
    domains_index['results'][0]['name']
  )
end
