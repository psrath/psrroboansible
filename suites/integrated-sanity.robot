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
  Log   Base Url = ${base_url}
  Log   Orch Ip = ${orch_ip}
  ${orche_ip}=   Get Parallel Value For Key   orch_ip
  ${base_url}=   Get Parallel Value For Key   base_url
  IF  '${orche_ip}' != '${EMPTY}'
    Set Suite Variable  ${orch_ip}  ${orche_ip}
    Set Suite Variable  ${base_url}  ${base_url}
    ${orchestrator.ansible_ssh_host}=     Set Variable    ${orch_ip}
    Log Dictionary  ${orchestrator}
    Log   Base Url Now = ${base_url}
    Log   Orch Ip Now = ${orch_ip}
  END
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
  Add Domain  ${plugin_domain}
  Add Domain  D1_${ip}
  Verify Presence Of Domain   D1_${ip} 
  Add Domain  D2_${ip}
  Verify Presence Of Domain   D2_${ip}
  Add Domain  D3_${ip}
  Verify Presence Of Domain   D3_${ip}

Create And Verify Multiple Sub Domains
  [Tags]    orchestrator  platformLinux
  Add SubDomain   ${plugin_subdom}   ${plugin_domain}
  Add SubDomain   SD1_${ip}   D1_${ip}
  Verify Presence Of SubDomain In  SD1_${ip}   D1_${ip}
  Add SubDomain   SD2_${ip}   D1_${ip}
  Verify Presence Of SubDomain In  SD2_${ip}   D1_${ip}  
  Add SubDomain   SD3_${ip}   D1_${ip}
  Verify Presence Of SubDomain In  SD3_${ip}   D1_${ip}

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
  [Tags]  orchestrator   platformLinux   manual
  Stop Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Deletion of Plugin From Orchestrator

Verify Uninstallation of plugin
  [Tags]  orchestrator   platformLinux   manual
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


##################################################################
###        Reports Generation and Validation test cases        ###
##################################################################

Create And Download Application Details Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_Details
  Set Suite Variable  ${REPORT_NAME}    Application Details
  Set Suite Variable  ${REPORT_FORMAT}    appDetailWithServerInfocsv
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create And Download Application Forensic Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_Forensic
  Set Suite Variable  ${REPORT_NAME}    Application Forensic
  Set Suite Variable  ${REPORT_FORMAT}    appStatsDetailWithServerInfocsv
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create And Download Application Forensic Session Details Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_Forensic_Session_Details
  Set Suite Variable  ${REPORT_NAME}    Application Forensic Session Details
  Set Suite Variable  ${REPORT_FORMAT}    appStatsSessionDetailWithServerInfocsv
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create Attacked Applications Details Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Attacked_Applications_Details
  Set Suite Variable  ${REPORT_NAME}    Attacked Application Details
  Set Suite Variable  ${REPORT_FORMAT}    attackappcsvReport
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create And Download Discovered Applications Details Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Discovered_Application_Details
  Set Suite Variable  ${REPORT_NAME}    Discovered Application Details
  Set Suite Variable  ${REPORT_FORMAT}    discoveredappcsvReport
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create Secure Application Policy Details Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Secure_Application_Policy_Details
  Set Suite Variable  ${REPORT_NAME}    Secure Application Policy Details
  Set Suite Variable  ${REPORT_FORMAT}    appsecpolicycsvReport
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Default Application Model Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    default
  Set Suite Variable  ${REPORT_NAME}    Default Application Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Threat Dragon Application Model Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    Threat Dragon
  Set Suite Variable  ${REPORT_NAME}    Threat Dragon Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Threat Dragon ++ Application Model Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    Threat Dragon ++
  Set Suite Variable  ${REPORT_NAME}    Threat Dragon ++ Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Microsoft TMT Application Model Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    Microsoft TMT
  Set Suite Variable  ${REPORT_NAME}    Microsoft TMT Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create PCRE Affected Server Sessions By Policy Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    PCRE_Affected_Server_Sessions_Details
  Set Suite Variable  ${REPORT_FORMAT}    pcreAffectedServerSessionsDetailsCsv
  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Affected Server Sessions by Policy
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create PCRE Affected Server Stats By Application Report
  [Tags]   platformLinux
  Set Suite Variable  ${REPORT_TYPE}    PCRE_Affected_Server_Stats_By_Apps
  Set Suite Variable  ${REPORT_FORMAT}    pcreAffectedServerStatsByAppsCsv
  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Affected Server Stats by Application
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}


