require 'beaker'

module Beaker::PuppetInstallHelper
  def run_puppet_install_helper(type_arg=find_install_type,version=ENV["PUPPET_VERSION"])
    run_puppet_install_helper_on(hosts,type_arg,version)
  end

  # Takes a host(s) object, install type string, and install version string.
  # - Type defaults to PE for PE nodes, and foss otherwise.
  # - Version will default to the latest 3x foss/pe package, depending on type
  def run_puppet_install_helper_on(hosts,type_arg=find_install_type,version=ENV["PUPPET_VERSION"])
    # Short circuit based on rspec-system and beaker variables
    return if ENV["RS_PROVISION"] == "no" or ENV["BEAKER_provision"] == "no"

    type = type_arg || find_install_type

    # Example environment variables to be read:
    # PUPPET_VERSION=3.8.1 <-- for foss/pe/gem
    # PUPPET_VERSION=4.1.0 <-- for agent/gem
    # PUPPET_VERSION=1.0.1 <-- for agent
    #
    # PUPPET_INSTALL_TYPE=pe
    # PUPPET_INSTALL_TYPE=foss
    # PUPPET_INSTALL_TYPE=agent

    case type
    when "pe"
      # This will skip hosts that are not supported
      install_pe_on(hosts,{"pe_ver" => version})
      add_pe_defaults_on(hosts)
      add_puppet_paths_on(hosts)
    when "foss"
      opts = {
        :version        => version,
        :default_action => "gem_install",
      }

      install_puppet_on(hosts, opts)
      if opts[:version] and not version_is_less(opts[:version], '4.0.0')
        add_aio_defaults_on(hosts)
      else
        add_foss_defaults_on(hosts)
      end
      add_puppet_paths_on(hosts)
      Array(hosts).each do |host|
        if fact_on(host,"osfamily") != "windows"
          on host, "mkdir -p #{host["distmoduledir"]}"
          on host, "touch #{host["hieraconf"]}"
        end
        if fact_on(host, "operatingsystem") == "Debian"
          on host, "echo 'export PATH=/var/lib/gems/1.8/bin/:${PATH}' >> ~/.bashrc"
        end
        if fact_on(host, "operatingsystem") == "Solaris"
          on host, "echo 'export PATH=/opt/puppet/bin:/var/ruby/1.8/gem_home/bin:${PATH}' >> ~/.bashrc"
        end
      end
    when "agent"
      # This will fail on hosts that are not supported; use foss and specify a 4.x version instead
      install_puppet_agent_on(hosts, {:version => version})
      add_aio_defaults_on(hosts)
      add_puppet_paths_on(hosts)
    else
      raise ArgumentError, "Type must be pe, foss, or agent; got #{type.inspect}"
    end
  end

  def find_install_type
    if type = ENV["PUPPET_INSTALL_TYPE"]
      type
    elsif default.is_pe?
      "pe"
    else
      "foss"
    end
  end
end

include Beaker::PuppetInstallHelper
