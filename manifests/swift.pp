# vim: noet

# $hash_path_suffix is a unique string per cluster used to hash partitions
# $cluster_name is a string defining the cluster, eg eqiad-test or pmtpa-prod.
#               It is used to find the ring files in the puppet files
class swift::base($hash_path_suffix, $cluster_name) {

	include webserver::base

	# Recommendations from Swift -- see <http://tinyurl.com/swift-sysctl>.
	sysctl::parameters { 'swift_performance':
		values => {
			'net.ipv4.tcp_syncookies'             => 0,
			'net.ipv4.tcp_tw_recycle'             => 1,  # disable TIME_WAIT
			'net.ipv4.tcp_tw_reuse'               => 1,
			'net.ipv4.netfilter.ip_conntrack_max' => 262144,
		},
	}

	# this is on purpose not a >=. the cloud archive only exists for
	# precise right now, and will perhaps exist for the next LTS, but
	# surely not for the intermediate releases.
	if ($::lsbdistcodename == 'precise') {
		apt::repository { 'ubuntucloud':
			uri        => 'http://ubuntu-cloud.archive.canonical.com/ubuntu',
			dist       => 'precise-updates/folsom',
			components => 'main',
			keyfile    => 'puppet:///files/misc/ubuntu-cloud.key',
			before     => Package['swift'],
		}
	}

	package { [
		'swift',
		'swift-doc',
		'python-swift',
		'python-swiftclient',
		'python-ss-statsd',
		]:
		ensure => present;
	}

	File {
		owner => "swift",
		group => "swift",
		mode => 0440
	}
	file {
		"/etc/swift":
			require => Package[swift],
			ensure => directory,
			recurse => true;
		"/etc/swift/swift.conf":
			require => Package[swift],
			ensure => present,
			content => template("swift/etc.swift.conf.erb");
		"/etc/swift/account.builder":
			ensure => present,
			source => "puppet:///volatile/swift/${cluster_name}/account.builder";
		"/etc/swift/account.ring.gz":
			ensure => present,
			source => "puppet:///volatile/swift/${cluster_name}/account.ring.gz";
		"/etc/swift/container.builder":
			ensure => present,
			source => "puppet:///volatile/swift/${cluster_name}/container.builder";
		"/etc/swift/container.ring.gz":
			ensure => present,
			source => "puppet:///volatile/swift/${cluster_name}/container.ring.gz";
		"/etc/swift/object.builder":
			ensure => present,
			source => "puppet:///volatile/swift/${cluster_name}/object.builder";
		"/etc/swift/object.ring.gz":
			ensure => present,
			source => "puppet:///volatile/swift/${cluster_name}/object.ring.gz";
	}
	include ganglia::logtailer
	file { "/usr/share/ganglia-logtailer/SwiftHTTPLogtailer.py":
		owner => root,
		group => root,
		mode => 0444,
		source => "puppet:///files/swift/SwiftHTTPLogtailer.py",
		require => Package['ganglia-logtailer']
	}
	cron { swift-proxy-ganglia:
		command => "/usr/sbin/ganglia-logtailer --classname SwiftHTTPLogtailer --log_file /var/log/syslog --mode cron > /dev/null 2>&1",
		user => root,
		minute => '*',
		ensure => present
	}
}

class swift::proxy {
	Class[swift::proxy::config] -> Class[swift::proxy]

	system_role { "swift:base": description => "swift frontend proxy" }

	realize File["/etc/swift/proxy-server.conf"]

	package { ['swift-proxy', 'python-swauth']:
		ensure => present;
	}

	# use a generic (parameterized) memcached class
	class { "memcached": memcached_size => '128', memcached_port => '11211' }

	file { "/usr/local/lib/python2.7/dist-packages/wmf/":
		owner => root,
		group => root,
		mode => 0444,
		source => "puppet:///files/swift/SwiftMedia/wmf/",
		recurse => remote;
	}
}

class swift::proxy::monitoring($host) {
	monitor_service { 'swift-http-frontend':
		description   => 'Swift HTTP frontend',
		check_command => "check_http_url!$host!/monitoring/frontend",
	}
	monitor_service { 'swift-http-backend':
		description   => 'Swift HTTP backend',
		check_command => "check_http_url!$host!/monitoring/backend",
	}
}

# TODO: document parameters