##################################################################
###    Windows Sanity Suite Test Cases    ###
##################################################################


##################################################################
###    Create Domain and Subdomain on orchestrator test case   ###
##################################################################

Login to Orchestrator Via Api
  [Tags]    orchestrator  platformWindows
  Login Into Orchestrator using API

Create And Verify Multiple Domains
  [Tags]    orchestrator  platformWindows
  Add Domain  ${plugin_domain}
  ${passed}=  Run Keyword And Return Status    Verify Presence Of Domain   ${plugin_domain}
  Run Keyword Unless    ${passed}    Fatal Error

Create And Verify Multiple Sub Domains
  [Tags]    orchestrator  platformWindows
  Add SubDomain   ${plugin_subdom}   ${plugin_domain}
  ${passed}=  Run Keyword And Return Status    Verify Presence Of SubDomain In    ${plugin_subdom}   ${plugin_domain}
  Run Keyword Unless    ${passed}    Fatal Error

##################################################################
###            Manual plugin installation test case            ###
##################################################################

Register Plugin on Orchestrator and Install it On Win VM [${ip}]
  [Tags]   platformWindows
  ${secrets}=  Create Register Plugin   ${PREFIX}-${pos.av_domain}-${ip}   True    ${plugin_domain}    ${plugin_subdom}    True
  ${passed}=  Run Keyword And Return Status    Copy ASP Plugin Installation File    ${plugin}
  Run Keyword Unless    ${passed}    Fatal Error
  ${passed}=  Run Keyword And Return Status    Install ASP Plugin From Installation File    ${plugin}  ${secrets}
  Run Keyword Unless    ${passed}    Fatal Error

Verify ASP Plugin App Manager is running on Win VM
  [Tags]   platformWindows
  Verify AppManager Is Running    ${plugin}

##################################################################
###          Server applications discovery test cases          ###
##################################################################

Verify Discovery of Application powershell on Plugin [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    powershell
  Log to Console    APP_NAME=${APP_NAME}
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Service tomcat On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    tomcat
  Log to Console    APP_NAME=${APP_NAME}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application tomcat On Win VM [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Service mysql On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    mysql
  Log to Console    APP_NAME=${APP_NAME}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Application mysql Can Be Accessed On Win VM [${ip}]
  [Tags]   platformWindows
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}

Verify Discovery of Application mysql on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Service mysqld On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    mysqld
  Log to Console    APP_NAME=${APP_NAME}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Application mysqld Can Be Accessed on Plugin [${ip}]
  [Tags]   platformWindows
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}

Verify Discovery of Application mysqld on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Service sqlserver On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    sqlserver
  Log to Console    APP_NAME=${APP_NAME}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application sqlserver on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Start mysqlsh Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    mysqlsh
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application mysqlsh on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop mysqlsh Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

##################################################################
###          Client applications discovery test cases          ###
##################################################################

Start ssms Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    ssms
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application ssms on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop ssms Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start ms_profiler Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    ms_profiler
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application ms_profiler on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop ms_profiler Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start work_bench Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    work_bench
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application work_bench on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop work_bench Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start heidisql Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    heidisql
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application heidisql on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop heidisql Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start firefox Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    firefox
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application firefox on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop firefox Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start chrome Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    chrome
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application chrome on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop chrome Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start edge Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    edge
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application edge on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop edge Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Start internet_explorer Application On Win VM [${ip}]
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    internet_explorer
  Log to Console    APP_NAME=${APP_NAME}
  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

Verify Discovery of Application internet_explorer on Plugin [${ip}]
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Stop internet_explorer Application On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

#Start spring_boot Application On Win VM [${ip}]
#  [Tags]   platformWindows
#  Set Suite Variable  ${APP_NAME}    spring_boot
#  Log to Console    APP_NAME=${APP_NAME}
#  Start Desktop Application on Plugin   ${plugin}   ${APP_NAME}

#Verify Discovery of Application spring_boot on Plugin [${ip}]
#  [Tags]   platformWindows
#  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

#Stop spring_boot Application On Win VM [${ip}]
#  [Tags]   platformWindows
#  Stop Desktop Application on Plugin   ${plugin}   ${APP_NAME}

##################################################################
###        Reports Generation and Validation test cases        ###
##################################################################

