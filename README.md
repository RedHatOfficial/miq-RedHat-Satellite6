# miq-RedHat-Satellite6

## General Information

| Name      | miq-RedHat-Satellite6 |
| --- | --- | --- |
| License   | GPL v2 (see LICENSE file) |
| Version   | 1.0 |

## Author
| Name      | E-mail |
| --- | --- |
| Kevin Morey | kmorey@redhat.com |
| Laurent Domb | ldomb@redhat.com |

## Packager
| Name              | E-mail |
| --- | --- |
| Jose Simonelli    | jose@redhat.com |


## Install
1) Download import/export rake scripts
```
cd /tmp

if [ -d cfme-rhconsulting-scripts-master ] ; then
    rm -fR /tmp/cfme-rhconsulting-scripts-master
fi

wget -O cfme-rhconsulting-scripts.zip https://github.com/rhtconsulting/cfme-rhconsulting-scripts/archive/master.zip
unzip cfme-rhconsulting-scripts.zip
cd cfme-rhconsulting-scripts-master
make install
```

2) Install {project-name} on appliance
```
PROJECT_NAME="miq-RedHat-Satellite6"
PROJECT_ZIP="https://github.com/rhtconsulting/miq-RedHat-Satellite6/archive/master.zip"
cd /tmp
wget -O ${PROJECT_NAME}.zip ${PROJECT_ZIP}
unzip ${PROJECT_NAME}.zip
cd ${PROJECT_NAME}-master
sh install.sh
```
