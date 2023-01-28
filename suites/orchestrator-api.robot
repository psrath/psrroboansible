*** Settings ***
Resource        ../variables/globals.robot
Suite Setup       Run Setup Only Once   Environmnet Setup   ${${APP_OS}}   ${${PROXMOX}}
Suite Teardown    Release Locks
Metadata      Plugin OS   ${APP_OS}
Metadata      PROXMOX     ${PROXMOX}
Metadata      SuiteName   ASP Sanity Test Suite 

*** Test Cases ***
# Deploy containers on docker
#   Deploy containers on docker host  ${dockerhost}

Deploy VM on Proxmox on ${${PROXMOX}.pve_node}
  [Tags]    orchestrator  platformAll
  Log     ${APP_OS}
  Set Suite Variable  ${APP_OS_NAME}    ${APP_OS}
  Log     ${PROXMOX}
  Log     ${PREFIX}
  Set Proxmox Ip List     ${${PROXMOX}}   ${testenv.${PREFIX}.vm_ips}
  Log   ${${proxmox}.vm_ips}
  ${plugin}=  Deploy VM on proxmox  ${${APP_OS}}  ${${PROXMOX}}
  Set Suite Variable  &{plugin}   &{plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Suite Variable  &{pos}   &{plugin}[${ip}][app_os]
  Set Suite Variable  ${ip}    ${ip}
  ${dash_ip}=   Get Dash Ip   ${ip}
  Set Suite Variable  ${dash_ip}    ${dash_ip}
  Set Suite Variable    ${plugin_domain}        ${pos.av_domain}_${dash_ip}
  Set Suite Variable    ${plugin_subdom}        ${pos.av_subdom}_${dash_ip}
  Log Dictionary  ${pos}  level=INFO

##################################################################
###    Linux Sanity Suite Test Cases    ###
##################################################################

Login to Orchestrator Via Api
  [Tags]    orchestrator  platformLinux
  Login Into Orchestrator using API

Create And Verify Multiple Domains
  [Tags]    orchestrator  platformLinux
  Add Domain  D1_${ip}
  Verify Presence Of Domain   D1_${ip} 
  Add Domain  D2_${ip}
  Verify Presence Of Domain   D2_${ip}
  Add Domain  D3_${ip}
  Verify Presence Of Domain   D3_${ip}
  Add Domain  ${plugin_domain}

Create And Verify Multiple Sub Domains
  [Tags]    orchestrator  platformLinux
  Add SubDomain   SD1_${ip}   D1_${ip}
  Verify Presence Of SubDomain In  SD1_${ip}   D1_${ip}
  Add SubDomain   SD2_${ip}   D1_${ip}
  Verify Presence Of SubDomain In  SD2_${ip}   D1_${ip}  
  Add SubDomain   SD3_${ip}   D1_${ip}
  Verify Presence Of SubDomain In  SD3_${ip}   D1_${ip}
  Add SubDomain   ${plugin_subdom}   ${plugin_domain}

Delete Domains and Subdomains
  [Tags]    orchestrator  platformLinux
  Delete Domain  D2_${ip}
  Verify Absense Of Domain   D2_${ip}
  Delete Domain  D3_${ip}
  Verify Absense Of Domain   D3_${ip}
  Delete SubDomain  SD3_${ip}   D1_${ip}
  Verify Absense Of SubDomain In  SD3_${ip}   D1_${ip}
  Delete SubDomain  SD2_${ip}   D1_${ip}
  Verify Absense Of SubDomain In  SD2_${ip}   D1_${ip}
  Delete Domain  D1_${ip}
  Verify Absense Of Domain  D1_${ip}

Create Multiple Users, Login For First Time, Change Passwords and Verify Login using them, Delete users
  [Tags]    orchestrator  platformLinux
  Run Only Once   Test User Creation, Setting Password, Logging In And Deletion Of Multiple Users

Manual Install With Protection Mode 
  [Tags]  orchestrator   platformLinux   manual
  ${secrets}=  Create Register Plugin   manual-${PREFIX}-${vm_name}   True    ${plugin_domain}    ${plugin_subdom}    False
  Log    ${secrets}
  Run Manual Installer With Protection Mode   ${secrets}
  Verify AppManager Is Running    ${plugin}
  Restart Application On Plugin With Protection Mode  ${plugin}   ${APP_NAME}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost

Verify Deletion Of Plugin From Orchestrator
  [Tags]  orchestrator    platformLinux   manual
  Stop Application On Plugin   ${plugin}   ${app}
  Verify Deletion of Plugin From Orchestrator

Verify Uninstallation of plugin
  [Tags]  orchestrator    platformLinux   manual
  Uninstall Plugin  ${plugin}   ${ip}   ${APP_NAME}

Delete Plugin Package ${pos.osType}#${pos.osName}#${pos.osVersion}
  [Tags]    orchestrator  platformLinux
  Acquire Lock  ${pos.osType}#${pos.osName}#${pos.osVersion}
  Delete Package    ${pos.osType}   ${pos.osName}   ${pos.osVersion}

Upload Plugin package ${pos.osType}#${pos.osName}#${pos.osVersion}
  [Tags]    orchestrator  platformLinux
  Upload Plugin Package

Push install plugin ${pos.osType}#${pos.osName}#${pos.osVersion} on [${ip}]
  [Tags]   platformLinux
  # IF  '${pos.osName}' == 'Ubuntu'
  #   Sleep  180s  reason=Sleeping for three minutes so that unattended upgrade finishes
  #   # Kill All Apt On Ubuntu
  # END
  IF  '${pos.osName}' == 'RHEL'
    Refresh Subsription Manager on RHEL8
  END
  Create Client Push Install With Exclusive Tenancy    ${PREFIX}-${vm_name}   True    ${plugin_domain}    ${plugin_subdom}    True    ${pos.osType}   ${pos.osName}   ${pos.osVersion}    ${ip}   ${pos.avocado_user}    ${pos.avocado_pwd}
  ${status}=  Wait for client push to finish  ${PREFIX}-${vm_name}
  Release Lock    ${pos.osType}#${pos.osName}#${pos.osVersion}
  Should Be True  ${status}  msg=Plugin installation was not successful
  Whitelist All Python Applications
  Verify AppManager Is Running    ${plugin}

Restart Application [${APP_NAME}] On Plugin [${ip}]
  [Tags]   platformLinux
  Restart Application On Plugin    ${plugin}   ${APP_NAME}

Verify Discovery of Application [${APP_NAME}] on Plugin [${ip}]
  [Tags]   platformLinux
  # ${ip}=  Get Plugin IP        ${plugin}
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

# Restart Application [${APP_NAME}] On Plugin [${ip}]
#   Restart Application On Plugin   ${plugin}   ${APP_NAME} 

Register Application [${APP_NAME}] on Plugin [${ip}] With Protect Mode
  [Tags]    orchestrator  platformLinux
  Register App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Protect App From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Application [${APP_NAME}] On Plugin [${ip}] after Enabling Protect
  [Tags]   platformLinux
  Restart Application On Plugin   ${plugin}   ${APP_NAME} 

Verify Application [${APP_NAME}] on Plugin [${ip}] Can Not Be Accessed
  [Tags]   platformLinux
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost

Allow Protected Application [${APP_NAME}] on Plugin [${ip}] 
  [Tags]    orchestrator  platformLinux
  Allow App From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Application [${APP_NAME}] On Plugin [${ip}] after Allow
  [Tags]   platformLinux
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Application [${APP_NAME}] Can Be Accessed on Plugin [${ip}]
  [Tags]   platformLinux
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost

Delete Registered Application [${APP_NAME}] on Plugin [${ip}]
  [Tags]   platformLinux
  Stop Application On Plugin   ${plugin}   ${APP_NAME}
  Delete Registered App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Create Basic Secure App Policy and allow access to Application [${APP_NAME}] on Plugin [${ip}]
  [Tags]   platformLinux
  Register App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Protect App From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost
  Create Basic Policy   Basic_NS_SAP_${APP_NAME}_${ip}   ${ip}   ${pos}[apps][${APP_NAME}][process_name]  left   allow    mirror   ${plugin_domain}  ${plugin_subdom}
  Verify That The Policy Is Created   Basic_NS_SAP_${APP_NAME}_${ip}

Schedule Basic Secure Application Policy for Application [${APP_NAME}] on Plugin [${ip}]
  [Tags]   platformLinux
  Schedule Policy Always  Basic_NS_SAP_${APP_NAME}_${ip}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost

Verify That An Active Policy Can Not Be Deleted
  [Tags]   platformLinux
  Delete Policy And Verify   Basic_NS_SAP_${APP_NAME}_${ip}  Policy is active. Cannot perform the requested operation.

Suspend Policy And Verify That Application [${APP_NAME}] on Plugin [${ip}] Can Not Be Accessed Any More
  [Tags]   platformLinux
  Suspend Policy And Verify   Basic_NS_SAP_${APP_NAME}_${ip}
  # Sleep   10s 
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost

Verify Policy Deletion 
  [Tags]   platformLinux
  Delete Policy And Verify  Basic_NS_SAP_${APP_NAME}_${ip}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}   localhost

