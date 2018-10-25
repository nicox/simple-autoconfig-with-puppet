include stdlib

$ip_address = ""     ## IP of this host
$mailrelay = "" 
$mailsender = ""   
$systems = ['f5', 'chkp', 'cisco', 'ironport' ]
$hosts = { 'f5' => 'netmask(1.2.3.4/32) or netmask(2.3.4.5/32)',
           'chkp' => 'netmask(3.4.5.6/32) ',
	   'cisco' => 'netmask(4.5.6.0/24) ',
	   'ironport' => 'netmask(5.6.7.8/32) '}
### where to send the mails
	   $mails = { 'f5' => '',
           'chkp' => '',
	   'cisco' => '',
	   'ironport' => ''}
#########################################################################################################
#########################################################################################################
##### end configuration ####
#########################################################################################################
#########################################################################################################

###### install needed packages #######
package { 'git' : ensure => present, }
package { 'syslog-ng' : ensure => present, }
package { 'logrotate' : ensure => present, }
package { 'logcheck' : ensure => present, }
package { 'cron-apt' : ensure => present, }
package { 'vim' : ensure => present,}

###### end install needed packages #######

###### service definition to restart services when needed ######
service { syslog-ng:
    ensure => running
}  
service { exim4:
    ensure => running
}

###### end service definition to restart services when needed ######

##### cronapt config ###
file_line { 'autoupdate':
  path  => '/etc/cron-apt/action.d/3-download',
  line  => 'dist-upgrade -y -o APT::Get::Show-Upgraded=true',
  match => '^dist-upgrade -d -y -o APT::Get::Show-Upgraded=true',
}
### end cronapt config ###

### exim-mailrelay config ###

file_line { "exim-config-1":
  path => "/etc/exim4/update-exim4.conf.conf",
  line => "dc_smarthost='$mailrelay'",
  match => 'dc_smarthost=',
}

file_line { "exim-config-2":
  path => "/etc/exim4/update-exim4.conf.conf",
  line => "dc_eximconfig_configtype='satellite'",
  match => 'dc_eximconfig_configtype=',
}

file_line { "exim-config-3":
  path => "/etc/exim4/update-exim4.conf.conf",
  line => "dc_hide_mailname='true'",
  match => 'dc_hide_mailname=',
}

file_line { "exim-config-4":
  path => "/etc/email-addresses",
  line => "logcheck: $mailsender",
}
exec {"Comment to your resource":
  command => '/usr/sbin/update-exim4.conf',
  provider => shell,
  notify => Service[exim4]
}

### end exim-mailrelay config ###

### vim config ###

$vimrc_str = "set mouse-=a"
file { '/root/.vimrc': content => $vimrc_str, }

### end vim config ###

### syslog source config ###
$syslog_ng_config_full = "
source s_net { tcp(ip($ip_address) port(514));
               udp(ip($ip_address) port(514));
 };
"
file { '/etc/syslog-ng/conf.d/logcheck.conf': content => $syslog_ng_config_full, }

### end sysllog source config ###

### comment default-logcheck in crond config ###
file_line { "add-crond-logcheck":
    ensure            => present,
    after             => 'MAILTO=root',
    path              => '/etc/cron.d/logcheck',
    line              => "#@reboot         logcheck    if [ -x /usr/sbin/logcheck ]; then nice -n10 /usr/sbin/logcheck -R; fi",
    match             => '@reboot [ ]+logcheck    if \[ -x /usr/sbin/logcheck \]; then nice -n10 /usr/sbin/logcheck -R; fi',
  }
file_line { "add-crond-logcheck-2":
    ensure            => present,
    after             => 'MAILTO=root',
    path              => '/etc/cron.d/logcheck',
    line              => "#2 * * * *       logcheck    if [ -x /usr/sbin/logcheck ]; then nice -n10 /usr/sbin/logcheck -R; fi",
    match             => '2 [ *]+logcheck    if \[ -x /usr/sbin/logcheck \]; then nice -n10 /usr/sbin/logcheck; fi',
  }

### end comment default-logcheck in crond config ###

