# Creates a dialog element with a yaml dump of information about a valid template for each
# selected destination location for the selected OS version and Environment.
#
# Parameters
#   dialog_os_tag
#   dialog_location_tags
#   dialog_satellite_environment_name or dialog_satellite_environment_id

require 'yaml'
require 'apipie-bindings'

module RedHatConsulting_Satellite6
  module Automate
    module Integration
      module Satellite
        module DynamicDialogs
          class GetTemplatesBasedOnSelectedOsAndLocationAndEnvironment
            include RedHatConsulting_Utilities::StdLib::Core

            SATELLITE_CONFIG_URI           = 'Integration/Satellite/Configuration/default'
            OS_TAG_DIALOG_OPTION           = 'dialog_os_tag'
            LOCATION_TAGS_DIALOG_OPTION    = 'dialog_location_tags'
            ENVIRONMENT_NAME_DIALOG_OPTION = 'dialog_satellite_environment_name'
            ENVIRONMENT_ID_DIALOG_OPTION   = 'dialog_satellite_environment_id'
            ENVIRONMENT_TAG_CATEGORY       = 'environment'

            def initialize(handle = $evm)
              @handle = handle
              @DEBUG = false
            end

            def main
              dump_root()    if @DEBUG

              # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
              exit MIQ_OK unless @handle.root['vmdb_object_type']

              # get parameters
              os_tag                = @handle.root[OS_TAG_DIALOG_OPTION]
              location_tags         = @handle.root[LOCATION_TAGS_DIALOG_OPTION] || []
              environment_name      = get_environment_name()
              log(:info, "os_tag               => #{os_tag}")               if @DEBUG
              log(:info, "location_tags        => #{location_tags}")        if @DEBUG
              log(:info, "environment_tag_name => #{environment_tag_name}") if @DEBUG

              invalid_selection = false
              value = []

              # invalid if no os template tag(s) selected
              if os_tag.blank?
                invalid_selection = true
                value << "OS must be selected to determine valid destination providers."
              end

              # invalid if no environment is selected
              if environment_name.blank?
                invalid_selection = true
                value << "Environment must be selected to determine valid destination providers."
              else
                environment_tag_name  = "#{ENVIRONMENT_TAG_CATEGORY}/#{to_tag_name(environment_name)}"
                log(:info, "environment_tag_name => #{environment_tag_name}") if @DEBUG
              end

              # invalid if no location tags selected
              location_tags.delete("null")
              location_tags.delete("[]")
              if location_tags.empty?
                invalid_selection = true
                value << "Destination location(s) must be selected to determine valid destination providers."
              end

              # find appropriatlly tagged providers
              providers_by_tag = {}
              if !invalid_selection
                environment_tag_path     = "/managed/#{environment_tag_name}"
                environment_tag          = @handle.vmdb(:classification).find_by_name(environment_tag_name)
                log(:info, "environment_tag_name => '#{environment_tag_name}', tag => #{environment_tag}") if @DEBUG
                
                environment_tagged_providers = @handle.vmdb(:ext_management_system).find_tagged_with(:all => environment_tag_path, :ns => "*")
                if environment_tagged_providers.empty?
                  invalid_selection = true
                  value << "Could Not Find Destination Provider with Tags <#{environment_tag.parent.description}: #{environment_tag.description}>." unless environment_tag.blank?
                  value << "Invalid environment Tag provided: <#{environment_tag_name}>"                                                            if environment_tag.blank?
                end
                
                if @DEBUG
                  log(:info, "There are [#{environment_tagged_providers.length}] provider(s) tagged with #{environment_tag_name}:")
                  environment_tagged_providers.each do |provider|
                    log(:info, "\tProvider tagged with #{environment_tag_name}: #{provider.name}")
                  end
                end
                
              end

              if !invalid_selection
                location_tags.each do |location_tag_name|
                  location_tag_path    = "/managed/#{location_tag_name}"
                  log(:info, "location_tag_path => #{location_tag_path}") if @DEBUG

                  location_tagged_providers = @handle.vmdb(:ext_management_system).find_tagged_with(:all => location_tag_path, :ns => "*")
              
                  if @DEBUG
                    log(:info, "There are [#{location_tagged_providers.length}] provider(s) tagged with #{location_tag_name}:")
                    location_tagged_providers.each do |provider|
                      log(:info, "\tProvider tagged with #{location_tag_name}: #{provider.name}")
                    end
                  end
                  
                  # get intersection of providers with location tag and providers with environment tag
                  tagged_providers =  location_tagged_providers.reject { |provider| !provider.tagged_with?(ENVIRONMENT_TAG_CATEGORY, to_tag_name(environment_name)) }
                  
                  if @DEBUG
                    log(:info, "There are [#{tagged_providers.length}] provider(s) tagged with both #{location_tag_name} and #{environment_tag_name}:")
                    tagged_providers.each do |provider|
                      log(:info, "\tProvider location and environment: #{provider.name}")
                    end
                  end


                  if tagged_providers.empty?
                    location_tag    = @handle.vmdb(:classification).find_by_name(location_tag_name)
                    log(:info, "location_tag_name => '#{location_tag_name}', tag => #{location_tag}")     if @DEBUG
                    invalid_selection = true
                    value << "Could not find Provider with Tags <#{location_tag.parent.description}: #{location_tag.description}>" unless location_tag.blank?
                    value << "Invalid location Tag provided: <#{location_tag_name}>"                                               if location_tag.blank?
                  else
                    providers_by_tag[location_tag_name] = tagged_providers
                  end
                end
                log(:info, "providers_by_tag => #{providers_by_tag}")              if @DEBUG
              end

              if !invalid_selection
                # ensure there are templates tagged with the correct OS
                tagged_templates = @handle.vmdb(:VmOrTemplate).find_tagged_with(:all => "/managed/#{os_tag}", :ns => "*")
                tagged_templates.select! { |tagged_template| tagged_template.template }
                log(:info, "tagged_templates => #{tagged_templates}") if @DEBUG
                if tagged_templates.empty?
                  template_tag = @handle.vmdb(:classification).find_by_name(os_tag)
                  invalid_selection = true
                  value << "Could not find any Templates with Tag <#{template_tag.parent.description}: #{template_tag.description}>"
                end

                # sort templates tagged with the correct OS by the correctly tagged provider they line up with
                templates_by_provider_tag = {}
                tagged_templates.each do |tagged_template|
                  template_provider = tagged_template.ext_management_system
                  providers_by_tag.each do |location_tag_name, providers|
                    if providers.collect {|provider| provider.id}.include?(template_provider.id)
                      templates_by_provider_tag[location_tag_name] ||= []
                      templates_by_provider_tag[location_tag_name] << tagged_template
                    end
                  end
                end
                log(:info, "templates_by_provider_tag => #{templates_by_provider_tag}") if @DEBUG

                # determine the selected templates
                selected_templates = []
                location_tags.each do |location_tag_name|
                  provider_tag = @handle.vmdb(:classification).find_by_name(location_tag_name)
                  template_tag = @handle.vmdb(:classification).find_by_name(os_tag)
                  if templates_by_provider_tag[location_tag_name].blank?
                    invalid_selection = true
                    value << "Could not find Template with Tag <#{template_tag.parent.description}: #{template_tag.description}> on a Provider with Tag <#{provider_tag.parent.description}: #{provider_tag.description}>"
                  else
                    # NOTE: just choose the first valid one and warn if there was more then one valid selection
                    selected_templates << templates_by_provider_tag[location_tag_name].first
                    log(:warn, "More then one valid Template available with Tag <#{template_tag.parent.description}: #{template_tag.description}> " +
                                    "on a Provider with Tag <#{provider_tag.parent.description}: #{provider_tag.description}>") if templates_by_provider_tag[location_tag_name].length > 1
                  end
                end
              end

              # if invalid selection prepend a note as such
              # else valid selection, list selected providers
              if invalid_selection
                value.map! { |v| "    * #{v}" }
                value.unshift('INVALID SELECTION')
                value = value.join("\n")
              else
                value = []
                selected_templates.each do |selected_template|
                  # add the provider options
                  value << {
                    :provider => selected_template.ext_management_system.name,
                    :name     => selected_template.name,
                    :guid     => selected_template.guid
                  }
                end
                value = value.to_yaml
              end

              # create dialog element
              dialog_field = @handle.object
              dialog_field["data_type"]  = "string"
              dialog_field['read_only']  = true
              dialog_field['value']      = value
              log(:info, "value => #{value}") if @DEBUG
            end


            # Takes a string and makes it a valid tag name
            #
            # @param str String to turn into a valid Tag name
            #
            # @return Given string transformed into a valid Tag name
            def to_tag_name(str)
              return str.downcase.gsub(/[^a-z0-9_]+/,'_')
            end

            def get_environment_name()
              # determine environment
              satellite_environment_name = @handle.root[ENVIRONMENT_NAME_DIALOG_OPTION]
              satellite_environment_id   = @handle.root[ENVIRONMENT_ID_DIALOG_OPTION]
              # return nil if the dialog elements have not been selected yet
              return nil if satellite_environment_name.blank? and satellite_environment_id.blank?
              return nil if satellite_environment_name == '!' or satellite_environment_id == '!'
                  
              # if the satellite enviornment name is actually an ID
              # else if satellite envirnonment name not given check for satellite environment id
              if satellite_environment_name =~ /^[0-9]+$/
                satellite_environment_id = satellite_environment_name.to_i
              end
             
              if !satellite_environment_id.blank?
                log(:info, "satellite_environment_id => #{satellite_environment_id}") if @DEBUG
                satellite_api              = get_satellite_api()
                begin
                  satellite_environment      = satellite_api.resource(:lifecycle_environments).call(:show, {:id => satellite_environment_id})
                  satellite_environment_name = satellite_environment['name']
                rescue => e
                  error("Error invoking Satellite API: #{e.to_s}")
                end
              end
              log(:error, "One of <satellite_environment_name, satellite_environment_id> must be specified.") if satellite_environment_name.blank?
              return satellite_environment_name
            end

            def get_satellite_api()
              satellite_config = $evm.instantiate(SATELLITE_CONFIG_URI)
              error("Satellite Configuration not found") if satellite_config.nil?
              
              satellite_server   = satellite_config['satellite_server']
              satellite_username = satellite_config['satellite_username']
              satellite_password = satellite_config.decrypt('satellite_password')
              
              log(:info, "satellite_server   = #{satellite_server}") if @DEBUG
              log(:info, "satellite_username = #{satellite_username}") if @DEBUG
              
              error("Satellite Server configuration not found")   if satellite_server.nil?
              error("Satellite User configuration not found")     if satellite_username.nil?
              error("Satellite Password configuration not found") if satellite_password.nil?
              
              satellite_api = ApipieBindings::API.new({:uri => satellite_server, :username => satellite_username, :password => satellite_password, :api_version => 2})
              log(:info, "satellite_api = #{satellite_api}") if @DEBUG
              return satellite_api
            end

          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RedHatConsulting_Satellite6::Automate::Integration::Satellite::DynamicDialogs::GetTemplatesBasedOnSelectedOsAndLocationAndEnvironment.new.main
end
