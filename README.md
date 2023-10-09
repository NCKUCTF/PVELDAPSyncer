# PVELDAPSyncer

## Install
1. Copy shell script to `/usr/local/bin`
```bash
git clone https://github.com/NCKUCTF/PVELDAPSyncer
cp PVELDAPSyncer/syncacl.sh /usr/local/bin/syncacl
chmod 744 /usr/local/bin/syncacl
cp PVELDAPSyncer/syncldappamaccount.sh usr/local/bin/syncldappamaccount
chmod 744 /usr/local/bin/syncldappamaccount
```

2. Write `/etc/crontab`
```
* *     * * *   root    syncldappamaccount && syncacl ldap
```