Create And Download Application Details Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_Details
  Set Suite Variable  ${REPORT_NAME}    Application Details
  Set Suite Variable  ${REPORT_FORMAT}    appDetailWithServerInfocsv
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create And Download Application Forensic Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_Forensic
  Set Suite Variable  ${REPORT_NAME}    Application Forensic
  Set Suite Variable  ${REPORT_FORMAT}    appStatsDetailWithServerInfocsv
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create And Download Application Forensic Session Details Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_Forensic_Session_Details
  Set Suite Variable  ${REPORT_NAME}    Application Forensic Session Details
  Set Suite Variable  ${REPORT_FORMAT}    appStatsSessionDetailWithServerInfocsv
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create Attacked Applications Details Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Attacked_Applications_Details
  Set Suite Variable  ${REPORT_NAME}    Attacked Application Details
  Set Suite Variable  ${REPORT_FORMAT}    attackappcsvReport
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create And Download Discovered Applications Details Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Discovered_Application_Details
  Set Suite Variable  ${REPORT_NAME}    Discovered Application Details
  Set Suite Variable  ${REPORT_FORMAT}    discoveredappcsvReport
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  Download Report    ${report_filename}    ${REPORT_NAME}
  Verify Report Was Downloaded    ${report_filename}

Create Secure Application Policy Details Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Secure_Application_Policy_Details
  Set Suite Variable  ${REPORT_NAME}    Secure Application Policy Details
  Set Suite Variable  ${REPORT_FORMAT}    appsecpolicycsvReport
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Default Application Model Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    default
  Set Suite Variable  ${REPORT_NAME}    Default Application Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Threat Dragon Application Model Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    Threat Dragon
  Set Suite Variable  ${REPORT_NAME}    Threat Dragon Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Threat Dragon ++ Application Model Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    Threat Dragon ++
  Set Suite Variable  ${REPORT_NAME}    Threat Dragon ++ Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create Microsoft TMT Application Model Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    Application_model
  Set Suite Variable  ${REPORT_FORMAT}    applicationModelJson
  Set Suite Variable  ${MODEL_TYPE}    Microsoft TMT
  Set Suite Variable  ${REPORT_NAME}    Microsoft TMT Model
  ${generate_report_response}=  Create Report Application Model    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${MODEL_TYPE}    ${plugin_domain}    ${plugin_subdom}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create PCRE Affected Server Sessions By Policy Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    PCRE_Affected_Server_Sessions_Details
  Set Suite Variable  ${REPORT_FORMAT}    pcreAffectedServerSessionsDetailsCsv
  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Affected Server Sessions by Policy
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

Create PCRE Affected Server Stats By Application Report
  [Tags]   platformWindows
  Set Suite Variable  ${REPORT_TYPE}    PCRE_Affected_Server_Stats_By_Apps
  Set Suite Variable  ${REPORT_FORMAT}    pcreAffectedServerStatsByAppsCsv
  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Affected Server Stats by Application
  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
  #Download Report    ${report_filename}    ${REPORT_NAME}
  #Verify Report Was Downloaded    ${report_filename}

# Commented out last 5 PCRE reports generation tests cases, because it takes more than 60sec to get "No data found for report generation"
# notification for each PCRE reports generation test case
#Create PCRE Affected Server Stats By Policy Report
#  [Tags]   platformWindows
#  Set Suite Variable  ${REPORT_TYPE}    PCRE_Affected_Server_Stats_Details
#  Set Suite Variable  ${REPORT_FORMAT}    pcreAffectedServerStatsDetailsCsv
#  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Affected Server Stats by Policy
#  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
#  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
#  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
#  Download Report    ${report_filename}    ${REPORT_NAME}
#  Verify Report Was Downloaded    ${report_filename}

#Create PCRE Attacking Clients Sessions By Policy Report
#  [Tags]   platformWindows
#  Set Suite Variable  ${REPORT_TYPE}    PCRE_Attacking_Clients_Sessions
#  Set Suite Variable  ${REPORT_FORMAT}    pcreAttackingClientsSessionsCsv
#  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Attacking Clients Sessions by Policy
#  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
#  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
#  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
#  Download Report    ${report_filename}    ${REPORT_NAME}
#  Verify Report Was Downloaded    ${report_filename}

#Create PCRE Attacking Clients Stats By Application Report
#  [Tags]   platformWindows
#  Set Suite Variable  ${REPORT_TYPE}    PCRE_Attacking_Clients_Stats_By_Apps
#  Set Suite Variable  ${REPORT_FORMAT}    pcreAttackingClientsStatsByAppsCsv
#  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Attacking Clients Stats by Application
#  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
#  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
#  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
#  Download Report    ${report_filename}    ${REPORT_NAME}
#  Verify Report Was Downloaded    ${report_filename}

