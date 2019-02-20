#
# Description: Collection of Core Methods to use when interacting with Red Hat Satellite 6
#

module RedHatConsulting_Satellite6
  module StdLib
    module SatelliteCore

      require 'apipie-bindings'
      include RedHatConsulting_Utilities::StdLib::Core

      SATELLITE_CONFIG_URI           = 'Integration/Satellite/Configuration/default'

      def initialize( handle = $evm)
        @handle                  = handle
        @DEBUG                   = false
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

        satellite_api = ApipieBindings::API.new({:uri => satellite_server, :username => satellite_username, :password => satellite_password, :api_version => 2})
        log(:info, "satellite_api = #{satellite_api}") if @DEBUG
        return satellite_api

      end

      # Get the Satellite host record for a given host name
      #
      # @param satellite_api ApipieBinding Sattellite API object
      # @param name          String        Name of the host to find the Satelilte host record for
      #
      # @return Hash Satellite host record for the given host name returned from Satellite API
      def get_satellite_host_record(satellite_api, name)
        satellite_host_record = nil
        begin
          satellite_index_result = satellite_api.resource(:hosts).call(:index, {:search => "#{name}"})
          if !satellite_index_result['results'].empty?
            satellite_host_record = satellite_index_result['results'].first

            # get the full record
            satellite_host_record = satellite_api.resource(:hosts).call(:show, {:id => satellite_host_record['id']})

            # NOTE: hopefully this never happens
            # warn if found more then one result
            if satellite_index_result['results'].length > 1
              log(:warn, "More then one Satellite host record found for Host <#{name}>, using first one.")
            end
          end
        rescue RestClient::UnprocessableEntity => e
          error("Error finding Satellite host record for Host <#{name}>. Received an UnprocessableEntity error from Satellite. Check /var/log/foreman/production.log on Satellite for more info.")
        rescue Exception => e
          error("Error finding Satellite host record for Host <#{name}>: #{e.message}")
        end

        return satellite_host_record
      end

      # Get the Satellite Lifecycle environment name
      #
      # @param env_input Satellite Environment ID
      #
      # @return Satellite environment name
      def get_satellite_environment_name_from_id( satellite_environment_id )
        log(:info, "satellite_environment_id => #{satellite_environment_id}") if @DEBUG
        # if the environement ID is really a name return
        return satellite_environment_id unless satellite_environment_id =~ /^[0-9]+$/
        satellite_api              = get_satellite_api()
        begin
          satellite_environment      = satellite_api.resource(:lifecycle_environments).call(:show, {:id => satellite_environment_id})
          satellite_environment_name = satellite_environment['name']
        rescue => e
          error("Error determining Satellite Environment Name from ID: #{e.to_s}")
        end
        return satellite_environment_name
      end

    end
  end
end
