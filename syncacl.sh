#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Usage: $0 <sync realm>" 1>&2
    exit 1
fi

realm=$1
on=false
realmdata=""


while IFS='' read line
do
    if ! $on && [ "$(echo "$line" | awk '{print $2}')" == "$realm" ]
    then
        on=true
        realmdata='{'
    elif $on && echo "$line" | grep -v '^\s\+' > /dev/null
    then
        on=false
        realmdata="$realmdata
"'"": ""'
        realmdata="$realmdata
"'}'
    fi
    if $on && echo "$line" | grep '^\s\+' > /dev/null
    then
        realmdata="$realmdata
$(echo "$line" | sed 's/^\s\+\(\S\+\)\s\+\(.\+\)$/"\1": "\2",/g')"
    fi
done < /etc/pve/domains.cfg

orguserdata="$(grep -v "^acl*" /etc/pve/user.cfg)"
acldata="$(grep "^acl*" /etc/pve/user.cfg)"

newacldata=""

while read line
do
    if echo "$line" | awk -F: '{print $4}' | grep '!' > /dev/null || ( echo "$line" | awk -F: '{print $4}' | grep -v "^.\+@$realm$" > /dev/null && echo "$line" | awk -F: '{print $4}' | grep -v "^@.\+-$realm$" > /dev/null )
    then
        newacldata="$newacldata
$line"
    fi
done < <(echo "$acldata")

proto="ldap"
if [ "$(echo "$realmdata" | jq -r '.secure')" == "1" ]
then
    proto="ldaps"
fi

acldata="$(ldapsearch -x -H "$proto://$(echo "$realmdata" | jq -r '.server1')" -D "$(echo "$realmdata" | jq -r '.bind_dn')" -b "$(echo "$realmdata" | jq -r '.base_dn')" -w $(cat /etc/pve/priv/realm/$realm.pw) -LLL '(objectClass=pveobject)' pveacl)"

while read line
do
    if echo "$line" | grep '^dn:.*' > /dev/null
    then
        name="$(echo "$line" | sed 's/^dn:\s\+//g' | tr ',' '\n' | grep -i '^cn=' | awk -F= '{print $2}')"
        datatype="$(echo "$line" | sed 's/^dn:\s\+//g' | tr ',' '\n' | grep -i '^ou=' | awk -F= '{print $2}')"
        if [ "$datatype" == "people" ]
        then
            name="$name@$realm"
        elif [ "$datatype" == "groups" ]
        then
            name="@$name-$realm"
        fi
    elif echo "$line" | grep '^pveacl:.*' > /dev/null
    then
        newacldata="$newacldata
acl:1:$(echo "$line" | sed 's/^pveacl:\s\+//g' | jq -r '.path'):$name:$(echo "$line" | sed 's/^pveacl:\s\+//g' | jq -r '.rule'):"
    fi
done < <(echo "$acldata")

echo "$orguserdata


$(echo "$newacldata" | grep "^acl*")" > /etc/pve/user.cfg
