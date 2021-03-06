class Cheftacular
  class FileSystem
    def initialize options, config
      @options, @config  = options, config
    end

    def log_directories
      ['applog', 'deploy', 'failed-deploy', 'rolelog', 'rvm', 'server-setup', 'stashedlog', 'server-update', 'ssh-exec']
    end

    def write_version_file version
      File.open( current_version_file_path, "w") { |f| f.write(version) }
    end

    def write_nodes_file_cache nodes
      nodes.each do |node|
        File.open( File.join( current_nodes_file_cache_path, "#{ node.name }.json"), "w") { |f| f.write(node.to_json) }
      end
    end

    def write_environment_config_cache
      File.open( current_environment_config_cache_file_path, "w") { |f| f.write("set for #{ Time.now.strftime("%Y%m%d") }") }
    end

    def check_nodes_file_cache nodes=[]
      Dir.entries(current_nodes_file_cache_path).each do |location|
        next if is_junk_filename?(location)

        nodes << @config['ridley'].node.from_file("#{ current_nodes_file_cache_path }/#{ location }" )
      end

      nodes
    end

    def current_version_file_path
      current_file_path 'version-check.txt'
    end

    def current_audit_file_path
      current_file_path 'audit-check.txt'
    end

    def current_environment_config_cache_file_path
      current_file_path 'environment_config-check.txt'
    end

    def is_junk_filename? filename
      filename =~ /.DS_Store|.com.apple.timemachine.supported|README.*/ || filename == '.' || filename == '..' && File.directory?(filename)
    end

    def compare_file_node_cache_against_chef_nodes mode='include?'
      chef_server_names, nodes_file_cache_names = [],[]
      included = true 

      @config['chef_nodes'].each { |node| chef_server_names << node.name }

      check_nodes_file_cache.each { |node| nodes_file_cache_names << node.name }

      nodes_file_cache_names.each do |node_name|
        unless chef_server_names.include?(node_name)
          included = false

          break
        end
      end

      case mode
      when 'include?'  then return included
      when 'not_equal' then return check_nodes_file_cache.count != names.count
      when 'equal'     then return chef_server_names.sort == nodes_file_cache_names.sort
      end
    end

    def current_nodes_file_cache_path
      current_file_path 'node_cache'
    end

    def cleanup_file_caches mode='old', check_current_day_entry=false
      base_dir = File.join( @config['locs']['app-root'], 'tmp', @config['helper'].declassify )

      Dir.entries(base_dir).each do |entry|
        next if is_junk_filename?(entry)
        next if File.file?("#{ base_dir }/#{ entry }") && entry == 'local_cheftacular_cache' && mode != 'all'

        case mode
        when 'old'
          FileUtils.rm("#{ base_dir }/#{ entry }") if File.file?("#{ base_dir }/#{ entry }") && !entry.include?(Time.now.strftime("%Y%m%d"))
        when 'current-nodes'
          check_current_day_entry = true
        when 'all'
          FileUtils.rm("#{ base_dir }/#{ entry }") if File.file?("#{ base_dir }/#{ entry }")

          FileUtils.rm_rf("#{ base_dir }/#{ entry }") if File.exists?("#{ base_dir }/#{ entry }") && File.directory?("#{ base_dir }/#{ entry }")
        when 'current-audit-only'
          FileUtils.rm("#{ base_dir }/#{ entry }") if File.file?("#{ base_dir }/#{ entry }") && entry.include?(Time.now.strftime("%Y%m%d"))
        else
          puts "Warning, received unknown mode (#{ mode })! Please post your logs as an issue on github!"
        end

        if File.exists?("#{ base_dir }/#{ entry }") && File.directory?("#{ base_dir }/#{ entry }")
          FileUtils.rm_rf("#{ base_dir }/#{ entry }") if !check_current_day_entry && !entry.include?(Time.now.strftime("%Y%m%d"))
          
          FileUtils.rm_rf("#{ base_dir }/#{ entry }") if check_current_day_entry && entry.include?(Time.now.strftime("%Y%m%d"))

          FileUtils.mkdir_p current_nodes_file_cache_path
        end
      end
    end

    def remove_current_file_node_cache
      base_dir = File.join( @config['locs']['app-root'], 'tmp', @config['helper'].declassify )

      Dir.entries(base_dir).each do |entry|
        next if is_junk_filename?(entry)

        FileUtils.rm_rf("#{ base_dir }/#{ entry }") if File.directory?("#{ base_dir }/#{ entry }") && entry.include?(Time.now.strftime("%Y%m%d"))
      end      
    end

    def current_chef_repo_cheftacular_file_cache_path
      current_file_path "chef_repo_cheftacular_cache"
    end

    def local_cheftacular_file_cache_path
      current_file_path "local_cheftacular_cache", false
    end

    def write_chef_repo_cheftacular_cache_file hash
      File.open( current_chef_repo_cheftacular_file_cache_path, "w") { |f| f.write(hash) }
    end

    def write_local_cheftacular_cache_file hash_string
      File.open( local_cheftacular_file_cache_path, 'w') { |f| f.write(hash_string) }
    end

    def write_chef_repo_cheftacular_yml_file file_location
      File.open( file_location, "w") { |f| f.write(@config['helper'].compile_chef_repo_cheftacular_yml_as_hash.to_yaml) }
    end

    def write_config_cheftacular_yml_file to_be_created_filename='cheftacular.yml', example_filename='cheftacular.yml'
      File.open( File.join(@config['locs']['chef-repo'], "config", to_be_created_filename), "w") { |f| f.write(File.read(File.join(@config['locs']['examples'], example_filename))) }
    end

    def parse_berkshelf_cookbook_versions version='latest', berkshelf_cookbooks={}

      Dir.foreach(@config['locs']['berks']) do |berkshelf_cookbook|
        next if is_junk_filename?(berkshelf_cookbook)
        use_current_cookbook = false

        true_cookbook_name = berkshelf_cookbook.rpartition('-').first
        cookbook_version   = parse_version_from_berkshelf_cookbook(berkshelf_cookbook)

        #get only the latest version, berkshelf pulls in multiple commits from git repos for SOME REASON
        use_current_cookbook = !berkshelf_cookbooks.has_key?(true_cookbook_name)

        if version == 'latest'
          use_current_cookbook = @config['helper'].is_higher_version?(cookbook_version, berkshelf_cookbooks[true_cookbook_name]['version']) if berkshelf_cookbooks.has_key?(true_cookbook_name)
        else
          use_current_cookbook = true if berkshelf_cookbooks.has_key?(true_cookbook_name) && cookbook_version == version
        end

        if use_current_cookbook
          berkshelf_cookbooks[true_cookbook_name] ||= {}
          berkshelf_cookbooks[true_cookbook_name]['version']  = cookbook_version
          berkshelf_cookbooks[true_cookbook_name]['location'] = berkshelf_cookbook
          berkshelf_cookbooks[true_cookbook_name]['mtime']    = File.mtime(File.expand_path("#{ @config['locs']['berks'] }/#{ berkshelf_cookbook }"))
        end
      end

      berkshelf_cookbooks
    end

    def parse_chef_repo_cookbook_versions chef_repo_cookbooks={}
      Dir.foreach(@config['locs']['cookbooks']) do |chef_repo_cookbook|
        next if is_junk_filename?(chef_repo_cookbook)
          
        new_name = chef_repo_cookbook.rpartition('-').first

        chef_repo_cookbooks[chef_repo_cookbook] = if File.exists?(File.expand_path("#{ @config['locs']['cookbooks'] }/#{ chef_repo_cookbook }/metadata.rb"))
                                                    File.read(File.expand_path("#{ @config['locs']['cookbooks'] }/#{ chef_repo_cookbook }/metadata.rb")).gsub('"',"'").gsub(/^version[\s]*('\d[.\d]+')/).peek[/('\d[.\d]+')/].gsub("'",'')
                                                  else
                                                    JSON.parse(File.read(File.expand_path("#{ @config['locs']['cookbooks'] }/#{ chef_repo_cookbook }/metadata.json"))).to_hash['version']
                                                  end
      end

      chef_repo_cookbooks
    end

    def parse_version_from_berkshelf_cookbook berkshelf_cookbook
      if File.exists?(File.expand_path("#{ @config['locs']['berks'] }/#{ berkshelf_cookbook }/metadata.rb"))
        File.read(File.expand_path("#{ @config['locs']['berks'] }/#{ berkshelf_cookbook }/metadata.rb")).gsub('"',"'").gsub(/^version[\s]*('\d[.\d]+')/).peek[/('\d[.\d]+')/].gsub("'",'')
      else
        berkshelf_cookbook.split('-').last
      end
    end

    def parse_gemfile_gem_version gem_name
      File.read(File.expand_path("#{ @config['locs']['root'] }/Gemfile"))[/#{ gem_name }.*([\d\.]+)/][/([\d\.]+)/]
    end

    def scrub_from_known_hosts target
      puts "Clearing #{ target } from known_hosts file."
      case RbConfig::CONFIG['host_os']
      when /mswin|windows/i
        puts "#{ __method__ } does not support this operating system at this time"
      when /linux|arch/i
        puts "#{ __method__ } does not support this operating system at this time"
      when /sunos|solaris/i
        puts "#{ __method__ } does not support this operating system at this time"
      when /darwin/i
        #Removes the entire line containing the string
        `sed -i '' "s/#{ target }.*//g" ~/.ssh/known_hosts`

        #remove empty lines
        `sed -i '' "/^$/d" ~/.ssh/known_hosts`
      else
        puts "#{ __method__ } does not support this operating system at this time"
      end
    end

    def initialize_log_directories should_cleanup_file_caches=true
      log_directories.each do |sub_log_directory|
        FileUtils.mkdir_p File.join( @config['locs']['chef-log'], sub_log_directory )
      end

      FileUtils.mkdir_p File.join( @config['locs']['app-tmp'], @config['helper'].declassify)

      FileUtils.mkdir_p @config['filesystem'].current_nodes_file_cache_path

      cleanup_file_caches if should_cleanup_file_caches
    end

    def remove_log_directories directories_to_not_remove_array=[]
      (log_directories - directories_to_not_remove_array).each do |log_directory|
        FileUtils.rm_rf File.join( @config['locs']['chef-log'], log_directory.strip )
      end
    end

    def generate_report_from_node_hash report_name, node_hash={}, out=[]
      node_hash.each_pair do |serv_name, output|
        out << "#{ serv_name }:"

        output.join("\n").split("\n").each do |line|
          out << " #{ line }"
        end

        out << "\n"
      end

      puts(out) if @options['no_logs'] || @options['verbose']

      log_loc, timestamp = @config['helper'].set_log_loc_and_timestamp

      puts("Generating log file for #{ report_name } at #{ log_loc }/#{ report_name.gsub(' ', '-') }-#{ timestamp }.txt") unless @options['quiet']

      File.open("#{ log_loc }/#{ report_name.gsub(' ', '-') }-#{ timestamp }.txt", "w") { |f| f.write(out.join("\n").scrub_pretty_text) } unless @options['no_logs']
    end

    private
    def current_file_path file_name, use_timestamp=true
      File.join( @config['locs']['app-root'], 'tmp', @config['helper'].declassify, ( use_timestamp ? "#{ Time.now.strftime("%Y%m%d") }-#{ file_name }" : file_name ))
    end
  end
end