# Class: swift::proxy::config
#
# This class configures a Swift Proxy.
#
# Only put virtual resources in this class, as it's included
# on non-proxy swift nodes as well.
#
# Parameters:
class swift::proxy::config(
	$bind_port="8080",
	$proxy_address,
	$memcached_servers,
	$num_workers,
	$auth_backend,
	$super_admin_key,
	$rewrite_account,
	$rewrite_password,
	$rewrite_thumb_server,
	$shard_container_list,
	$backend_url_format ) {

	Class[swift::base] -> Class[swift::proxy::config]

	# Virtual resource
	@file { "/etc/swift/proxy-server.conf":
		owner => swift,
		group => swift,
		mode => 0440,
		content => template("swift/proxy-server.conf.erb")
	}

}

class swift::storage {
	Class[swift::base] -> Class[swift::storage]

	system_role { "swift::storage": description => "swift backend storage brick" }

	class packages {
		package {
			[ "swift-account",
			  "swift-container",
			  "swift-object" ]:
			ensure => present;
		}
	}

	class config {
		require swift::storage::packages

		class {'rsync::server': log_file => '/var/log/rsyncd.log'}
		rsync::server::module {
			'account':
				uid => 'swift',
				gid => 'swift',
				max_connections => '2',
				path        => '/srv/swift-storage/',
				read_only   => 'false',
				lock_file => '/var/lock/account.lock';
			'container':
				uid => 'swift',
				gid => 'swift',
				max_connections => '2',
				path        => '/srv/swift-storage/',
				read_only   => 'false',
				lock_file => '/var/lock/container.lock';
			'object':
				uid => 'swift',
				gid => 'swift',
				max_connections => '3',
				path        => '/srv/swift-storage/',
				read_only   => 'false',
				lock_file => '/var/lock/object.lock';
		}

		# set up swift specific configs
		File { owner => swift, group => swift, mode => 0440 }
		file {
			"/etc/swift/account-server.conf":
				content => template("swift/etc.swift.account-server.conf.erb");
			"/etc/swift/container-server.conf":
				content => template("swift/etc.swift.container-server.conf.erb");
			"/etc/swift/object-server.conf":
				content => template("swift/etc.swift.object-server.conf.erb");
		}

		file { "/srv/swift-storage":
			require => Package[swift],
			owner => swift,
			group => swift,
			mode => 0751, # the 1 is to allow nagios to read the drives for check_disk
			ensure => directory;
		}
	}

	class service {
		require swift::storage::config

		Service { ensure => running }
		service {
			[ swift-account, swift-account-auditor, swift-account-reaper, swift-account-replicator ]:
				subscribe => File["/etc/swift/account-server.conf"];
			[ swift-container, swift-container-auditor, swift-container-replicator, swift-container-updater ]:
				subscribe => File["/etc/swift/container-server.conf"];
			[ swift-object, swift-object-auditor, swift-object-replicator, swift-object-updater ]:
				subscribe => File["/etc/swift/object-server.conf"];
		}
	}

	class monitoring {
		require swift::storage::service
		$nagios_group = "swift"
		monitor_service { "swift-account-auditor": description => "swift-account-auditor", check_command => "nrpe_check_swift_account_auditor" }
		monitor_service { "swift-account-reaper": description => "swift-account-reaper", check_command => "nrpe_check_swift_account_reaper" }
		monitor_service { "swift-account-replicator": description => "swift-account-replicator", check_command => "nrpe_check_swift_account_replicator" }
		monitor_service { "swift-account-server": description => "swift-account-server", check_command => "nrpe_check_swift_account_server" }
		monitor_service { "swift-container-auditor": description => "swift-container-auditor", check_command => "nrpe_check_swift_container_auditor" }
		monitor_service { "swift-container-replicator": description => "swift-container-replicator", check_command => "nrpe_check_swift_container_replicator" }
		monitor_service { "swift-container-server": description => "swift-container-server", check_command => "nrpe_check_swift_container_server" }
		monitor_service { "swift-container-updater": description => "swift-container-updater", check_command => "nrpe_check_swift_container_updater" }
		monitor_service { "swift-object-auditor": description => "swift-object-auditor", check_command => "nrpe_check_swift_object_auditor" }
		monitor_service { "swift-object-replicator": description => "swift-object-replicator", check_command => "nrpe_check_swift_object_replicator" }
		monitor_service { "swift-object-server": description => "swift-object-server", check_command => "nrpe_check_swift_object_server" }
		monitor_service { "swift-object-updater": description => "swift-object-updater", check_command => "nrpe_check_swift_object_updater" }
	}