Verify Application Counts Shown In Dashboard
  [Tags]   platformLinux
  Verify Dashboard Apps Count

Verify Domain Counts Shown In Dashboard
  [Tags]   platformLinux
  Verify Dashboard Domain Count

Create Basic Secure App Policy for mysql app on ${ip} and allow access to Unsecure Domain
  [Tags]  if-mysql  platformLinux
  # ${ip}=  Get Plugin IP        ${plugin}
  Verify Application Can Be Accessed From Host    mysql    ${plugin}    extra_args=${external_mysql}
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][mysql][process_name]  ${plugin_domain}  ${plugin_subdom}
  Register App From Tenancy  ${ip}  ${pos}[apps][mysql][process_name]     ${plugin_domain}    ${plugin_subdom}
  Protect App From Tenancy   ${ip}  ${pos}[apps][mysql][process_name]     ${plugin_domain}    ${plugin_subdom}
  Verify Application Can NOT Be Accessed From Host    mysql    ${plugin}  extra_args=${external_mysql}
  Create Basic Policy For Unsecure Domain  Basic_NS_SAP_mysql_${ip}   ${ip}   ${pos}[apps][mysql][process_name]   allow    mirror   ${plugin_domain}    ${plugin_subdom}
  Verify That The Policy Is Created   Basic_NS_SAP_mysql_${ip}
  Schedule Policy Always  Basic_NS_SAP_mysql_${ip}
  Verify Application Can Be Accessed From Host    mysql    ${plugin}    extra_args=${external_mysql}
  Suspend Policy And Verify   Basic_NS_SAP_mysql_${ip}

