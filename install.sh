#!/usr/bin/bash
VER=$(rpm -qa | grep cfme-5 | awk -F '-' '{print $2}' | awk -F '.' '{print "v"$1"."$2}')
cd /root
git clone https://github.com/rhtconsulting/cfme-rhconsulting-scripts.git
git clone https://github.com/RedHatOfficial/miq-Utilities.git
git clone https://github.com/RedHatOfficial/miq-RedHat-Satellite6.git
cd /root/cfme-rhconsulting-scripts/
make install
make clean-install
cd /root/miq-RedHat-Satellite6/Automate/Configuration/Infrastructure/Network/Configuration.class
for i in $(cat /root/networks.txt)
  do
    name="$(echo $i | awk -F'*' '{print $1}')"
    purp="$(echo $i | awk -F'*' '{print $2}')"
    netw="$(echo $i | awk -F'*' '{print $3}')"
    dnss="$(echo $i | awk -F'*' '{print $4}')"
    gate="$(echo $i | awk -F'*' '{print $5}')"
    cp -f _missing.yaml "$name".yaml
    sed -i "s/netname/$name/" "$name".yaml
    sed -i "s/purpose/$purp/" "$name".yaml
    sed -i "s@1.2.3.0/24@$netw@" "$name".yaml
    sed -i "s/9.10.11.12/$dnss/" "$name".yaml
    sed -i "s/5.6.7.8/$gate/" "$name".yaml
  done
cd /root
sed -i "s/cfme@example.com/$(cat /root/admin-email.txt)/" /root/miq-RedHat-Satellite6/Automate/Configuration/Infrastructure/VM/Provisioning/Email.class/__class__.yaml
sed -i "s/cfme@example.com/$(cat /root/admin-email.txt)/" /root/miq-RedHat-Satellite6/Automate/Configuration/Infrastructure/VM/Retirement/Email.class/__class__.yaml
miqimport --enabled --overwrite domain RedHatConsulting_Utilities /root/miq-Utilities/Automate
miqimport --enabled --overwrite domain RedHatConsulting_Satellite6 /root/miq-RedHat-Satellite6/Automate
miqimport --enabled --no-overwrite domain Configuration /root/miq-RedHat-Satellite6/Automate
miqimport service_dialogs miq-RedHat-Satellite6/Dialogs/$VER
miqimport service_catalogs miq-RedHat-Satellite6/Catalogs/$VER
