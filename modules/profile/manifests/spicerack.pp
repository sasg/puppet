# == Class profile::spicerack
#
# Installs the spicerack library and cookbook entry point and their configuration.
#
# === Parameters
#
# [*tcpircbot_host*]
#   Hostname for the IRC bot.
#
# [*tcpircbot_port*]
#   Port to use with the IRC bot.
#
class profile::spicerack(
    String $tcpircbot_host = hiera('tcpircbot_host'),
    Wmflib::IpPort $tcpircbot_port = hiera('tcpircbot_port'),
    Hash $redis_shards = hiera('redis::shards'),
) {
    # Ensure pre-requisite profiles are included
    require ::profile::conftool::client
    require ::profile::cumin::master
    require ::profile::ipmi::mgmt
    require ::profile::access_new_install
    require ::profile::conftool::client

    include ::service::deploy::common
    include ::passwords::redis

    # Install the software
    require_package('spicerack')

    $cookbooks_dir = '/srv/deployment/spicerack'

    # Install the cookbooks
    git::clone { 'operations/cookbooks':
        ensure    => 'latest',
        directory => $cookbooks_dir,
    }

    # Install the global configuration, the directory is already created by the Debian package
    file { '/etc/spicerack/config.yaml':
        ensure  => present,
        owner   => 'root',
        group   => 'ops',
        mode    => '0440',
        content => template('profile/spicerack/config.yaml.erb'),
    }

    # Install the Redis-specific configuration
    file { '/etc/spicerack/redis_cluster':
        ensure => directory,
        owner  => 'root',
        group  => 'ops',
        mode   => '0550',
    }

    $redis_sessions_data = {
        'password' => $passwords::redis::main_password,
        'shards' => $redis_shards['sessions'],
    }
    file { '/etc/spicerack/redis_cluster/sessions.yaml':
        ensure  => present,
        owner   => 'root',
        group   => 'ops',
        mode    => '0440',
        content => ordered_yaml($redis_sessions_data),
    }
}