Upload Multiple Rule Files
  [Tags]  orchestrator  platformLinux
  Upload And Verify Multiple Pcre Rule Files    multiple

Test PCRE policy for SQLi attack on mysqld
  [Tags]  if-mysqld   platformLinux
  Create Basic Policy   NS_mysqld_${ip}   ${ip}   mysqld  left   allow    mirror   ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
  Verify That The Policy Is Created   NS_mysqld_${ip}
  Schedule Policy Always  NS_mysqld_${ip}
  Create Pcre Policy For Registered App  PCRE2_SQLi_${ip}  mysqld  ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
  # Enable All Pcre Rules Of Type  PCRE2_SQLi_${ip}   SQLi
  Enable Pcre Rule   PCRE2_SQLi_${ip}   942160
  Verify Pcre Rule Is Enabled  PCRE2_SQLi_${ip}   942160   SQLi
  Activate Pcre Policy    PCRE2_SQLi_${ip}
  Record Attacks So Far
  Generate SQLi Attack On Mysqld
  Verify That Attack Count Has Increased
  [Teardown]   Suspend MySQL PCRE

Test PCRE policy for XSS attack on tomcat
  [Tags]  if-tomcat   platformLinux
  Create Basic Policy   NS_tomcat_${ip}   ${ip}   java  left   allow    mirror   ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
  Verify That The Policy Is Created   NS_tomcat_${ip}
  Schedule Policy Always  NS_tomcat_${ip}
  Create Pcre Policy For Registered App  PCRE1_XSS_${ip}  java  ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
  # Enable All Pcre Rules Of Type  PCRE1_SQLi_${ip}   SQLi
  Enable Pcre Rule   PCRE1_XSS_${ip}   124
  Verify Pcre Rule Is Enabled  PCRE1_XSS_${ip}   124   XSS
  Activate Pcre Policy    PCRE1_XSS_${ip}
  Record Attacks So Far
  Generate XSS Attack On Tomcat
  Verify That Attack Count Has Increased
  [Teardown]   Suspend Tomcat PCRE

