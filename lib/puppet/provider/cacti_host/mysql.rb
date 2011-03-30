Puppet::Type.type(:cacti_host).provide(:mysql) do
  desc "Use MySQL for the database."

  confine :cacti_db_type => :mysql

  mk_resource_methods

  COLUMNS = [
    'description',
    'hostname',
    'notes',
    'snmp_community',
    'snmp_version',
    'snmp_username',
    'snmp_password',
    'snmp_auth_protocol',
    'snmp_priv_passphrase',
    'snmp_priv_protocol',
    'snmp_context',
    'snmp_port',
    'snmp_timeout',
    'availability_method',
    'ping_method',
    'ping_port',
    'ping_timeout',
    'ping_retries',
    'max_oids',
    'disabled',
  ]

  OVERRIDE = {
    'description'          => 'name',
    'snmp_password'        => 'snmp_auth_password',
    'snmp_priv_passphrase' => 'snmp_priv_password',
    'max_oids'             => 'snmp_max_oids',
  }

  class Hash
    def symbolize_keys
      replace(inject({}) { |h,(k,v)| h[k.to_sym] = v; h })
    end
  end

  def self.prefetch(resources)
    require 'mysql'
    begin
      dbh = Mysql.real_connect(Facter.value(:cacti_db_host), Facter.value(:cacti_db_user), Facter.value(:cacti_db_pass), Facter.value(:cacti_db_name), Facter.value(:cacti_db_port))

      # Build big "foo, bar AS baz, ..." lump of SQL with most of the columns
      sql = COLUMNS.collect { |c| OVERRIDE.has_key?(c) ? "#{c} AS #{OVERRIDE[c]}" : c }.join(', ')

      resources.each do |name,resource|
        res = dbh.query("SELECT #{sql}, COALESCE(name, '') AS host_template FROM host LEFT JOIN host_template ON host.host_template_id = host_template.id WHERE description = '#{name}'")
        if res.num_rows > 0

          # Get a list of fields that should be numeric
          fields = res.fetch_fields.select { |f| f.is_num? }.collect! { |f| f.name }
          res.each_hash do |row|
            # XXX Why do I have to do this?
            fields.each { |field| row[field] = row[field].to_i }
            resource.provider = new({:ensure => :present}.merge!(row.symbolize_keys))
            break
          end
        else
          resource.provider = new(:ensure => :absent)
        end
      end
    rescue Mysql::Error => e
      raise Puppet::Error, "Cannot prefetch hosts: #{e.error}"
    ensure
      dbh.close if dbh
    end
  end
  
  def flush
    require 'mysql'
    begin
      dbh = Mysql.real_connect(Facter.value(:cacti_db_host), Facter.value(:cacti_db_user), Facter.value(:cacti_db_pass), Facter.value(:cacti_db_name), Facter.value(:cacti_db_port))

      res = dbh.query("SELECT id FROM host WHERE description = '#{name}'")
      id = 0
      if res.num_rows > 0 then
        res.each_hash do |row|
          id = row['id'].to_i # Grr
        end
      end

      if @property_hash[:ensure] == :absent and id > 0 then

        # FIXME It would be maybe nice to be able to just nuke the host and
        #       keep the graphs and data sources around like the web interface
        #       offers, but for now, nuking the lot is more consistent

        #unless id > 0
        #  raise Puppet::Error, "We should have a host id to work with"
        #end

        sql = <<-"SQL"
   SELECT data_local.id                      AS local_data_id
        , COALESCE(data_template_data.id, 0) AS data_template_data_id
     FROM data_local
LEFT JOIN data_template_data ON data_local.id = local_data_id
    WHERE host_id = #{id}
        SQL

        # Remove data sources
        res = dbh.query(sql)
        res.each_hash do |row|
          local_data_id         = row['local_data_id'].to_i
          data_template_data_id = row['data_template_data_id'].to_i

          if data_template_data_id > 0
            dbh.query("DELETE FROM data_template_data_rra WHERE data_template_data_id = #{data_template_data_id}")
            dbh.query("DELETE FROM data_input_data WHERE data_template_data_id = #{data_template_data_id}")
          end

          dbh.query("DELETE FROM data_template_data WHERE local_data_id = #{local_data_id}")
          dbh.query("DELETE FROM data_template_rrd WHERE local_data_id = #{local_data_id}")
          dbh.query("DELETE FROM poller_item WHERE local_data_id = #{local_data_id}")
          dbh.query("DELETE FROM data_local WHERE id = #{local_data_id}")
        end

        # Remove graphs
        res = dbh.query("SELECT id AS local_graph_id FROM graph_local WHERE host_id = #{id}")
        res.each_hash do |row|
          local_graph_id = row['local_graph_id'].to_i
          dbh.query("DELETE FROM graph_templates_graph WHERE local_graph_id = #{local_graph_id}")
          dbh.query("DELETE FROM graph_templates_item WHERE local_graph_id = #{local_graph_id}")
          dbh.query("DELETE FROM graph_tree_items WHERE local_graph_id = #{local_graph_id}")
          dbh.query("DELETE FROM graph_local WHERE id = #{local_graph_id}")
        end

        # Remove the host itself
        dbh.query("DELETE FROM host_graph WHERE host_id = #{id}")
        dbh.query("DELETE FROM host_snmp_query WHERE host_id = #{id}")
        dbh.query("DELETE FROM host_snmp_cache WHERE host_id = #{id}")
        dbh.query("DELETE FROM poller_item WHERE host_id = #{id}")
        dbh.query("DELETE FROM poller_reindex WHERE host_id = #{id}")
        dbh.query("DELETE FROM poller_command WHERE command LIKE '#{id}:%'")
        dbh.query("DELETE FROM graph_tree_items WHERE host_id = #{id}")

        dbh.query("DELETE FROM host WHERE id = #{id}")
      elsif @property_hash[:ensure] == :present
        # XXX On updates this is set, but for inserts it doesn't exist
        @property_hash[:name] = name

        # Grab the host_template ID
        template_id = 0
        if @property_hash[:host_template] != ""
          st = dbh.prepare("SELECT id FROM host_template WHERE name = ?")
          st.execute(@property_hash[:host_template])
          while row = st.fetch do
            template_id = row[0]
          end
          st.close
        end

        values = COLUMNS.collect { |c| OVERRIDE.has_key?(c) ? @property_hash[OVERRIDE[c].to_sym] : @property_hash[c.to_sym] }
        values << template_id

        if id > 0 then
          placeholders = COLUMNS.collect { |c| "#{c} = ?" }.join(', ')
          st = dbh.prepare("UPDATE host SET #{placeholders}, host_template_id = ? WHERE id = ?")
          values << id
        else
          columns = COLUMNS.join(', ')
          placeholders  = Array.new(COLUMNS.length) { '?' }.join(', ')
          st = dbh.prepare("INSERT INTO host (#{columns}, host_template_id) VALUES (#{placeholders}, ?)")
        end

        st.execute(*values)
        if st.affected_rows != 1 then
          raise Puppet::Error, "Exactly one row should have been affected"
        end

        st.close
      end
    rescue Mysql::Error => e
      raise Puppet::Error, "Cannot flush host: #{e.error}"
    ensure
      dbh.close if dbh
    end
  end

  def create
    @property_hash[:ensure] = :present
    #@resource.class.validproperties.each do |property|
    #  if value = @resource.should(property)
    #    @property_hash[property] = value
    #  end
    #end
  end

  def destroy
    @property_hash[:ensure] = :absent
  end

  def exists?
    @property_hash[:ensure] != :absent
  end
end