	# this class installs swift-drive-audit as a cronjob; it checks the disks every 60 minutes
	# and unmounts failed disks. It logs its actions to /var/log/syslog.
	class driveaudit {
		require swift::storage::service
		# this file comes from the python-swift package but there are local improvements
		# that are not yet merged upstream.
		file { "/usr/bin/swift-drive-audit":
			owner => root,
			group => root,
			mode => 755,
			source => "puppet:///files/swift/usr.bin.swift-drive-audit"
		}
		file { "/etc/swift/swift-drive-audit.conf":
			owner => root,
			group => root,
			mode => 0440,
			source => "puppet:///files/swift/etc.swift.swift-drive-audit.conf"
		}
		cron { "swift-drive-audit":
			command => "/usr/bin/swift-drive-audit /etc/swift/swift-drive-audit.conf",
			user => root,
			minute => 1,
			ensure => present
		}
	}

	include packages, config, service, driveaudit
}

# Definition: swift::create_filesystem
#
# Creates a new partition table on a device, and
# creates a partition and file system for Swift
#
# Parameters:
#	- $title:
#		The device to partition
define swift::create_filesystem($partition_nr="1") {
	require base::platform

	if ($title =~ /^\/dev\/([hvs]d[a-z]+|md[0-9]+)$/) {
		$dev = "${title}${partition_nr}"
		$dev_suffix = regsubst($dev, '^\/dev\/(.*)$', '\1')
		exec { "swift partitioning $title":
			path => "/usr/bin:/bin:/usr/sbin:/sbin",
			command => "parted -s -a optimal ${title} mklabel gpt mkpart swift-${dev_suffix} 0% 100% && mkfs -t xfs -i size=512 -L swift-${dev_suffix} ${dev}",
			creates => $dev
		}

		swift::mount_filesystem { "$dev": require => Exec["swift partitioning $title"] }
	}
}



# Definition: swift::mount_filesystem
#
# Mounts a block device ($title) under /srv/swift-storage/$devname
# as XFS with the appropriate file system options, and updates fstab
#
# Parameters:
#	- $title:
#		The device to mount (e.g. /dev/sdc1)
define swift::mount_filesystem() {
	$dev = $title
	$dev_suffix = regsubst($dev, '^\/dev\/(.*)$', '\1')
	$mountpath = "/srv/swift-storage/${dev_suffix}"

	# Make sure the mountpoint exists...
	# This can't be a file resource, as it would become a duplicate.
	exec { "mkdir $mountpath":
		require => File["/srv/swift-storage"],
		path => "/usr/bin:/bin",
		creates => $mountpath
	}

	# ...mount the filesystem by label...
	mount { $mountpath:
		device => "LABEL=swift-${dev_suffix}",
		name => $mountpath,
		ensure => mounted,
		fstype => "xfs",
		options => "noatime,nodiratime,nobarrier,logbufs=8",
		atboot => true,
		remounts => true
	}

	# ...and fix the directory attributes.
	file { "fix attr $mountpath":
		require => Class[swift::base],
		path => $mountpath,
		owner => swift,
		group => swift,
		mode => 0750,
		ensure => directory
	}

	Exec["mkdir $mountpath"] -> Mount[$mountpath] -> File["fix attr $mountpath"]
}


# Definition: swift::label_filesystem
#
# labels an XFS filesystem on a block device ($title) as
# swift-xxxx (example: swift-sdm3), only if the device is
# unmounted, has an xfs filesystem on it, and the filesystem
# does not already have a pre-existing swift label
# (so we don't accidentally relabel devices that show up with
# a changed device id)
#
# this would typically be used for devices partitioned and
# with xfs filesystems created at install time but no labels
#
# Parameters:
#	- $title:
#		The device to label (e.g. /dev/sdc1)
define swift::label_filesystem() {
	$device = $title
	$dev_suffix = regsubst($device, '^\/dev\/(.*)$', '\1')

	$label = "swift-${dev_suffix}"
	exec { "/usr/sbin/xfs_admin -L $label $device":
		onlyif => "/usr/bin/test $(/bin/mount | /bin/grep $device | /usr/bin/wc -l) -eq 0 && /usr/bin/test $(/usr/sbin/grub-probe -t fs -d  $device) = 'xfs' && /usr/bin/test $(/usr/sbin/xfs_admin -l $device | /bin/grep swift | /usr/bin/wc -l) -eq 0"
	}
}