# Create Basic EW Secure App Policy for allowing access to warriors
#   [Tags]    if-tomcat   platformLinux
#   [Setup]   Ensure that plugin with mysql is present
#   Log       ${mysql_ip}
#   ${mysql_dash_ip}=   Get Dash Ip   ${mysql_ip}
#   ${my_pl}=    Fetch Plugin From inventory By IP  ${mysql_ip}
#   Log Dictionary  ${my_pl}  level=INFO
#   Set Test Variable  &{mpos}   &{my_pl}[${mysql_ip}][app_os]
#   # Allow App From Tenancy   ${ip}  tomcat  ${plugin_domain}  ${plugin_subdom}
#   Configure Warriors On Tomcat    ${plugin}     ${mysql_ip}
#   Create Basic Policy From All Domain  All_tomcat_${dash_ip}   ${ip}   ${pos}[apps][tomcat][process_name]   allow    mirror   ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
#   Verify That The Policy Is Created    All_tomcat_${dash_ip}
#   Schedule Policy Always  All_tomcat_${dash_ip}
#   Sleep  5s  reason="Waiting for policy to be effective" 
#   # Restart Application On Plugin   ${my_pl}      mysqld
#   # Restart Application On Plugin   ${plugin}     tomcat
#   # Verify Application Can Be Accessed From Host  tomcat        ${plugin}    localhost
#   Verify That Tomcat Can Be Accessed
#   Verify Application Can NOT Be Accessed From Host  tomcat    ${plugin}    localhost    warriors
#   Create Basic Policy Allow Both Domains   Both_domain_${dash_ip}_${mysql_dash_ip}   ${ip}   ${pos}[apps][tomcat][process_name]   allow    mirror   ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}   ${mysql_ip}   mysqld   ${mpos.av_domain}_${mysql_dash_ip}    ${mpos.av_subdom}_${mysql_dash_ip}
#   Schedule Policy Always  Both_domain_${dash_ip}_${mysql_dash_ip}
#   Verify Application Can Be Accessed From Host  tomcat    ${plugin}    localhost    warriors
#   # [Teardown]  Suspend Policy And Verify   Both_domain_${dash_ip}_${mysql_dash_ip}
#   [Teardown]    Release Plugin  ${mysql_ip}


# Clean Up
#   # ${ip}=  Get Plugin IP        ${plugin}
#   Stop Application On Plugin   ${plugin}   ${APP_NAME}
#   Delete Registered App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
#   Delete Discovered App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

# Clean Up Specific Apps
#   [Tags]  if-mysql
#   Suspend Policy And Verify   Basic_NS_SAP_mysql_${ip}
#   Delete Policy And Verify    Basic_NS_SAP_mysql_${ip}
#   Delete Registered App From Tenancy  ${ip}  ${pos}[apps][mysql][process_name]        ${plugin_domain}  ${plugin_subdom}
#   Delete Discovered App From Tenancy  ${ip}  ${pos}[apps][mysql][process_name]        ${plugin_domain}  ${plugin_subdom}

# Uninstall and Cleanup Plugin on [${ip}]
#   #${ip}=  Get Plugin IP  ${plugin}
#   Uninstall Plugin  ${plugin}   ${ip}   ${APP_NAME}
#   Delete Plugin From Orchestrator Database   ${ip}