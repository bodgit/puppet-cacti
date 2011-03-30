# Bunch of facts with the Cacti database details, retrieved from the file
# usually named config.php

require 'yaml'

php = '/usr/bin/php'

cacti = case Facter.value(:operatingsystem)
  when 'CentOS' then '/etc/cacti/db.php' # EPEL package
  else nil
end

if php and File.executable?(php) and cacti and File.readable?(cacti) then

  # Basic PHP code to print all of the database settings as a YAML document
  code = <<-"PHP"
include "#{cacti}";

echo "---\n";
echo "  type: $database_type\n";
echo "  host: $database_hostname\n";
echo "  name: $database_default\n";
echo "  port: $database_port\n";
echo "  user: $database_username\n";
echo "  pass: $database_password\n";
  PHP

  settings = YAML.load(%x{#{php} -r '#{code}'})

  settings.each do |key,value|
    Facter.add("cacti_db_#{key}") do
      setcode do
        value
      end
    end
  end
end
