class profile::openstack::main::horizon::dashboard_source_deploy(
    $version = hiera('profile::openstack::main::version'),
    $keystone_host = hiera('profile::openstack::main::keystone_host'),
    $wmflabsdotorg_admin = hiera('profile::openstack::main::designate::wmflabsdotorg_admin'),
    $wmflabsdotorg_pass = hiera('profile::openstack::main::designate::wmflabsdotorg_pass'),
    $dhcp_domain = hiera('profile::openstack::main::nova::dhcp_domain'),
    $instance_network_id = hiera('profile::openstack::main::horizon::instance_network_id'),
    $ldap_user_pass = hiera('profile::openstack::main::ldap_user_pass'),
    $webserver_hostname = hiera('profile::openstack::main::horizon::webserver_hostname'),
    $all_regions = hiera('profile::openstack::main::all_regions'),
    $maintenance_mode = hiera('profile::openstack::main::horizon::maintenance_mode'),
    ) {

    require ::profile::openstack::main::clientlib
    class {'::profile::openstack::base::horizon::dashboard_source_deploy':
        version             => $version,
        keystone_host       => $keystone_host,
        wmflabsdotorg_admin => $wmflabsdotorg_admin,
        wmflabsdotorg_pass  => $wmflabsdotorg_pass,
        dhcp_domain         => $dhcp_domain,
        instance_network_id => $instance_network_id,
        ldap_user_pass      => $ldap_user_pass,
        webserver_hostname  => $webserver_hostname,
        all_regions         => $all_regions,
        maintenance_mode    => $maintenance_mode,
    }
}
