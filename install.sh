#!/bin/sh
TOPDIR=`pwd`
DOMAIN=miq-Marketplace

install_cmd() {
    echo "Importing ${DOMAIN} from ${TOPDIR}/Automate/${DOMAIN}"
    cd /var/www/miq/vmdb
    bin/rake "rhconsulting:miq_ae_datastore:import[${DOMAIN}, ${TOPDIR}/Automate]"

#    echo "Importing Service Dialogs"
#    bin/rake rhconsulting:dialogs:import[${TOPDIR}/ServiceDialogs]

#    echo "Importing Buttons"
#    bin/rake rhconsulting:buttons:import[${TOPDIR}/Buttons/buttons.yml]
}

if [ -d ${TOPDIR}/Automate/${DOMAIN} ] ; then
    install_cmd
else
    echo "Error, ${TOPDIR}/Automate/${DOMAIN} does NOT exist"
    exit 1
fi
