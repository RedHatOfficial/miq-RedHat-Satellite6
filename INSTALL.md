# Hybrid Cloud Automated Provisioning Realized with Red Hat CloudForms

## (Outline and Documentation Links)

# Abstract:

If you follow the below steps on greed field, configured, Red Hat CloudForms appliance(s), Hybrid Cloud Provisioning with Infrastructure Providers (RHEV, vCenter), Cloud Providers (AWS), a Configuration Management Provider (Satellite) and an Automation Provider (Ansible Tower) becomes a reality.  Simply follow the steps listed below and "it just works".

# Assumptions:

*   Red Hat CloudForms 4.5/4.6 up and running…
*   Red Hat Satellite 6 configured…
*   (Optional) Ansible Tower setup (for post install configuration)…
*   Cloud/Infra Providers and networking are in place…

# Additional Requirements:

*   Each user, including the admin user, making provisioning requests must have an email address configured.  Provisioning requests will fail if initiated by any user without a configured email address.  The [General Configuration](https://access.redhat.com/documentation/en-us/red_hat_cloudforms/4.5/html/general_configuration/configuration) document explains the process of creating users and editing users.

# Configure Providers:

*   Add Infrastructure, Cloud, Configuration and Automation Providers as prescribed in [Managing Providers](https://access.redhat.com/documentation/en-us/red_hat_cloudforms/4.5/html/managing_providers)

## Connect Infrastructure Providers:

*   Connect VMware vCenter
*   Connect RHEV

## Connect Cloud Providers:

*   Connect AWS Provider

## Add Configuration Management Provider:

*   Add Red Hat Satellite Provider

## Connect Automation Provider (optional):

*   Connect Ansible Tower Provider

# Automate Domains:

## Configuration Domain:
The Configuration domain will be created for you but it is recommended that you read the guide below to gain a better understanding ot the automate model.

*   [Understanding the Automate Model - Creating a Domain](https://access.redhat.com/documentation/en-us/red_hat_cloudforms/4.5/html/scripting_actions_in_cloudforms/understanding-the-automate-model#creating-a-domain) covers the steps required to create a domain within the Automate model.  The recommendation is to create a domain with a name of Configuration but the name of the domain is inconsequential.  The ordering of the domains is important and that will be covered later in this document.

### Network Configuration:

*   You will need the following information from each network defined in Red Hat Satellite for the next steps
    *   Network Name: ovirtmgmt
    *   Network purpose: (can be either [provisioning] or [destination])
    *   Network_address_space: 10.10.10.0/24
    *   Network_gateway: 10.10.10.1
    *   Network_nameservers (comma seperated with no spaces): [10.10.10.2,10.10.10.3]
*   Create /root/networks.txt and fill in the data using the '*' key as a field seperator
    *   [Net Name]\*[purpose]\*[Net Address]\*[

### Email Configuration:

*   In order to modify the from email address, override each of the following and change from_email_address value:
    *   Copy the following instances into your Configuration domain from RedHatConsulting_Utilities/Infrastructure/VM/Provisioning/Email
        *   MiqProvision_Complete
        *   MiqProvision_Update
        *   MiqProvisionRequest_Approved
        *   MiqProvisionRequest_Denied
        *   MiqProvisionRequest_Pending
    *   Copy the following instance into your Configuration domain from RedHatConsulting_Utilities/Infrastructure/VM/Retirement/Email
        *   Vm_retirement_emails
*   In order to stop Reconfigure notifications, override and blank all values in the following Instances
    *   Copy the following into your Configuration domain
        *   ManageIQ/Infrastructure/VM/Reconfigure/Email/VmReconfigureRequestApproved
    *   Copy the following instance into your Configuration domain
        *   ManageIQ/Infrastructure/VM/Reconfigure/Email/VmReconfigureTaskComplete

# Install Methods
There is 2 install methods.  One is scripted the other is manual.

## Scripted install
The following steps will perform an automated install and in later releases will also allow automating updates.

1. download *[this script](https://github.com/RedHatOfficial/miq-RedHat-Satellite6/blob/master/install.sh)* to the CFME appliance and make it executable
2. create and empty file /root/networks.txt and in it put the following data seperated by '*'
    - Network name: ovirtmgmt
    - Network purpose: (can be either [provisioning] or [destination])
    - Network_address_space: 10.10.10.0/24
    - Network_nameservers (comma seperated with no spaces): [10.10.10.2,10.10.10.3]
    - Network_gateway: 10.10.10.1

    This is an example of what the file will look like:
    ```
    AWS0*provision*10.168.0.0/24*192.168.0.6*10.168.0.1
    lab-50*destination*192.168.50.0/24*192.168.0.6*192.168.50.254
    .
    .
    .
    lab-51*destination*192.168.51.0/24*192.168.0.6*192.168.51.254
    ```

    The file should contain all the networks that is in the Satellite server.  Later versions of the script will be able to pull this directly using hammer.
3. create /root/admin-email.txt and put in it the default administrator email
    ```
    admin@example.org
    ```
4. run the setup.sh script which will pull needed repos from github, set up 3 new doamins, and add the networks and admin email to the configuration domain
5. go into the CloudForms UI/Automation/Automate/Explorer and verify that there are 3 new domains in the order listed below and change them if they are not to match the below ordering
    - Configuration
    - Red Hat Satellite 6 (RedHatConsulting_Satellite6)
    - Utilities (RedHatConsulting_Utilities)

    The Order is important as the code will go in the 2 RedHatConsulting domains and be overwritten as updates come out.  The configuration domain is where custom items like networks and email address will stay as this domain will be added to but never overwritten.
6. Click on each of the Red Hat domains then click in the Configuration button and select "Lock this domain".  This will prevent accidental changes that should be in the Configuration domain so they are not overwritten on further code updates.
7. Verify that there is now new catalog and service dialog items
8. Proceed on to [TAGGING:](#Tagging) below to perform the remainder of configuration

## Manual install

### Import Upstream Domains:

*   [Understanding the Automate Model - Importing a Domain](https://access.redhat.com/documentation/en-us/red_hat_cloudforms/4.5/html/scripting_actions_in_cloudforms/understanding-the-automate-model#importing-a-domain) explains how to import the required Automate domains.  The relevant repositories with links are included below.  In order to control release, you may want to choose a specific branch or tag.

### Import Automate Domains from RedHatOfficial Github:

*   Import miq-RedHat-Satellite6
    *   [https://github.com/RedHatOfficial/miq-RedHat-Satellite6.git](https://github.com/RedHatOfficial/miq-RedHat-Satellite6.git)
*   Import miq-Utilities
    *   [https://github.com/RedHatOfficial/miq-Utilities.git](https://github.com/RedHatOfficial/miq-Utilities.git)

### Automate Domain Priority:

*   [Understanding the Automate Model - Changing Priority Order of Domains](https://access.redhat.com/documentation/en-us/red_hat_cloudforms/4.5/html/scripting_actions_in_cloudforms/understanding-the-automate-model#changing-priority-order-of-domains) explains the process required in order to properly configure the priority of Automate Domains.  The following is the necessary priority required for this configuration.

### Configure Automate Domain Priority:

*   Configuration
*   RedHatConsulting_Satellite6
*   RedHatConsulting_Utilities

### Service Dialogs and Catalogs:

*   A pre-configured catalog and associated service dialog are provided as part of the miq-RedHat-Satellite6 project on Github.  Complete the following steps to import these items.

### Install cfme-rhconsulting-scripts per instructions on CFME appliance (this provides needed importing and exporting tools):

*   [https://github.com/rhtconsulting/cfme-rhconsulting-scripts#install](https://github.com/rhtconsulting/cfme-rhconsulting-scripts#install)

### Import Service Dialog and Catalog Items (these steps get done also on CFME appliance):

*   change to then git clone miq-RedHat-Satellite6 repository to a working directory
    *   git clone https://github.com/RedHatOfficial/miq-RedHat-Satellite6.git
*   Run the miqimport tool to import the provided Service Dialog(s) changing <VER> with v5.8 (CF 4.5) or v5.9 (CF 4.6)
    *   miqimport service_dialogs miq-RedHat-Satellite6/Dialogs/<VER>
*   Run the miqimport tool to import the provided Catalog item(s) changing <VER> with v5.8 (CF 4.5) or v5.9 (CF 4.6)
    *   miqimport service_catalogs miq-RedHat-Satellite6/Catalogs/<VER>

# Tagging:
This can not be automated as it requires knowledge of your environment.

## Tag Categories:

### Environment Tag Category
The default environment tag category that ships with CFME does not allow multiple values so we need to delete and recreate it.  This is don in the Region configuration area of CFME.
This tag will be populated with all the lifecycle environments from Satellite and used to tag what lifecycle environents can dbe used with each provider
*   Delete environment Tag Category
*   Recreate environment Tag Category
    *   Name: environment
    *   Description: Environment
    *   Long Description: Environment
    *   Show in Console: Yes
    *   Single Value: No
    *   Capture C & U Data by Tag: No

### Location Tag Category
The default location tag category that ships with CFME does not allow multiple values so we need to delete and recreate it.  This is don in the Region configuration area of CFME.
This tag will be populated with all the locations from Satellite and used to tag what locations can dbe used with each provider
*   Delete location Tag Category
*   Recreate location Tag Category
    *   Name: location
    *   Description: Location
    *   Long Description: Location
    *   Show in Console: Yes
    *   Single Value: No
    *   Capture C & U Data by Tag: No

### Operating System Tag Category
This is a new tag that will need to be created and ipopulated with what operating systems are supported from within CFME
This tag will be used to tag provider images with the operating system that the image is configured to deploy
*   Create os Tag Category
    *   Name: os
    *   Description: Operating System
    *   Long Description: Operating System
    *   Show in Console: Yes
    *   Single Value: Yes

## Tags:

*   In order to auto-populate some of the tags, you can simply open the service dialog at this point.  Once the dialog has opened, simply close the dialog and continue with tagging.  This will create the appropriate environment and location tags based on your Satellite configuration.

### Operating System Tags:

*   Create Tag for each Operating System Supported
    *   i.e. name: rhel6, description: RHEL 6
    *   i.e. name: rhel7, description: RHEL 7

### Infrastructure Provider Tags:

*   Infrastructure Providers require a multitude of tags based on your organization's configuraion and design.  The providers being used for automated provisioning need the following tags applied appropriate to your organization's goals.
*   Location and environment Tags
    *   Go into Compute / Infrastructure / Providers
    *   For each provider Select Policy / Edit Tags
    *   Tag that provider with all the environments and locations that provider supports or is used with
    *   Do this for all infrastucture providers defined in CFME as well
    *   Save

*   Provisioning Scope: All
    *   Go into Compute / Infrastructure / Hosts
    *   For each host Select Policy / Edit Tags
    *   Tag each host with the correct Provisioning Scope tag
    *   Pertform the same for each datastore in ompute / Infrastructure / Datastores
    *   Save

*   Tag Templates
    *   Navigate to Compute / Infrastructure / Virtual Machines
    *   Select Templates
    *   Select the template(s) to be tagged
    *   Select Policy / Edit Tags
    *   Apply appropriate Operating System Tag
    *   Save

### Cloud Provider Tags:

*   The following example lists the steps necessary to tag and utilize a public image.
*   Tagging of AWS Images
    *   Public_images_filters (Advanced Settings)
        *   If you wanted to download public images and filter the images downloaded, you could make the following modifications to your Advanced Settings of your appliance(s).  This example limits public images to the current RHEL 7 image.
            *   Change

                        :ec2:
                          :get_public_images: false
                          :public_images_filters:
                          - :name: image-type
                            :values:
                            - machine

            *   To

                        :ec2:
                          :get_public_images: true
                          :public_images_filters:
                          - :name: image-id
                            :values:
                            - ami-6871a115

*   Location and environment Tags
    *   Go into Compute / Cloud / Providers
    *   For each provider Select Policy / Edit Tags
    *   Tag that provider with all the environments and locations that provider supports or is used with
    *   Do this for all Cloud providers defined in CFME as well
    *   Save

*   Tag the Images with OS tags
    *   Navigate to Compute / Clouds / Instances / Images by Provider
    *   Select the image(s) to be tagged
    *   Select Policy / Edit Tags
    *   Apply appropriate Operating System Tag
    *   Save

# The Proof is in the Pudding…

*   Now is the time to test your configuration.  Ensure you have your logs open in case of configuration errors.
*   Open the Service Dialog
    *   If any script errors exist, refer to logs to determine the issue
*   Populate the Dialog
    *   The lower portion of the form will change as entries are populated.  Use this box to verify your selections.
*   Submit the Order
*   Watch the Requests and the Logs
*   Rejoice as you see your Hybrid Cloud Automated Provisioning Realized
    *   Do a little dance
    *   Tell all of your friends
*   Get involved!
    *   Submit issues against the upstream projects
    *   Pull Requests
