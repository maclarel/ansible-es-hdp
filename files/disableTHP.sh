# Disable THP for new processes as per https://access.redhat.com/solutions/46111
# Note that Ambari may still complain about this until the system is rebooted
# however process it spawns will be unaffected
if [ -a /sys/kernel/mm/redhat_transparent_hugepage/enabled ]
	then
		echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
fi

if [ -a /sys/kernel/mm/redhat_transparent_hugepage/defrag ]
	then
		echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag
fi


cat <<__END__ >> /etc/rc.local

if test -f /sys/kernel/mm/transparent_hugepage/enabled; then echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
__END__