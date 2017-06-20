# miq-RedHat-Satellite6
ManageIQ Automate Domain for integrating with Red Hat Satellite 6 developed by Red Hat Consulting.

# Table of Contents
* [miq-RedHat-Satellite6](#miq-redhat-satellite6)
* [Table of Contents](#table-of-contents)
* [Features](#features)
* [Dependencies](#dependencies)
  * [Other Datastores](#other-datastores)
* [Install](#install)
* [Contributors](#contributors)

# Features
The high level features of this ManageIQ extension.

* Satellite 6 PXE & Kickstart based provisioning Service and VM state machines
* Register VM to Satellite 6
* VM retirment including unregister VM from Satellite 6
* Satellite 6 dynamic dialogs
  * hostgroups
  * lifecycle environments
  * locations
  * organizaitons

# Dependencies
Dependencies of this ManageIQ extensions.

## Other Datastores
These ManageIQ atuomate domains must also be installed for this datastore to function.

* [RedHatConsulting_Utilities](https://github.com/rhtconsulting/miq-Utilities)

# Install
0. Install dependencies
1. Automate -> Import/Export
2. Import Datastore via git
3. Git URL: `https://github.com/rhtconsulting/miq-RedHat-Satellite6.git`
4. Submit
5. Select Branc/Tag to syncronize with
6. Submit
