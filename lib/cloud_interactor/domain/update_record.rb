class CloudInteractor
  class Domain
    def update_record args, already_created=false
      args['type']          ||= 'A'
      args['ttl']           ||= 300
      args['target_domain'] ||= @classes['clouds'].parse_provider_domain_record_name(args)
      args['target_domain']   = args[IDENTITY.singularize] if args['subdomain'].blank?

      read args, false

      puts "(#{ IDENTITY.capitalize }) Updating #{ args['subdomain'] } for #{ args[IDENTITY.singularize] }..."

      @main_obj['specific_records'][args[IDENTITY.singularize]].each do |record_hash|
        already_created = true if record_hash['name'] == args['target_domain'] && record_hash['type'] == args['type']

        args['id'] = record_hash['id']

        break if already_created
      end

      if already_created
        specific_fog_object = @classes['auth'].auth_service(RESOURCE).instance_eval('zones').get @main_obj["specific_#{ IDENTITY }"].last['id']

        #the fact that there is no public update method is silly
        specific_record = specific_fog_object.records.get(args['id'])

        case @options['route_dns_changes_via']
        when /rackspace|dnsimple/
          begin
            specific_record.type  = args['type']
            specific_record.value = args['target_ip']
            specific_record.ttl   = args['ttl']

            specific_record.save
          rescue Fog::Errors::Error => e
            tries ||= 3
            puts "Issue updating records for the domain #{ args[IDENTITY.singularize] }! Error: #{e}. Trying #{tries} more times."
            tries -= 1
            if tries > 0
              sleep(15)
              retry
            else
              false
            end
          end
        else
          raise "Unsupported action #{ __method__ } for #{ @options['preferred_cloud'] }. Please create an issue on github or submit a PR to fix this issue."
        end

        puts "(#{ IDENTITY.capitalize }) Updated #{ args['subdomain'] } (#{ args['target_ip'] }) to #{ args[IDENTITY.singularize] } (#{ args['target_domain'] })..."
      else
        tries = 3
        
        create_record [ args ]
      end
    end
  end
end
