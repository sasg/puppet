# == Class geoip::data::archive
#
#
# Sets up a cron job that grabs the latest version of the MaxMind database, puts it
# in a timestamped directory in /srv/geoip/archive, and pushes its contents to hdfs.
#
class geoip::data::archive(
    $maxmind_db_source_dir = '/usr/share/GeoIP',
    $hdfs_archive_dir = '/wmf/data/archive/geoip',
    $archive_dir = "${maxmind_db_source_dir}/archive",
) {
    # Puppet assigns 755 permissions to files and dirs, so the script can be ran
    # manually without sudo.
    file { $archive_dir:
        ensure => directory,
        owner  => 'root',
        group  => 'wikidev',
    }

    $archive_script = '/usr/local/bin/geoip_archive.sh'

    file { $archive_script:
        ensure  => file,
        owner   => 'root',
        group   => 'wikidev',
        mode    => '0555',
        content => file('geoip/archive.sh')
    }

    $archive_command = "${archive_script} ${maxmind_db_source_dir} ${archive_dir} ${hdfs_archive_dir} > /dev/null"

    cron { 'archive-maxmind-geoip-database':
        ensure      => present,
        command     => $archive_command,
        environment => 'MAILTO=analytics-alerts@wikimedia.org',
        user        => root,
        weekday     => 3,
        hour        => 5,
        minute      => 30
    }
}