#Create PCRE Attacking Clients Stats By Policy Report
#  [Tags]   platformWindows
#  Set Suite Variable  ${REPORT_TYPE}    PCRE_Attacking_Clients_Stats
#  Set Suite Variable  ${REPORT_FORMAT}    pcreAttackingClientsStatsCsv
#  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Attacking Clients Stats by Policy
#  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
#  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
#  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
#  Download Report    ${report_filename}    ${REPORT_NAME}
#  Verify Report Was Downloaded    ${report_filename}

#Create PCRE Secure Data Policy Details Report
#  [Tags]   platformWindows
#  Set Suite Variable  ${REPORT_TYPE}    PCRE_Policy_Details
#  Set Suite Variable  ${REPORT_FORMAT}    pcrePoliciesDetailsCsv
#  Set Suite Variable  ${REPORT_NAME}    OWASP Top 10 - Secure Data Policy Details
#  ${generate_report_response}=  Create Report    ${REPORT_TYPE}    ${REPORT_FORMAT}    ${plugin_domain}    ${plugin_subdom}    ${ip}
#  Verify Report Generation Started    ${REPORT_TYPE}    Report Generation started in background    ${generate_report_response}
#  ${report_filename}=  Get Report Generation Notification    ${REPORT_NAME}
#  Download Report    ${report_filename}    ${REPORT_NAME}
#  Verify Report Was Downloaded    ${report_filename}

##################################################################
###        Secure Application Policy test cases - mysql        ###
##################################################################

Restart Service mysql On Win VM [${ip}] Before Secure Application Policy Test Cases
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    mysql
  Log to Console    APP_NAME=${APP_NAME}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Application mysql Can Be Accessed On Win VM [${ip}] Before Secure Application Policy Test Cases
  [Tags]   platformWindows
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}

Verify Discovery of Application mysql On Win VM [${ip}] Before Secure Application Policy Test Cases
  [Tags]   platformWindows
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Register Application mysql On Win VM [${ip}] With Protect Mode
  [Tags]   platformWindows
  Register App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Protect App From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Application mysql On Win VM [${ip}] after Enabling Protect
  [Tags]   platformWindows
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Application mysql On Win VM [${ip}] Can Not Be Accessed
  [Tags]   platformWindows
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}

Allow Protected Application mysql On Win VM [${ip}]
  [Tags]   platformWindows
  Allow App From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Restart Application mysql On Win VM [${ip}] after Allow
  [Tags]   platformWindows
  Restart Application On Plugin   ${plugin}   ${APP_NAME}

Verify Application mysql Can Be Accessed On Win VM [${ip}] after Allow
  [Tags]   platformWindows
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}

Delete Registered Application mysql On Win VM [${ip}]
  [Tags]   platformWindows
  Stop Application On Plugin   ${plugin}   ${APP_NAME}
  Delete Registered App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

Create Basic Secure App Policy and allow access to Application mysql On Win VM [${ip}]
  [Tags]   platformWindows
  Register App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Protect App From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}
  Create Basic Policy   Basic_NS_SAP_${APP_NAME}_${ip}   ${ip}   ${pos}[apps][${APP_NAME}][process_name]  left   allow    mirror   ${plugin_domain}  ${plugin_subdom}
  Verify That The Policy Is Created   Basic_NS_SAP_${APP_NAME}_${ip}

Schedule Basic Secure Application Policy for Application mysql On Win VM [${ip}]
  [Tags]   platformWindows
  Schedule Policy Always  Basic_NS_SAP_${APP_NAME}_${ip}
  Restart Application On Plugin   ${plugin}   mysqld
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}

Verify That An Active Policy Can Not Be Deleted During mysql Secure Application Policy Test Cases
  [Tags]   platformWindows
  Delete Policy And Verify   Basic_NS_SAP_${APP_NAME}_${ip}  Policy is active. Cannot perform the requested operation.

Suspend Policy And Verify That Application mysql On Win VM [${ip}] Can Not Be Accessed Any More
  [Tags]   platformWindows
  Suspend Policy And Verify   Basic_NS_SAP_${APP_NAME}_${ip}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}

Verify Policy Deletion During mysql Secure Application Policy Test Cases
  [Tags]   platformWindows
  Delete Policy And Verify  Basic_NS_SAP_${APP_NAME}_${ip}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}

