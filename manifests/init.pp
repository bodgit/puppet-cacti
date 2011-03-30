class cacti {
    # FIXME This is nowhere near enough to get Cacti installed and working
    package { "cacti":
        ensure => present,
    }

    # Needed for the provider to work, database type provided by custom fact
    case $cacti_db_type {
        "mysql": {
            package { "ruby-mysql":
                ensure => present,
            }
        }
    }

    # Make sure the basic localhost default host is removed
    cacti_host { "Localhost":
        ensure => absent,
    }

    # Add some network devices that are not capable of running Puppet

    # Add a router device. Because it has crypto gubbins the SNMPv3 agent
    # supports the privacy password, although only DES works with Cacti
    cacti_host { "ADSL Router":
        ensure             => present,
        hostname           => "192.0.2.254",
        snmp_version       => 3,
        snmp_username      => "cacti",
        snmp_auth_protocol => "sha",
        snmp_auth_password => "password",
        snmp_priv_protocol => "des",
        snmp_priv_password => "password",
        notes              => "Some notes about this host",
        host_template      => "Cisco Router",
    }

    # Add a switch device. This lack the crypto bits so the SNMPv3 agent
    # only supports the authorization hash
    cacti_host { "Switch":
        ensure             => present,
        hostname           => "192.0.2.253",
        snmp_version       => 3,
        snmp_username      => "cacti",
        snmp_auth_protocol => "md5",
        snmp_auth_password => "password",
    }

    # Add an airport device. This only supports SNMPv2 so configure accordingly
    cacti_host { "Time Capsule":
        ensure         => present,
        hostname       => "192.0.2.252",
        snmp_version   => 2,
        snmp_community => "public",
    }

    # Scoop up any exported resources from other Puppet nodes
    Cacti_host <<| |>>
}
