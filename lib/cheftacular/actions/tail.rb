class Cheftacular
  class ActionDocumentation
    def tail
      @config['documentation']['action'][__method__] ||= {}
      @config['documentation']['action'][__method__]['long_description'] = [
        "`cft tail [PATTERN_TO_MATCH]` will tail the logs (return continuous output) of the first node if finds " + 
        "that has an application matching the repository running on it. Currently only supports rails stacks",

        [
          "    1. pass `-n NODE_NAME` to grab the output of a node other than the first.",

          "    2. Workers and job servers change the output of this command heavily. " +
          "Worker and job servers should tail their log to the master log (/var/log/syslog) where <b>all</b> of the major processes on the server output to. " +
          "While the vast majority of this syslog will be relevant to application developers, some will not (usually firewall blocks and the like).",

          "    3. if the `PATTERN_TO_MATCH` argument exists, the tail will only return entries that have that pattern rather than everything written to the file.",

          "    4. If `--nginx` is specified, the tail will instead try and fetch data from the nginx instance on the matching node rather than the default."
        ]
      ]

      @config['documentation']['action'][__method__]['short_description'] = 'Tails the logs of the first node found for the current repository'
    end
  end

  class Action
    def tail pattern_to_match=''
      pattern_to_match = ARGV[1] if pattern_to_match.blank?

      nodes = @config['getter'].get_true_node_objects

      nodes = @config['parser'].exclude_nodes( nodes, [{ unless: "role[#{ @options['role'] }]" }], true )

      nodes = @config['parser'].exclude_nodes( nodes, [{ if: "role[#{ @options['negative_role'] }]" }], true) if @options['negative_role']

      nodes.each do |n|
        puts("Beginning tail run for #{ n.name } (#{ n.public_ipaddress }) on role #{ @options['role'] }") unless @options['quiet']

        if @config['dummy_sshkit'].has_run_list_in_role_map?(n.run_list, @config['cheftacular']['role_maps'])
          start_tail_role_map( n.public_ipaddress, n.run_list, pattern_to_match )
        elsif @options['get_nginx_logs']
          start_tail_role_map( n.public_ipaddress, n.run_list, pattern_to_match, "/var/log/nginx/#{ @options['repository'] }_access.log")
        else
          self.send("start_tail_#{ @config['getter'].get_current_stack }", n.public_ipaddress, n.run_list, pattern_to_match )
        end
      end
    end

    private

    def start_tail_role_map ip_address, run_list, pattern_to_match, log_loc='default'
      log_loc = @config['getter'].get_current_role_map(run_list)['log_location'].split(',').first.gsub('|current_repo_location|', "#{ @config['cheftacular']['base_file_path'] }/#{ @options['repository'] }/current") if log_loc == 'default'

      `ssh #{ Cheftacular::SSH_INLINE_VARS } -tt #{ @config['cheftacular']['deploy_user'] }@#{ ip_address } "#{ @config['helper'].sudo(ip_address) } tail -f #{ log_loc } #{ get_tail_grep_string(pattern_to_match) }" > /dev/tty`
    end

    def start_tail_ruby_on_rails ip_address, run_list, pattern_to_match
      true_env = @config['dummy_sshkit'].get_true_environment run_list, @config['cheftacular']['run_list_environments'][@options['env']], @options['env']
      true_env = @config['dummy_sshkit'].get_override_environment @config['cheftacular']['repositories'][@options['role']], @options['env']

      #special servers should be listed first as most of them will have web role
      log_loc = "#{ @config['cheftacular']['base_file_path'] }/#{ @options['repository'] }/current/log/#{ true_env }.log"

      `ssh #{ Cheftacular::SSH_INLINE_VARS } -tt #{ @config['cheftacular']['deploy_user'] }@#{ ip_address } "#{ @config['helper'].sudo(ip_address) } tail -f #{ log_loc } #{ get_tail_grep_string(pattern_to_match) }" > /dev/tty`
    end

    def start_tail_nodejs ip_address, run_list, pattern_to_match
      log_loc = "/var/log/syslog"

      `ssh #{ Cheftacular::SSH_INLINE_VARS } -tt #{ @config['cheftacular']['deploy_user'] }@#{ ip_address } "#{ @config['helper'].sudo(ip_address) } tail -f #{ log_loc } #{ get_tail_grep_string(pattern_to_match) }" > /dev/tty`
    end

    def get_tail_grep_string pattern_to_match=''
      "| grep -i -E \\\"#{ pattern_to_match }\\\"" unless pattern_to_match.blank?
    end
  end
end
