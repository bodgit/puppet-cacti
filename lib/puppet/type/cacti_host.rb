Puppet::Type.newtype(:cacti_host) do
  @doc = "Manage a host to be monitored by Cacti."

  ensurable

  newparam(:name) do
    desc "The description of the host."

    isnamevar
  end

  newproperty(:hostname) do
    desc "Fully qualified hostname or IP address for this host."
  end

  newproperty(:snmp_version) do
    desc "Supported SNMP version for this host."

    newvalues(1, 2, 3)

    munge do |value|
      value.to_i
    end
  end

  newproperty(:snmp_community) do
    desc "SNMP community string for version 1 or 2."

    validate do |value|
      if value != "" and value !~ /^[a-zA-Z0-9\-_]{1,32}$/
        raise ArgumentError, "%s is not a valid SNMP community string" % value
      end
    end

    defaultto ""
  end

  newproperty(:snmp_username) do
    desc "SNMP username for version 3."

    defaultto ""
  end

  newproperty(:snmp_auth_password) do
    desc "SNMP authorization password for version 3."

    defaultto ""
  end

  newproperty(:snmp_auth_protocol) do
    desc "SNMP authorization protocol for version 3."

    newvalues(:md5, :sha, "")

    munge do |value|
      value.to_s.upcase
    end

    defaultto ""
  end

  newproperty(:snmp_priv_password) do
    desc "SNMP privacy password for version 3."

    defaultto ""
  end

  newproperty(:snmp_priv_protocol) do
    desc "SNMP privacy protocol for version 3."

    newvalues(:des, :aes, :'[None]')

    munge do |value|
      # Getting fed up of this symbol/string malarkey
      if [:des, :aes, 'des', 'aes'].include?(value) then
        value.to_s.upcase
      else
        value.to_s
      end
    end

    # This makes me vomit
    defaultto "[None]"
  end

  newproperty(:snmp_context) do
    desc "SNMP context for version 3."

    defaultto ""
  end

  newproperty(:snmp_port) do
    desc "UDP port number to use for SNMP."

    validate do |value|
      unless (1..65535).include?(value.to_i)
        raise ArgumentError, "%s is not a valid port" % value
      end
    end

    munge do |value|
      value.to_i
    end

    defaultto "161"
  end

  newproperty(:snmp_timeout) do
    desc "Maximum number of milliseconds to wait for an SNMP response."

    validate do |value|
      unless value =~ /^\d+$/
        raise ArgumentError, "%s is not a valid timeout" % value
      end
    end

    munge do |value|
      value.to_i
    end

    defaultto "500"
  end

  newproperty(:snmp_max_oids) do
    desc "Maximum number of OID's that can be obtained in a single SNMP GET request."

    validate do |value|
      unless value =~ /^\d+$/
        raise ArgumentError, "%s is not a valid value for maximum OID's" % value
      end
    end

    munge do |value|
      value.to_i
    end

    defaultto "10"
  end

  newproperty(:host_template) do
    desc "Host template to use for this host."

    defaultto ""
  end

  newproperty(:disabled)

  newparam(:enable) do
    desc "Whether a host should be actively monitored or not."

    newvalues(:true, :false)

    munge do |value|
      @resource[:disabled] = case value.to_s
        when "false" then "on"
        else ""
      end
    end

    defaultto :true
  end

  newproperty(:notes) do
    desc "Notes for this host."

    defaultto ""
  end

  # FIXME these are just the values that match what is created by default

  # Hardcoded to SNMP
  newproperty(:availability_method) do
    desc "The method Cacti will use to determine if a host is available for polling."

    newvalue(2)

    munge do |value|
      value.to_i
    end

    defaultto "2"
  end

  # Hardcoded to UDP
  newproperty(:ping_method) do
    desc "The type of ping packet to send."

    newvalue(2)

    munge do |value|
      value.to_i
    end

    defaultto "2"
  end

  # Hardcoded (UDP) port 23
  newproperty(:ping_port) do
    desc "TCP or UDP port to attempt connection."

    newvalue(23)

    munge do |value|
      value.to_i
    end

    defaultto "23"
  end

  # Hardcoded to 400 milliseconds timeout
  newproperty(:ping_timeout) do
    desc "The timeout value to use for host ICMP and UDP ping."

    newvalue(400)

    munge do |value|
      value.to_i
    end

    defaultto "400"
  end

  # Hardcoded to 1 retry attempt
  newproperty(:ping_retries) do
    desc "After an initial failure, the number of ping retries Cacti will attempt."

    newvalue(1)

    munge do |value|
      value.to_i
    end

    defaultto "1"
  end

  # FIXME If I create a cacti_host_template type, enable autorequire magic
  #autorequire(:cacti_host_template) do
  #  @resource[:host_template]
  #end

  validate do
    case self[:snmp_version]
    when 3 then
      self.fail "SNMP username is required" unless self[:snmp_username] != ""
      self.fail "SNMP authorization protocol is required" unless self[:snmp_auth_protocol] != ""
      self.fail "SNMP authorization password is required" unless self[:snmp_auth_password] != ""
      if self[:snmp_priv_protocol] != "[None]" then
        self.fail "SNMP privacy password is required" unless self[:snmp_priv_password] != ""
      end
    when 1, 2 then
      self.fail "SNMP community is required" unless self[:snmp_community] != ""
    end
  end
end
