#This class will store any specific differences cheftacular will run into for different providers, usually via the cloud_bootstrap command
class Cheftacular
  class CloudProvider
    def initialize options, config
      @options, @config = options, config
    end

    #public address, private address
    def parse_addresses_from_server_create_hash server_hash
      case @options['preferred_cloud']
      when 'rackspace'
        [server_hash['ipv4_address'], server_hash['addresses']['private'][0]['addr']]
      when 'digitalocean'
        [server_hash['public_ip_address'], server_hash['private_ip_address']]
      else raise "CRITICAL! Encountered unsupported preferred cloud #{ @options['preferred_cloud'] }"
      end
    end

    def parse_server_root_password_from_server_create_hash server_hash, real_node_name
      case @options['preferred_cloud']
      when 'rackspace'
        begin
          server_hash['admin_passwords']["#{ real_node_name }"]
        rescue NoMethodError => e
          raise "Unable to locate an admin pass for server #{ @options['node_name'] }, does the server already exist?"
        end
      when 'digitalocean' #we use sshkey authentication for initial server create for digitalocean
      else raise "CRITICAL! Encountered unsupported preferred cloud #{ @options['preferred_cloud'] }"
      end
    end
  end
end