class Cheftacular
  class StatelessActionDocumentation
    def help
      @config['documentation']['stateless_action'][__method__] ||= {}
      @config['documentation']['stateless_action'][__method__]['long_description'] = [
        "`cft help COMMAND|MODE` this command returns the documentation for a specific command if COMMAND matches the name of a command. " +
        "Alternatively, it can be passed `action|arguments|application|current|devops|stateless_action` to fetch the commands for a specific mode." +
        "Misspellings of commands will display near hits."
      ]

      @config['documentation']['stateless_action'][__method__]['short_description'] = 'Displays useful help related information based on the current context'

      @config['documentation']['application'][__method__] = @config['documentation']['stateless_action'][__method__]
    end
  end

  class InitializationAction
    def help
      
    end
  end

  class StatelessAction
    def help inference_modes=[]
      target_command   = @options['command'] == 'help' ? ARGV[1] : ARGV[0]
      target_command   = @config['cheftacular']['mode'] if target_command == 'current'
      target_command ||= ''

      case target_command
      when 'action'                  then inference_modes << 'action'
      when 'application' || 'devops' then inference_modes << 'both'
      when 'stateless_action'        then inference_modes << 'stateless_action'
      when ''                        then inference_modes << 'short_context_descriptions'
      end

      if @config['helper'].is_command? target_command
        @config['action_documentation'].send(target_command)

        puts @config['documentation']['action'][target_command.to_sym]['long_description'].flatten.join("\n\n")
      elsif @config['helper'].is_stateless_command? target_command
        @config['stateless_action_documentation'].send(target_command)

        puts @config['documentation']['stateless_action'][target_command.to_sym]['long_description'].flatten.join("\n\n")
      end

      if inference_modes.include?('action') || inference_modes.include?('both') || inference_modes.include?('short_context_descriptions')
        @config['action_documentation'].public_methods(false).each do |method|
          @config['action_documentation'].send(method)
        end
      end

      if inference_modes.include?('action') || inference_modes.include?('both') || inference_modes.include?('short_context_descriptions')
 
        @config['stateless_action_documentation'].public_methods(false).each do |method|
          @config['stateless_action_documentation'].send(method)
        end
      end

      puts @config['documentation']['arguments'].flatten.join("\n\n") if target_command == 'arguments'

      if inference_modes.include?('short_context_descriptions')
        if @config['helper'].running_in_mode?('devops')
          puts @config['helper'].compile_short_context_descriptions(@config['documentation']['action'].merge(@config['documentation']['stateless_action']), 35)
        else
          puts @config['helper'].compile_short_context_descriptions(@config['documentation']['action'].merge(@config['documentation']['application']))
        end
      end
      
      puts @config['helper'].compile_documentation_lines(target_command).flatten.join("\n\n") if target_command =~ /action|stateless_action|application|devops/

      if inference_modes.empty? && @config['helper'].is_not_command_or_stateless_command?(target_command)
        methods = @config['action_documentation'].public_methods(false) + @config['stateless_action_documentation'].public_methods(false)

        sorted_methods = methods.uniq.sort_by { |method| @config['helper'].compare_strings(target_command, method.to_s)}

        puts "Unable to find documentation for #{ target_command }, did you mean:"
        puts "    #{ sorted_methods.at(0) }"
        puts "    #{ sorted_methods.at(1) }"
        puts "    #{ sorted_methods.at(2) }\n"
        puts "If so, please run 'cft help COMMAND' with one of the above commands or run 'cft help #{ @config['cheftacular']['mode'] }' to see a list of commands"
      end
    end
  end
end
