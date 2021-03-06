# = Class: icinga::nsca::daemon
#
# Sets up an NSCA daemon for listening to passive check
# results from hosts
class icinga::nsca::daemon (
    $icinga_user,
    $icinga_group,
){

    package { 'nsca':
        ensure => 'present',
    }

    include ::passwords::icinga
    $nsca_decrypt_password = $::passwords::icinga::nsca_decrypt_password


    if os_version('debian >= stretch') {

        systemd::service { 'nsca':
            ensure  => 'present',
            content => systemd_template('nsca'),
            require => File['/etc/nsca.cfg'],
        }

        $nsca_chroot = '/var/lib/icinga'
        $command_file = '/rw/icinga.cmd'

    # FIXME: remove after we are off jessie
    } else {

        service { 'nsca':
            ensure  => running,
            require => File['/etc/nsca.cfg'],
        }

        $nsca_chroot = '/var/lib/nagios'
        $command_file = '/rw/nagios.cmd'
    }

    file { '/etc/nsca.cfg':
        content => template('icinga/nsca.cfg.erb'),
        owner   => 'root',
        mode    => '0400',
        require => Package['nsca'],
    }
}
