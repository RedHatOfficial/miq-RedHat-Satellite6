# Populates a dynamic drop down with the Lifecycle Enviornments from a Satellite Organization
# filtered by tags on the providers available.
#
# Inputs:
# - return_key - string - determines if hash returned from dialog element provides name or ID. e.g { id => name } or { name => name }
#   - acceptable values - 'name' or 'id'
#   - default value - 'id'

require 'apipie-bindings'

module RedHatConsulting_Satellite6
  module Automate
    module Integration
      module Satellite
        module DynamicDialogs
          class GetLifecycleEnvironmentsFilteredByTags
            include RedHatConsulting_Utilities::StdLib::Core

            TAG_CATEGORY = 'environment'
            SATELLITE_CONFIG_URI = 'Integration/Satellite/Configuration/default'

            def initialize(handle = $evm)
              @handle = handle
              @DEBUG = false
            end

            def main

              # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
              exit MIQ_OK unless @handle.root['vmdb_object_type']

              satellite_api = get_satellite_api()

              satellite_organization_id = @handle.root['dialog_satellite_organization_id']
              log(:info, "satellite_organization_id = #{satellite_organization_id}") if @DEBUG
              
              param_return_key = get_param(:return_key)
              log(:info, "Method input return_key => <#{param_return_key}>") if @DEBUG
              return_key = param_return_key.downcase == 'name' ? 'name' : 'id' rescue 'id'
              log(:info, "Returning Dialog element values based on <#{return_key}>") if @DEBUG

              if !satellite_organization_id.length.zero?
                environments_index = satellite_api.resource(:lifecycle_environments).call(:index,{:organization_id => satellite_organization_id})
                log(:info, "environments_index = #{environments_index}") if @DEBUG
                dialog_field_values = Hash[ *environments_index['results'].collect { |item| [item[return_key], item['name']] }.flatten ]
                log(:info, "Environment dialog_field_values = #{dialog_field_values}") if @DEBUG
              else
                dialog_field_values = {}
              end

              log(:info, "dialog_field_values pre filtering: #{dialog_field_values}") if @DEBUG
              dialog_field_values.each do | key, name|
                create_tag(TAG_CATEGORY, name)
              end

              providers = @handle.vmdb(:ems).all
              dialog_field_values.delete_if do |id, name|
                provider_tagged      = false
                tag_name = to_tag_name(name)

                providers.each do |provider|
                  provider_tagged = provider.tagged_with?(TAG_CATEGORY, tag_name)
                  log(:info, "Provider '#{provider.name}' tagged with: #{TAG_CATEGORY} => #{tag_name}") if @DEBUG && provider_tagged
                  break if provider_tagged
                end
                log(:info, "No provider tagged with: #{TAG_CATEGORY} => #{tag_name}") if @DEBUG && !provider_tagged
                !provider_tagged
              end
              log(:info, "dialog_field_values post filtering: #{dialog_field_values}") if @DEBUG


              dialog_field_values['!']   = '--- Select Environment From List ---'
              dialog_field               = @handle.object
              dialog_field["sort_by"]    = "value"
              dialog_field["sort_order"] = "ascending"
              dialog_field["data_type"]  = "string"
              dialog_field["required"]   = true
              dialog_field["values"]     = dialog_field_values

              exit MIQ_OK

            end

            # Gets all of the Tags in a given Tag Category
            #
            # @param category Tag Category to get all of the Tags for
            #
            # @return Hash of Tag names mapped to Tag descriptions
            #
            # @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/using_tags_from_automate/chapter.html#_getting_the_list_of_tags_in_a_category
            def get_category_tags(category)
              classification = @handle.vmdb(:classification).find_by_name(category)
              tags = {}
              @handle.vmdb(:classification).where(:parent_id => classification.id).each do |tag|
                tags[tag.name] = tag.description
              end

              return tags
            end

            # Create a Tag in a given Category if it does not already exist
            #
            # @param category Tag Category to create the Tag in
            # @param tag      Tag to create in the given Tag Category
            #
            # @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/using_tags_from_automate/chapter.html
            def create_tag(category, tag)
              create_tag_category(category)
              tag_name = to_tag_name(tag)
              unless @handle.execute('tag_exists?', category, tag_name)
                @handle.execute('tag_create',
                             category,
                             :name => tag_name,
                             :description => tag)
              end
            end

            # Create a Tag  Category if it does not already exist
            #
            # @param category     Tag Category to create
            # @param description  Tag Category description.
            #                     Optional
            #                     Defaults to the `category`
            # @param single_value True if a resource can only have one tag from this category,
            #                     False if a resource can have multiple tags from this category.
            #                     Optional.
            #                     Defaults to `false`
            #
            # @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/using_tags_from_automate/chapter.html
            def create_tag_category(category, description = nil, single_value = false)
              category_name = to_tag_name(category)
              unless @handle.execute('category_exists?', category_name)
                @handle.execute('category_create',
                             :name => category_name,
                             :single_value => single_value,
                             :perf_by_tag => false,
                             :description => description || category)
              end
            end

            # Takes a string and makes it a valid tag name
            #
            # @param str String to turn into a valid Tag name
            #
            # @return Given string transformed into a valid Tag name
            def to_tag_name(str)
              return str.downcase.gsub(/[^a-z0-9_]+/,'_')
            end

            # Gets an ApiPie binding to the Satellite API.
            #
            # @return ApipieBindings to the Satellite API
            def get_satellite_api()
              satellite_config = @handle.instantiate(SATELLITE_CONFIG_URI)
              error("Satellite Configuration not found") if satellite_config.nil?

              satellite_server   = satellite_config['satellite_server']
              satellite_username = satellite_config['satellite_username']
              satellite_password = satellite_config.decrypt('satellite_password')

              log(:info, "satellite_server   = #{satellite_server}") if @DEBUG
              log(:info, "satellite_username = #{satellite_username}") if @DEBUG

              error("Satellite Server configuration not found")   if satellite_server.nil?
              error("Satellite User configuration not found")     if satellite_username.nil?
              error("Satellite Password configuration not found") if satellite_password.nil?

              satellite_api = ApipieBindings::API.new({:uri => satellite_server, :username => satellite_username, :password => satellite_password, :api_version => 2, :apidoc_cache_dir => "/tmp/foreman" }, {:verify_ssl => false})
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
  RedHatConsulting_Satellite6::Automate::Integration::Satellite::DynamicDialogs::GetLifecycleEnvironmentsFilteredByTags.new.main
end
