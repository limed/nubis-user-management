
file { '/etc/confd/conf.d/nubis-users.toml':
    ensure => file,
    owner  => root,
    group  => root,
    mode   => '0644',
    source => 'puppet:///nubis/files/nubis-users.toml',
}