$systems.each |String $system| {

### logcheck-configuration ###
  file { "/usr/sbin/logcheck-${system}": ensure => present, source => '/usr/sbin/logcheck', source_permissions => use}
  file { "/etc/logcheck-${system}": ensure => directory, recurse => true, source => '/etc/logcheck', source_permissions => use }
  file { "/var/lib/logcheck-${system}": ensure => directory, recurse => true, source => '/var/lib/logcheck', source_permissions => use }
  file { "/etc/logcheck-${system}/ignore.d.server/${system}": ensure => present, source => "/root/${system}.regex", owner => root, group => logcheck, mode => "644", }

  file_line { "logcheck-${system}-configdir":
    path => "/usr/sbin/logcheck-${system}",
    line => "RULEDIR=\"/etc/logcheck-${system}\"",
    match => 'RULEDIR=\"\/etc\/logcheck\"',
  }
  file_line { "logcheck-${system}-conffile":
    path => "/usr/sbin/logcheck-${system}",
    line => "CONFFILE=\"/etc/logcheck-${system}/logcheck.conf\"",
    match => 'CONFFILE=\"\/etc\/logcheck\/logcheck.conf\"',
  }
  file_line { "logcheck-${system}-logfiles":
    path => "/usr/sbin/logcheck-${system}",
    line => "LOGFILES_LIST=\"/etc/logcheck-${system}/logcheck.logfiles\"",
    match => 'LOGFILES_LIST=\"\/etc\/logcheck\/logcheck.logfiles\"',
  }
  file_line { "logcheck-${system}-logfiles_list":
    path => "/usr/sbin/logcheck-${system}",
    line => "LOGFILES_LIST_D=\"/etc/logcheck-${system}/logcheck.logfiles.d\"",
    match => 'LOGFILES_LIST_D=\"\/etc\/logcheck\/logcheck.logfiles.d\"',
  }
  file_line { "logcheck-${system}-permissioncheck":
    path => "/usr/sbin/logcheck-${system}",
    line => '/etc/logcheck/logcheck.logfiles!',
    match => '\/etc\/logcheck\/logcheck.logfiles\!',
  }
  file_line { "logcheck-${system}-statedir":
    path => "/usr/sbin/logcheck-${system}",
    line => "STATEDIR=\"/var/lib/logcheck-${system}\"",
    match => 'STATEDIR=\"\/var\/lib\/logcheck\"',
  }
  file_line { "logcheck-${system}-lockdir":
    path => "/usr/sbin/logcheck-${system}",
    line => "LOCKDIR=/run/lock/logcheck-${system}",
    match => 'LOCKDIR=\/run\/lock\/logcheck',
  }

  $logcheck_logfiles = {$system => "/var/log/${system}.log"}
  file { "/etc/logcheck-${system}/logcheck.logfiles": content => $logcheck_logfiles[$system], }

### end logcheck-configuration ###

### add crond-entries for logcheck ###
  file_line { "add-crond-logcheck-${system}":
    ensure            => present,
    after             => 'MAILTO=root',
    path              => '/etc/cron.d/logcheck',
    line              => "@reboot         logcheck    if [ -x /usr/sbin/logcheck-${system} ]; then nice -n10 /usr/sbin/logcheck-${system} -R; fi",
    #match             => "@reboot         logcheck    if [ -x /usr/sbin/logcheck-${system} ]; then nice -n10 /usr/sbin/logcheck-${system} -R; fi",
  }
  file_line { "add-crond-logcheck-${system}-2":
    ensure            => present,
    after             => 'MAILTO=root',
    path              => '/etc/cron.d/logcheck',
    line              => "2 * * * *       logcheck    if [ -x /usr/sbin/logcheck-${system} ]; then nice -n10 /usr/sbin/logcheck-${system} ; fi",
    #match             => '2 * * * *       logcheck    if [ -x /usr/sbin/logcheck-${system} ]; then nice -n10 /usr/sbin/logcheck-${system} ; fi',
  }

### end add crond-entries for logcheck ###

### logrotate config ###
  $logrotate = { $system => "/var/log/${system}.log {
    rotate 50
    daily
    delaycompress
    compress
    missingok
    notifempty
    postrotate
      invoke-rc.d syslog-ng reload > /dev/null
    endscript
  }"}

  file { "/etc/logrotate.d/${system}": content => $logrotate[$system], }
### end logrotate config ###
}
#### syslog-ng ###
$hosts.each |$system, $host| {
$syslog_logcheck = "destination d_${system} { file(\"/var/log/${system}.log\"); };
                  filter f_${system}_hosts {  ${host}  };
                  log { source(s_net); filter(f_${system}_hosts); destination(d_${system});};
"

#notice('getvar("$syslog_logcheck[$system]")')


file_line { "/etc/syslog-ng/conf.d/logcheck.conf${system}":
    ensure => present,
    path   => '/etc/syslog-ng/conf.d/logcheck.conf',
    line   => "$syslog_logcheck",
        }
#$filterhost = 
}

$excludehosts = $hosts.reduce(  ) |$memo, $value| {
  $string = "${memo[1]} or ${value[1]}"
  [0,$string]
}

file_line { "/etc/syslog-ng/conf.d/logcheck.conf-fallback":
    ensure => present,
    path   => '/etc/syslog-ng/conf.d/logcheck.conf',
    line   => "destination d_fallback { file(\"/var/log/fallback.log\"); };
               filter f_fallback_hosts { not ( ${excludehosts[1]} ) };
               log { source(s_net); filter(f_fallback_hosts); destination(d_fallback);};
		",
        }

#### end syslog-ng ###

#### special-loop for logcheck ###
$mails.each |$system, $mail| {
file_line { "logcheck-${system}-sendmailto":
  path => "/etc/logcheck-${system}/logcheck.conf",
  line => "SENDMAILTO=\"${mail}\"",
  match => '^SENDMAILTO=\"logcheck\"',
  notify => Service[syslog-ng]
}
}
#### end special-loop for logcheck ###


