# == Class etcd::auth:;common
#
# Common base configs for the etcd auth classes
class etcd::auth::common($root_password, $active = true) {
    # Require the global etcd config file
    require ::etcd::client::globalconfig

    file { '/usr/local/bin/etcd-manage':
        ensure => absent,
    }

    if $active {
        # specific configuration for the root user, basically
        # just the credentials.
        etcd::client::config { '/root/.etcdrc':
            settings => {
                username => 'root',
                password => $root_password,
            },
        }
    }
}
