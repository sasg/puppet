# == Class profile::analytics::database::meta::backup_dest
#
# Target host to store the analytics meta database snapshot, taken by
# the role running profile::analytics::database::meta::backup.
#
class profile::analytics::database::meta::backup_dest(
    $hive_metastore_host = hiera('profile::analytics::database::meta::backup_dest::hive::metastore_host'),
    $oozie_host          = hiera('profile::analytics::database::meta::backup_dest::oozie_host'),
) {

    if !defined(File['/srv/backup']) {
        file { '/srv/backup':
            ensure => 'directory',
            owner  => 'root',
            group  => 'analytics-admins',
            mode   => '0755',
        }
    }

    file { [
            '/srv/backup/mysql',
            '/srv/backup/mysql/analytics-meta',
        ]:
        ensure => 'directory',
        owner  => 'root',
        group  => 'analytics-admins',
        mode   => '0750',
    }

    class { '::rsync::server': }

    # These are probably the same host, but in case they
    # aren't, allow either use of this rsync server module.
    $hosts_allow = [$hive_metastore_host, $oozie_host]

    # This will allow $hosts_allow to host public data files
    # generated by the analytics cluster.
    # Note that this requires that cdh::hadoop::mount
    # be present and mounted at /mnt/hdfs
    rsync::server::module { 'backup':
        path        => '/srv/backup',
        read_only   => 'no',
        list        => 'no',
        hosts_allow => $hosts_allow,
    }

    $rsync_clients_ferm = join($hosts_allow, ' ')
    ferm::service { 'analytics_cluster-backup-rsync':
        proto  => 'tcp',
        port   => '873',
        srange => "@resolve((${rsync_clients_ferm}))",
    }

    # Alert if backup gets stale.
    $warning_threshold_hours = 26
    $critical_threshold_hours = 48
    nrpe::monitor_service { 'analytics-database-meta-backup-age':
        description   => 'Age of most recent Analytics meta MySQL database backup files',
        nrpe_command  => "/usr/local/lib/nagios/plugins/check_newest_file_age -C -d /srv/backup/mysql/analytics-meta -w ${$warning_threshold_hours} -c ${critical_threshold_hours}",
        contact_group => 'analytics',
    }
}
