class Cheftacular
  class StatelessActionDocumentation
    def compile_readme
      @config['documentation']['stateless_action'][__method__] ||= {}
      @config['documentation']['stateless_action'][__method__]['long_description'] = [
        "`cft compile_readme` compiles all documentation methods and creates a README.md file in the log folder of the application."
      ]

      @config['documentation']['stateless_action'][__method__]['short_description'] = 'Compiles and creates a readme based on all accessable commands'
    end
  end

  class InitializationAction
    def compile_readme
      
    end
  end

  class StatelessAction
    def compile_readme out=[]
       @config['action_documentation'].public_methods(false).each do |method|
         @config['action_documentation'].send(method)
      end

      @config['stateless_action_documentation'].public_methods(false).each do |method|
         @config['stateless_action_documentation'].send(method)
      end

      out << '# Table of Contents for Cheftacular Commands'

      out << '1. [Cheftacular Arguments and Flags](https://github.com/SocialCentivPublic/cheftacular/blob/master/lib/cheftacular/README.md#arguments-and-flags-for-cheftacular)'

      out << '2. [Application Commands](https://github.com/SocialCentivPublic/cheftacular/blob/master/lib/cheftacular/README.md#commands-that-can-be-run-in-the-application-context)'

      out << '3. [DevOps Commands](https://github.com/SocialCentivPublic/cheftacular/blob/master/lib/cheftacular/README.md#commands-that-can-only-be-run-in-the-devops-context)' + "\n"
      
      out << @config['documentation']['arguments']

      out << "\n## Commands that can be run in the application context"

      out << @config['helper'].compile_documentation_lines('application')

      out << "\n## Commands that can ONLY be run in the devops context"

      out << @config['helper'].compile_documentation_lines('stateless_action')

      FileUtils.rm("#{ @config['locs']['chef-log'] }/README.md") if File.exist?("#{ @config['locs']['chef-log'] }/README.md")

      File.open("#{ @config['locs']['chef-log'] }/README.md", "w") { |f| f.write(out.flatten.join("\n\n")) }
    end
  end
end
