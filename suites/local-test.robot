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
  Run Manual Installer Using install_adpl.sh Script   ${secrets}
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
  Enable Debug And Trace Log for ADPL amd AppMgr
  Release Lock    ${pos.osType}#${pos.osName}#${pos.osVersion}
  Should Be True  ${status}  msg=Plugin installation was not successful
  Whitelist All Python Applications
  Verify AppManager Is Running    ${plugin}

Restart Application [${APP_NAME}] On Plugin [${ip}]
  [Tags]   platformLinux
  Restart Application On Plugin    ${plugin}   ${APP_NAME}

Verify Discovery of Application [${APP_NAME}] on Plugin [${ip}]
  [Tags]   platformLinux
  Verify App Is Discovered On Host From Tenancy   ${ip}  ${pos}[apps][${APP_NAME}][process_name]  ${plugin_domain}  ${plugin_subdom}