Verify Application Counts Shown In Dashboard After mysql Secure Application Policy Test Cases
  [Tags]   platformWindows
  Verify Dashboard Apps Count

Verify Domain Counts Shown In Dashboard After mysql Secure Application Policy Test Cases
  [Tags]   platformWindows
  Verify Dashboard Domain Count

##################################################################
###        Non-adpl (unsecured) policy test case - mysql       ###
##################################################################

Create Basic Secure App Policy for mysql app on ${ip} and allow access to Unsecure Domain
  [Tags]   platformWindows
  Delete Registered App From Tenancy  ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Restart Application On Plugin   ${plugin}   ${APP_NAME}
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}    extra_args=${external_mysql}
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][mysql][process_name]  ${plugin_domain}  ${plugin_subdom}
  Register App From Tenancy  ${ip}  ${pos}[apps][mysql][process_name]     ${plugin_domain}    ${plugin_subdom}
  Protect App From Tenancy   ${ip}  ${pos}[apps][mysql][process_name]     ${plugin_domain}    ${plugin_subdom}
  Verify Application Can NOT Be Accessed From Host    ${APP_NAME}    ${plugin}  extra_args=${external_mysql}
  Create Basic Policy For Unsecure Domain  Basic_NS_SAP_mysql_${ip}   ${ip}   ${pos}[apps][mysql][process_name]   allow    mirror   ${plugin_domain}    ${plugin_subdom}
  Verify That The Policy Is Created   Basic_NS_SAP_mysql_${ip}
  Schedule Policy Always  Basic_NS_SAP_mysql_${ip}
  Verify Application Can Be Accessed From Host    ${APP_NAME}    ${plugin}    extra_args=${external_mysql}
  Suspend Policy And Verify   Basic_NS_SAP_mysql_${ip}

##################################################################
###             Upload PCRE rule file(s) test case             ###
##################################################################

Upload Multiple Rule Files
  [Tags]   platformWindows
  Upload And Verify Multiple Pcre Rule Files    multiple

##################################################################
###            Secure Data Policy test cases - tomcat          ###
##################################################################

Test PCRE policy for XSS attack on tomcat
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    tomcat
  Log to Console    APP_NAME=${APP_NAME}
  Create Basic Policy   NS_tomcat_${ip}   ${ip}   ${pos}[apps][${APP_NAME}][process_name]  left   allow    mirror  ${plugin_domain}  ${plugin_subdom}
  Verify That The Policy Is Created   NS_tomcat_${ip}
  Schedule Policy Always  NS_tomcat_${ip}
  Create Pcre Policy For Registered App  PCRE1_XSS_${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}
  Enable Pcre Rule   PCRE1_XSS_${ip}   124
  Verify Pcre Rule Is Enabled  PCRE1_XSS_${ip}   124   XSS
  Activate Pcre Policy    PCRE1_XSS_${ip}
  Record Attacks So Far
  Generate XSS Attack On Tomcat
  Verify That Attack Count Has Increased
  [Teardown]   Suspend Tomcat PCRE

##################################################################
###            Secure Data Policy test cases - mysql           ###
##################################################################

Test PCRE policy for SQLi attack on mysqld
  [Tags]   platformWindows
  Set Suite Variable  ${APP_NAME}    mysql
  Log to Console    APP_NAME=${APP_NAME}
  Create Basic Policy   NS_mysqld_${ip}   ${ip}   ${pos}[apps][${APP_NAME}][process_name]  left   allow    mirror   ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
  Verify That The Policy Is Created   NS_mysqld_${ip}
  Schedule Policy Always  NS_mysqld_${ip}
  Create Pcre Policy For Registered App  PCRE2_SQLi_${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${pos.av_domain}_${dash_ip}    ${pos.av_subdom}_${dash_ip}
  Enable Pcre Rule   PCRE2_SQLi_${ip}   942160
  Verify Pcre Rule Is Enabled  PCRE2_SQLi_${ip}   942160   SQLi
  Activate Pcre Policy    PCRE2_SQLi_${ip}
  Record Attacks So Far
  Generate SQLi Attack On Mysqld
  Verify That Attack Count Has Increased
  [Teardown]   Suspend Policies   NS_mysqld_${ip}   PCRE2_S

Uninstall ASP plugin from Win VM
  [Tags]   platformWindows
  Uninstall Plugin  ${plugin}   ${ip}   ${APP_NAME}