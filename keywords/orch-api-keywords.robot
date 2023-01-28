
*** Keywords ***
# Setup Infrastructure To Run Automation
#   [Arguments]     ${app_os}    ${proxmox_instance}    ${NAME_APP_OS}
#   Log     ${app_os}
#   Environmnet Setup   ${app_os}    ${proxmox_instance}
#   Set Suite Variable  ${APP_OS_NAME}    ${NAME_APP_OS}
#   Log     ${APP_OS_NAME}
#   Log     ${PROXMOX}
#   Log     ${PREFIX}
#   Log   Base Url = ${base_url}
#   Log   Orch Ip = ${orch_ip}
#   ${orche_ip}=   Get Parallel Value For Key   orch_ip
#   ${base_url}=   Get Parallel Value For Key   base_url
#   IF  '${orche_ip}' != '${EMPTY}'
#     Set Suite Variable  ${orch_ip}  ${orche_ip}
#     Set Suite Variable  ${base_url}  ${base_url}
#     ${orchestrator.ansible_ssh_host}=     Set Variable    ${orch_ip}
#     Log Dictionary  ${orchestrator}
#     Log   Base Url Now = ${base_url}
#     Log   Orch Ip Now = ${orch_ip}
#   END
#   Set Proxmox Ip List     ${${PROXMOX}}   ${testenv.${PREFIX}.vm_ips}
#   Log   ${${proxmox}.vm_ips}
#   Log   ${APP_OS}
#   ${plugin}=  Deploy VM on proxmox  ${APP_OS}  ${${PROXMOX}}
#   Set Suite Variable  &{plugin}   &{plugin}
#   ${ip}=  Get Plugin IP        ${plugin}
#   Set Suite Variable  &{pos}   &{plugin}[${ip}][app_os]
#   Set Suite Variable  ${ip}    ${ip}
#   ${dash_ip}=   Get Dash Ip   ${ip}
#   Set Suite Variable  ${dash_ip}    ${dash_ip}
#   Set Suite Variable    ${plugin_domain}        ${pos.av_domain}_${dash_ip}
#   Set Suite Variable    ${plugin_subdom}        ${pos.av_subdom}_${dash_ip}
#   Log Dictionary  ${pos}  level=INFO

Environmnet Setup
  [Arguments]     ${app_os}    ${proxmox_instance}
  Log   ${app_os}
  ${value}=   Evaluate   ${testenv}.get('${PREFIX}', ${EMPTY})
  IF  ${value} == None
    Fatal Error  msg=Unable to find test environment '${PREFIX}' configuration, Exiting...
  END
  Set Parallel Value For Key   inventory       ${used_ips}
  Set Parallel Value For Key   ips_in_deploy   ${ips_in_deploy}
  Set Parallel Value For Key   newid           5000
  Set Parallel Value For Key   instance_cnt    ${instance_cnt}
  Set Parallel Value For Key   build_num       ${BUILD_NUM}
  Log  Using Build System = ${BUILD_SYSTEM}
  Log  Using MAJOR_RELEASE = ${MAJOR_RELEASE}
  Download Plugins Build    ${BUILD_SYSTEM}
  Log  Using Build ${BUILD_NUM}
  IF  '${DEPLOY_ORCH}' != '${EMPTY}'
    Download Orchestrator Build    ${ORCH_BUILD_NUM}
    ${ORCH_BUILD_NUM}=    Get Parallel Value For Key   orch_build_num
    Log  Using Orchestraor Build ${ORCH_BUILD_NUM}
  END
  Shutdown All Automation VMs And Remove Ipconfig On them   ${app_os}    ${proxmox_instance}
  IF  '${DEPLOY_ORCH}' != '${EMPTY}'
    Deploy Orchestrator VM on proxmox
    Install Orchestrator  ${ORCH_BUILD_NUM}
    Set Global Variable   ${orch_ip}   ${ip}
    Set Parallel Value For Key   orch_ip   ${ip}
    Log   Using Orchestrator @ ${orch_ip}
    Set Global Variable  ${base_url}  https://${orch_ip}:8443/orchestrator
    Set Parallel Value For Key   base_url   ${base_url}
    Log  base_url=${base_url}
    Login For First Time   administrator    $ecure@Av19   Avocado_protect@20
    Login Into Orchestrator using API
    Set Parallel Value For Key     orch_install_status    ${True}
  END
  
Deploy Orchestraor VM and Install Orchestraor Build
  IF  '${DEPLOY_ORCH}' != '${EMPTY}'
    Log  Using Orchestraor Build ${ORCH_BUILD_NUM}
    ${orch_install_status}=    Get Parallel Value For Key   orch_install_status
    Log     orch_install_status = ${orch_install_status}
    IF    ${orch_install_status} == ${True}
      Pass Execution    Orchestrator Install Was Successful
    ELSE
      Fatal Error    Orchestrator Install Was Not Successful. Hence Exiting..
    END
  ELSE 
    Login Into Orchestrator using API
    Log    Pre-deployed external orchstrator is being used hence passing
  END

Install Orchestrator
  [Arguments]     ${ORCH_BUILD_NUM}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${extra}=   Create Dictionary     build_dir=${EXECDIR}/build/${ORCH_BUILD_NUM}/
  Run Playbook On Host   install-orchestrator.yml   inventory=${t_inv}    extra=${extra}

Acquire Plugin
  [Arguments]     ${plugin_ip}=${EMPTY}
  IF   '${plugin_ip}' != '${EMPTY}'
    Log   Acquiring Lock On ${plugin_ip}
    Acquire Lock    ${plugin_ip}
  ELSE
    ${val}=   Get Variable Value  ${ip}
    IF  '${val}' != 'None'
      Log   Acquiring Lock On ${ip}
      Acquire Lock    ${ip}  
    ELSE
      Log  "Plugin IP Not found"
    END
  END

Release Plugin
  [Arguments]     ${plugin_ip}=${EMPTY}
  IF   '${plugin_ip}' != '${EMPTY}'
    Log   Releasing Lock On ${plugin_ip}
    Release Lock    ${plugin_ip}
  ELSE
    ${val}=   Get Variable Value  ${ip}
    IF  '${val}' != 'None'
      Log   Releasing Lock On ${ip}
      Release Lock    ${ip}  
    ELSE
      Log  "Plugin IP Not found"
    END
  END
  Pass Execution  Plugin Released

Test User Creation, Setting Password, Logging In And Deletion Of Multiple Users
  Create User   manoj   Avocado_protect@21
  Verify User Is Added   manoj
  Login For First Time   manoj   Avocado_protect@21  Avocado_protect@20
  Login Into Orchestrator As   manoj
  Delete User   manoj
  Create User   andrzej   Avocado_protect@21
  Verify User Is Added   andrzej
  Login For First Time   andrzej   Avocado_protect@21  Avocado_protect@20
  Login Into Orchestrator As   andrzej
  Delete User   andrzej
  Create User   sankalp   Avocado_protect@21
  Verify User Is Added   sankalp
  Login For First Time   sankalp   Avocado_protect@21  Avocado_protect@20
  Login Into Orchestrator As   sankalp
  Delete User   sankalp

Shutdown All Automation VMs And Remove Ipconfig On them
  [Arguments]     ${app_os}    ${proxmox_instance}
  &{dict1}=  Create Dictionary  app_os=${app_os}  proxmox=${proxmox_instance}
  &{dict2}=  Create Dictionary  ${proxmox_instance.host}   ${dict1}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict2}
  ${extra}=   Create Dictionary     NAME_PREFIX=${PREFIX}
  Run Playbook On Proxmox   shutdown-all-auto-vms.yml    inventory=${t_inv}    extra=${extra}

Destroy VMs
  [Arguments]     ${app_os}    ${proxmox_instance}
  Log To Console  Inside keyword  stream=STDOUT  no_newline=False
  &{dict1}=  Create Dictionary  app_os=${app_os}  proxmox=${proxmox_instance}
  &{dict2}=  Create Dictionary  ${proxmox_instance.host}   ${dict1}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict2}
  ${extra}=   Create Dictionary     os_type=${app_os}[osType]
  Run Playbook On Proxmox   destroy-vms.yml    inventory=${t_inv}    extra=${extra}

# Login Into Orchestrator UI 
#   ${headers}=   Create dictionary   Authorization=${token}    Content-Type=application/x-www-form-urlencoded
#   &{data}=    Create dictionary  username=administrator   password=Avocado_protect@20   grant_type=password
#   ${resp_json}=     POST On Session  ${session}   /oauth/token  data=${data}    headers=${headers}

Login Into Orchestrator using API
  Login Into Orchestrator

Print All Policies
  ${pols}=    Get All Policies
  Log Dictionary  ${pols}  level=INFO

Print Domains
  ${domains}=   Get Domains
  Log Dictionary  ${domains}  level=INFO

Print Sub Domains of 
  [Arguments]   ${domain_name}
  ${subdomains}=    Get Sub Domains Of   ${domain_name}
  Log Dictionary  ${subdomains}  level=INFO

Verify Presence Of Domain
  [Arguments]   ${domain_name}
  ${domain_list}=    Get Domains
  ${value}=	  Get Value From Json	  ${domain_list}	  $.listCustomers..custName
  Log List    ${value}  level=INFO
  List Should Contain Value  ${value}  ${domain_name}  msg="Found Domain ${domain_name}"

Verify Absense Of Domain
  [Arguments]   ${domain_name}
  ${domain_list}=    Get Domains
  ${value}=	  Get Value From Json	  ${domain_list}	  $.listCustomers..custName
  Log List    ${value}  level=INFO
  List Should Not Contain Value  ${value}  ${domain_name}  msg="Domain Not Found ${domain_name}"

Verify Presence Of SubDomain In
  [Arguments]   ${subdomain_name}    ${domain_name}
  ${subdomain_list}=    Get Sub Domains Of   ${domain_name}
  ${value}=	  Get Value From Json	  ${subdomain_list}	  $.listDepartments..deptName
  Log List    ${value}  level=INFO
  List Should Contain Value  ${value}  ${subdomain_name}  msg="Found SubDomain ${subdomain_name}"

Verify Absense Of SubDomain In
  [Arguments]   ${subdomain_name}    ${domain_name}
  ${subdomain_list}=    Get Sub Domains Of   ${domain_name}
  ${value}=	  Get Value From Json	  ${subdomain_list}	  $.listDepartments..deptName
  Log List    ${value}  level=INFO
  List Should Not Contain Value  ${value}  ${subdomain_name}  msg="SubDomain Not Found ${subdomain_name}"

Deploy Orchestrator VM on proxmox
  Log     ${PROXMOX}
  Log     ${PREFIX}
  Log     ${ORCH_OS}
  Set Proxmox Ip List     ${${PROXMOX}}   ${testenv.${PREFIX}.orch_ips}
  Log   ${${proxmox}.vm_ips}
  IF   '${ORCH_OS}' == 'RHEL8'
    Set Suite Variable  ${APP_OS_NAME}    orch_rhel84
    ${plugin}=  Deploy VM on proxmox  ${orch_rhel84}  ${${PROXMOX}}
  ELSE IF   '${ORCH_OS}' == 'OL7'
    Set Suite Variable  ${APP_OS_NAME}    orch_ol7
    ${plugin}=  Deploy VM on proxmox  ${orch_ol7}  ${${PROXMOX}}
  ELSE
    Set Suite Variable  ${APP_OS_NAME}    orch_co7
    ${plugin}=  Deploy VM on proxmox  ${orch_co7}  ${${PROXMOX}}
  END
  Set Suite Variable  &{plugin}   &{plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Suite Variable  ${ip}    ${ip}
  ${dash_ip}=   Get Dash Ip   ${ip}

Deploy VM on proxmox
  [Arguments]     ${app_os}    ${proxmox_instance}
  Log To Console  Inside keyword  stream=STDOUT  no_newline=False
  &{dict1}=  Create Dictionary  app_os=${app_os}  proxmox=${proxmox_instance}
  &{dict2}=  Create Dictionary  ${proxmox_instance.host}   ${dict1}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict2}
  Acquire Lock  GetIP
  @{inventory}=    Get Parallel Value For Key   inventory
  Log List  ${inventory}
  @{in_deploy}=    Get Parallel Value For Key   ips_in_deploy
  ${newid}=    Get Parallel Value For Key       newid
  Log List     ${in_deploy}
  ${ip_to_assign}=    Get Unused IP    ${inventory}    ${proxmox_instance}   ${in_deploy}
  ${vmid_to_assign}=  Get VM ID To Assign   ${newid}   ${proxmox_instance.host}
  Should Not Be Equal  ${ip_to_assign}  NOT FOUND  msg='All IPs are used from the proxmox ${proxmox_instance.host}'
  Append To List  ${in_deploy}  ${ip_to_assign}
  Set Parallel Value For Key     ips_in_deploy   ${in_deploy}
  Set Parallel Value For Key     newid           ${vmid_to_assign}
  @{deploy}=    Get Parallel Value For Key   ips_in_deploy
  Log List  ${deploy}  level=INFO
  Log     ${APP_OS_NAME}
  ${vm_name}=   Get Dash Name  ${APP_OS_NAME}
  Set Suite Variable  ${vm_name}  ${vm_name}
  Log   "vm_name = "${vm_name}
  Release Lock  GetIP
  # ${vm_name}=   Get Dash Ip  ${ip_to_assign}
  IF  '${app_os}[osType]' == 'Linux'
    ${extra}=   Create Dictionary     IP_ADDRESS=${ip_to_assign}    GIVEN_NAME=${vm_name}   NEW_ID=${vmid_to_assign}  APP_OS_NAME=${APP_OS_NAME}  NAME_PREFIX=${PREFIX}
    Run Playbook On Proxmox  new-deploy-vm.yml    inventory=${t_inv}   extra=${extra}
  ELSE IF  '${app_os}[osType]' == 'Windows'
    ${extra}=   Create Dictionary     IP_ADDRESS=${ip_to_assign}    GIVEN_NAME=${vm_name}    NEW_ID=${vmid_to_assign}  APP_OS_NAME=${APP_OS_NAME}   NAME_PREFIX=${PREFIX}
    Log To Console    Started to clone Win VM from template, it will take up to 10min to create full clone of Win VM  stream=STDOUT  no_newline=False
    Run Playbook On Proxmox  win-new-deploy-vm.yml    inventory=${t_inv}   extra=${extra}
  END
  ${result}=    Load JSON From File   /tmp/${proxmox_instance.host}/tmp/ip-${vm_name}.txt
  ${ip_address}=  Get Vm Ip    ${result}    ${app_os}[osType]    ${ip_to_assign}
  &{dict} =    Create Dictionary    app_os=${app_os}    proxmox_instance=${proxmox_instance}
  Log Dictionary  ${dict}  level=INFO
  &{host} =    Create Dictionary    ${ip_address}=&{dict}
  Log Dictionary  ${host}  level=INFO
  Acquire Lock  GetIP
  @{inventory}=   Get Parallel Value For Key     inventory
  Append To List    ${inventory}     ${host}
  Set Parallel Value For Key     inventory   ${inventory}
  @{in_deploy}=    Get Parallel Value For Key   ips_in_deploy
  Log To Console    ips_in_deploy ${in_deploy}
  @{new_in_deploy}=  Remove IP From List  ${in_deploy}   ${ip_to_assign}
  Log To Console     new_in_deploy ${in_deploy}
  Set Parallel Value For Key     ips_in_deploy   ${new_in_deploy}
  Release Lock  GetIP
  ${inv_so_far}=    Get Parallel Value For Key   inventory
  Log List    ${inv_so_far}
  Log To Console  "Waiting till VM with IP ${ip_to_assign} is up and connecting "   
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${host}
  Run Playbook On Host  wait-till-vm-connects.yml  inventory=${t_inv}
  Log Dictionary  ${host}  level=INFO
  [Return]    ${host}

Enusure inventory has mysql plugin
  ${inv_so_far}=    Get Parallel Value For Key   inventory
  Log List  ${inv_so_far}  level=INFO

Verify Deletion of Plugin From Orchestrator
  Delete Client If Exists By IP   ${ip}

Uninstall Plugin
  [Arguments]     ${plugin}   ${ip}   ${app}
  # @{keys}=   Get Dictionary Keys  ${plugin}
  # ${ip_address}=  ${keys}[0]
  # Log To Console  ${ip_address}
  # &{dict1}=  Create Dictionary  app_os=${plugin.ip_address.app_os}    proxmox=${plugin.ip_address.proxmox_instance}
  # &{dict2}=  Create Dictionary  ${plugin}   ${dict1}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
    Run Playbook On Host  uninstall-plugin.yml  inventory=${t_inv}
    Delete Plugin From Orchestrator Database   ${ip}
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
    ${extra}=   Create Dictionary     before_reboot=True
    Run Playbook On Host  win-uninstall-plugin.yml  inventory=${t_inv}   extra=${extra}
    Sleep  120s  reason="waiting for Win VM to boot up after uninstalling ASP plugin"
    ${extra}=   Create Dictionary     before_reboot=False
    Run Playbook On Host  win-uninstall-plugin.yml  inventory=${t_inv}   extra=${extra}
  END
  Delete Client If Exists By IP   ${ip}
  
Deploy containers on docker host
  [Arguments]     ${dockerhost_instance}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${dockerhost_instance}
  Log Dictionary  ${t_inv}  level=INFO
  Run Playbook On Host    deploy-docker.yml   inventory=${t_inv}

Verify AppManager Is Running
  [Arguments]     ${plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
    Run Playbook On Host  verify-appmgr-running.yml   inventory=${t_inv}
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
    &{extra}=    Create Dictionary    process_name=AVCDAppManager64
    Run Playbook On Host  win-verify-process-running.yml   inventory=${t_inv}   extra=${extra}
    &{extra}=    Create Dictionary    process_name=AVCDAppMgrService
    Run Playbook On Host  win-verify-process-running.yml   inventory=${t_inv}   extra=${extra}
  END

Get Plugin IP
  [Arguments]     ${plugin}
  @{keys}=   Get Dictionary Keys  ${plugin}
  ${ip_address}=    Set Variable   ${keys}[0]
  Log To Console  ${ip_address}
  [Return]    ${ip_address}

Restart Application On Plugin With Protection Mode
  [Arguments]     ${plugin}   ${service}
  ${ip}=  Get Plugin IP        ${plugin}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    &{extra_options}=    Create Dictionary  service_name=${plugin}[${ip}][app_os][apps][${service}][systemd_service]   process_name=${plugin}[${ip}][app_os][apps][${service}][process_name]
    Log Dictionary  ${extra_options}  level=INFO
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
    Run Playbook On Host  restart-service-protection.yml  inventory=${t_inv}   extra=${extra_options}
  # ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
  #   &{extra}=    Create Dictionary  service_name=${plugin}[${ip}][app_os][apps][${service}][service_name]  service_type=${plugin}[${ip}][app_os][apps][${service}][type]
  #   &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
  #   ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  #   Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
  #   Run Playbook On Host  win-restart-service.yml  inventory=${t_inv}   extra=${extra}
  END
  Sleep  12s  reason="waiting for app status changes"

Restart Application On Plugin
  [Arguments]     ${plugin}   ${service}
  ${ip}=  Get Plugin IP        ${plugin}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    &{extra_options}=    Create Dictionary  service_name=${plugin}[${ip}][app_os][apps][${service}][systemd_service]  process_name=${plugin}[${ip}][app_os][apps][${service}][process_name]
    Log Dictionary  ${extra_options}  level=INFO
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
    Run Playbook On Host  restart-service.yml  inventory=${t_inv}   extra=${extra_options}
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    &{extra}=    Create Dictionary  service_name=${plugin}[${ip}][app_os][apps][${service}][service_name]  service_type=${plugin}[${ip}][app_os][apps][${service}][type]
    &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
    Run Playbook On Host  win-restart-service.yml  inventory=${t_inv}   extra=${extra}
  END
  Sleep  12s  reason="waiting for app status changes"

Configure Warriors On Tomcat
  [Arguments]     ${plugin}   ${mysql_ip}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  &{extra}=   Create Dictionary  TEST_APP=warriors  MYSQL_IP=${mysql_ip}  CONFIG_FILE=${pos.apps.tomcat.warriors.config}
  Run Playbook On Host  config-testapps.yml  inventory=${t_inv}   extra=${extra}

Launch Command On Plugin
  [Arguments]     ${plugin}   ${command}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  # &{service_name}=    Create Dictionary  service_name=${service}
  IF  '${command}' == 'mysql'
    Run Playbook On Host  launch-mysql.yml  inventory=${t_inv}
  END
  Sleep  6s  reason="waiting for app status changes"

Stop Application On Plugin
  [Arguments]     ${plugin}   ${service}
  ${ip}=  Get Plugin IP        ${plugin}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    &{service_name}=    Create Dictionary  service_name=${plugin}[${ip}][app_os][apps][${service}][systemd_service]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
    Run Playbook On Host  stop-service.yml  inventory=${t_inv}   extra=${service_name}
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
    IF  '${service}' == 'mysqld'
      &{process_name}=    Create Dictionary  process_name=${plugin}[${ip}][app_os][apps][${service}][process_name]
      Run Playbook On Host  win-stop-process.yml  inventory=${t_inv}   extra=${process_name}
    ELSE
      &{service_name}=    Create Dictionary  service_name=${plugin}[${ip}][app_os][apps][${service}][service_name]
      Run Playbook On Host  win-stop-service.yml  inventory=${t_inv}   extra=${service_name}
    END
  END
  Sleep  12s  reason="waiting 12s for app status changes"

Verify App Is Discovered On Plugin
  [Arguments]     ${plugin}     ${domain_name}   ${subdomain_name}   ${app_name}
  ${response}=    Get Discovered Apps From Tenancy  ${domain_name}   ${subdomain_name}
  Log Dictionary  ${response}  level=INFO
  Log   ${response}[totalRows] 
  ${apps}=    Get Value From Json   ${response}    $.listApplications[?(@.appName==\'java\')]
  Log List    ${apps}
  ${cnt}=   Get Length  ${apps}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Test Variable  &{plaos}   &{plugin}[${ip}][app_os]
  Log Dictionary  ${plaos}
  Log  ${plaos.apps}[${app_name}]  level=INFO  html=False  console=False  repr=False
  Should Be Equal As Integers  ${cnt}  ${plaos.apps}[${app_name}][processes]

Verify Application Can Be Accessed From Host
  [Arguments]     ${app_name}     ${plugin}     ${host}=remote   ${extra_args}=None
  Log   ${host} 
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Test Variable  &{plaos}   &{plugin}[${ip}][app_os]
  Set Test Variable  ${app}     ${plaos}[apps][${app_name}]
  IF  '${host}' == 'localhost'
    Log   ${host}
    &{dict} =    Create Dictionary    app_os=${plaos}    proxmox_instance=${plugin}[${ip}][proxmox_instance]
    &{host} =    Create Dictionary    localhost=&{dict}
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${host}
    Log Dictionary  ${t_inv}  level=INFO
  END
  Log Dictionary  ${app}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    IF  '${app.type}' == 'web'
      IF  '${extra_args}' == 'warriors'
          &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.warriors.endpoint}
          Run Playbook On Host    access-db-warriors-app.yml    extra=${app_url}  inventory=${t_inv}
      ELSE IF  '${app_name}' == 'tomcat'
        &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.endpoint}
        Run Playbook On Host  access-web-app.yml    extra=${app_url}  inventory=${t_inv}
      END
    END
    IF  '${app.type}' == 'mysqld'
      ${extra}=   Create Dictionary   db_host=${ip}
      Run Playbook On Host  access-mysqld-app.yml   extra=${extra}    inventory=${t_inv}
    END
    IF  '${app.type}' == 'mysql'
      Run Playbook On Host  access-using-mysql-app.yml   extra=${extra_args}    inventory=${t_inv}
    END
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
    IF  '${app.type}' == 'web'
      IF  '${app_name}' == 'tomcat'
        &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.endpoint}
        Run Playbook On Host    win-access-web-app.yml   inventory=${t_inv}  extra=${app_url}
      END
    ELSE IF  '${app.type}' == 'mysql'
      IF  ${extra_args} == ${external_mysql}
        Run Playbook On Host    win-access-using-external-mysql-app.yml   inventory=${t_inv}  extra=${extra_args}
      ELSE
        ${extra}=   Create Dictionary    service=${app}  mysql_server_ip_address=${ip}
        Run Playbook On Host    win-access-using-mysql-app.yml   inventory=${t_inv}  extra=${extra}
      END
    ELSE IF  '${app.type}' == 'mysqld'
      ${extra}=   Create Dictionary    service=${app}  mysql_server_ip_address=${ip}
      Run Playbook On Host    win-access-using-mysql-app.yml   inventory=${t_inv}  extra=${extra}
    END
  END

Verify Application Can NOT Be Accessed From Host
  [Arguments]     ${app_name}     ${plugin}     ${host}=remote   ${extra_args}=None
  Log   ${host} 
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Test Variable  &{plaos}   &{plugin}[${ip}][app_os]
  Set Test Variable  ${app}     ${plaos}[apps][${app_name}]
  IF  '${host}' == 'localhost'
    Log   ${host}
    &{dict} =    Create Dictionary    app_os=${plaos}    proxmox_instance=${plugin}[${ip}][proxmox_instance]
    &{host} =    Create Dictionary    localhost=&{dict}
    Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${host}
    Log Dictionary  ${t_inv}  level=INFO
  END
  Log Dictionary  ${app}
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    IF  '${app.type}' == 'web'
      IF  '${extra_args}' == 'warriors'
          &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.warriors.endpoint}
          Run Playbook On Host  disabled-db-access-warriors-app.yml    extra=${app_url}  inventory=${t_inv}
      ELSE IF  '${app_name}' == 'tomcat'
          &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.endpoint}
          Run Playbook On Host  disabled-access-web-app.yml    extra=${app_url}  inventory=${t_inv}
      END
    END
    IF  '${app.type}' == 'mysqld'
      ${extra}=   Create Dictionary   db_host=${ip}
      Run Playbook On Host  disabled-access-mysqld-app.yml   extra=${extra}    inventory=${t_inv}
    END
    IF  '${app.type}' == 'mysql'
      Run Playbook On Host  disabled-access-using-mysql-app.yml   extra=${extra_args}    inventory=${t_inv}
    END
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
    ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
    Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
    IF  '${app.type}' == 'web'
      IF  '${app_name}' == 'tomcat'
        &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.endpoint}
        Run Playbook On Host    win-disabled-access-web-app.yml   inventory=${t_inv}  extra=${app_url}
      END
    ELSE IF  '${app.type}' == 'mysql'
      ${extra}=   Create Dictionary    service=${app}  mysql_server_ip_address=${ip}
      Run Playbook On Host    win-disabled-access-using-mysql-app.yml   inventory=${t_inv}  extra=${extra}
    ELSE IF  '${app.type}' == 'mysqld'
      ${extra}=   Create Dictionary    service=${app}  mysql_server_ip_address=${ip}
      Run Playbook On Host    win-disabled-access-using-mysql-app.yml   inventory=${t_inv}  extra=${extra}
    END
  END

Delete Plugin From Orchestrator Database
  [Arguments]     ${plugin_ip}
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  &{dict} =    Create Dictionary    orchestrator=${orchestrator}
  Log Dictionary  ${dict}  level=INFO
  &{host} =    Create Dictionary    ${orch_ip}=&{dict}
  # Set To Dictionary  ${host}      app_os=${app_os}    proxmox_instance=${proxmox_instance}
  Log Dictionary  ${host}  level=INFO
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${host}
  Log Dictionary  ${t_inv}  level=INFO
  &{extra}=   Create Dictionary  ip=${plugin_ip}
  Run Playbook On Orchestrator  delete-plugin-from-db.yml   extra=${extra}  inventory=${t_inv}

Ensure that current vm has mysql app
  ${ip}=    Get Plugin IP        ${plugin}
  Dictionary Should Contain Key  ${pos.apps}  mysql  msg="Plugin does not have mysql installed"

Ensure that plugin with mysql is present
  ${mysql_ip}=    Get First Mysql Ip
  Set Test Variable  ${mysql_ip}    ${mysql_ip}
  Should Not Be Empty  ${mysql_ip}  msg="Did not find any plugin with mysqld"
  Acquire Plugin  ${mysql_ip}

Generate SQLi Attack On Mysqld
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Test Variable  &{plaos}   &{plugin}[${ip}][app_os]
  &{dict}=    Create Dictionary    app_os=${plaos}    proxmox_instance=${plugin}[${ip}][proxmox_instance]
  &{host}=    Create Dictionary    localhost=&{dict}
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${host}
  Log Dictionary  ${t_inv}  level=INFO
  IF  '${plugin}[${ip}][app_os][osType]' == 'Linux'
    ${extra}=   Create Dictionary   db_host=${ip}   sql_query=select sleep(10) from mysql.user
    Run Playbook On Host  generate-sqli-attack.yml   extra=${extra}    inventory=${t_inv}
  ELSE IF  '${plugin}[${ip}][app_os][osType]' == 'Windows'
    Set Test Variable  ${app}     &{plugin}[${ip}][app_os][apps]['mysql']
    ${extra}=   Create Dictionary    service=${app}  mysql_server_ip_address=${ip}
    Run Playbook On Host    win-generate-sqli-attack.yml   inventory=${t_inv}  extra=${extra}
  END

Generate XSS Attack On Tomcat
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${ip}=  Get Plugin IP        ${plugin}
  Set Test Variable  &{plaos}   &{plugin}[${ip}][app_os]
  &{dict}=    Create Dictionary    app_os=${plaos}    proxmox_instance=${plugin}[${ip}][proxmox_instance]
  &{host}=    Create Dictionary    localhost=&{dict}
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${host}
  Log Dictionary  ${t_inv}  level=INFO
  Set Test Variable  ${app}     ${plaos}[apps][tomcat]
  &{app_url}=    Create Dictionary  app_url=${app.proto}://${ip}:${app.port}${app.endpoint}
  Run Playbook On Host  generate-xss-attack.yml   extra=${app_url}  inventory=${t_inv}

Record Attacks So Far
  # ${pre}=   Get Dashboard Threats Summary
  ${pre_dom}=   Get Threats For Domain  ${pos.av_domain}_${dash_ip}
  # Log  Total Threats Before Attack ${pre}
  Log  Threats On Domain Before Attack ${pre_dom}
  # Set Test Variable  ${pre}  ${pre}
  Set Test Variable  ${pre_dom}  ${pre_dom}

Verify That Attack Count Has Increased
  FOR  ${index}  IN RANGE  10
    Sleep  15s  reason=Waiting 10s for attack to be reported
    ${status}	 ${value}=  Run Keyword And Ignore Error  Verify Attack Count
    IF  '${status}'=='PASS'
      Pass Execution  Attack Counts Increased
      Return From Keyword
    END
  END
  Fail  msg=Attck counts did not increased even after 150s

Verify Attack Count
  # ${after}=   Get Dashboard Threats Summary
  ${after_dom}=   Get Threats For Domain  ${pos.av_domain}_${dash_ip}
  # Log  Total Threats After Attack ${after}
  Log  Threats On Domain After Attack ${after_dom}
  # ${diff}=  Evaluate  ${after}-${pre}
  # Should Be True  ${diff} > 0  msg=Dashboard Attack Count Difference is not more than 0
  ${diff}=  Evaluate  ${after_dom}-${pre_dom}
  Should Be True  ${diff} > 0  msg=Attack Count Difference for specific domain not more than 0

Suspend Policies
  [Arguments]     ${asp_pol}   ${pcre_pol}
  Log   Suspending ASP Policy
  Suspend Policy And Verify   ${asp_pol}
  Log   Suspending PCRE Policies
  Suspend Pcre Policy And Verify   ${pcre_pol}

Verify That Tomcat Can Be Accessed
  ${status}	  ${value}=   Run Keyword And Ignore Error   Verify Application Can Be Accessed From Host  tomcat        ${plugin}    localhost
  IF  '${status}'=='PASS'
    Return From Keyword
  ELSE
    Restart Application On Plugin   ${plugin}     tomcat
    Sleep  5s  Retrying to access tomcat after restart 
    Verify Application Can Be Accessed From Host  tomcat        ${plugin}    localhost
  END

Copy ASP Plugin Installation File
  [Arguments]      ${plugin}
  Log To Console    ${\n}Inside Copy ASP Plugin Installation File keyword  stream=STDOUT  no_newline=False
  ${ip}=  Get Plugin IP        ${plugin}
  &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
  ${extra}=   Create Dictionary    src_path=/tmp/setup_2.5.0.9.exe
  Run Playbook On Host    win-copy-plugin-installation-file.yml   inventory=${t_inv}  extra=${extra}

Install ASP Plugin From Installation File
  [Arguments]      ${plugin}    ${secrets}
  Log To Console    ${\n}Inside Install ASP Plugin From Installation File  stream=STDOUT  no_newline=False
  ${ip}=  Get Plugin IP        ${plugin}
  &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
  ${secrets_dict}    evaluate  json.loads($secrets)    json
  ${extra}=   Create Dictionary    orch_ip=${orch_ip}  secrets=${secrets_dict}
  Log To Console    Started to install ASP plugin on Win VM, once installation is complete, Win VM will be rebooted, it might take up to 3min to wait for it to re-appear  stream=STDOUT  no_newline=False
  Run Playbook On Host    win-install-plugin.yml   inventory=${t_inv}  extra=${extra}

Start Desktop Application on Plugin
  [Arguments]      ${plugin}    ${application}
  Log To Console    ${\n}Inside Start Desktop Application on Windows Plugin  stream=STDOUT  no_newline=False
  ${ip}=  Get Plugin IP        ${plugin}
  &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
  &{extra}=    Create Dictionary  app=${plugin}[${ip}][app_os][apps][${application}]
  IF  '${application}' == 'spring_boot'
    Run Playbook On Host    win-start-detached-application.yml   inventory=${t_inv}  extra=${extra}
    Sleep  30s  reason=Waiting 30s for java startup to complete
  ELSE IF  '${application}' == 'ms_profiler'
    Run Playbook On Host    win-start-detached-application.yml   inventory=${t_inv}  extra=${extra}
    Sleep  10s  reason=Waiting 10s for ms_profiler to start
  ELSE
    Run Playbook On Host    win-start-application.yml   inventory=${t_inv}  extra=${extra}
    Sleep  5s  reason=Waiting 5s for Windows application to start
  END

Stop Desktop Application on Plugin
  [Arguments]      ${plugin}    ${application}
  Log To Console    ${\n}Inside Start Desktop Application on Windows Plugin  stream=STDOUT  no_newline=False
  ${ip}=  Get Plugin IP        ${plugin}
  &{dict1}=  Create Dictionary    ${ip}=${plugin}[${ip}][app_os]
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary   ${t_inv.all.children.ungrouped}    hosts=${dict1}
  IF  '${plugin}[${ip}][app_os][apps][${application}][process_name]' == 'java'
    &{extra}=    Create Dictionary  process_name=${plugin}[${ip}][app_os][apps][${application}][process_name]
    Run Playbook On Host    win-stop-process.yml   inventory=${t_inv}  extra=${extra}
  ELSE
    &{extra}=    Create Dictionary  app=${plugin}[${ip}][app_os][apps][${application}]
    Run Playbook On Host    win-stop-application.yml   inventory=${t_inv}  extra=${extra}
  END

Kill All Apt On Ubuntu
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  Run Playbook On Host   ensure-apt-not-running.yml    inventory=${t_inv} 

Suspend MySQL PCRE
  Release Locks
  Suspend Policies   NS_mysqld_${ip}   PCRE2_SQLi_${ip}

Suspend Tomcat PCRE
  Release Locks
  Suspend Policies   NS_tomcat_${ip}   PCRE1_XSS_${ip}

Upload Plugin Package
  ${BUILD_NO}=    Get Parallel Value For Key   ${pos.plugin_installer_dir}_build_num
  Log   Uploading plugin package # ${BUILD_NO}
  Upload Package  ${pos.osType}   ${pos.osName}   ${pos.osVersion}   pluginpackage/${BUILD_NO}/${pos.plugin_installer_dir}

Refresh Subsription Manager on RHEL8
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  Run Playbook On Host   refresh-subsription-rhel8.yml    inventory=${t_inv} 

Enable Debug And Trace Log for ADPL amd AppMgr
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  Run Playbook On Host   enable-trace-log.yml    inventory=${t_inv} 

Run Manual Installer Using install_adpl.sh Script
  [Arguments]      ${secrets}
  ${BUILD_NO}=    Get Parallel Value For Key   ${pos.plugin_installer_dir}_build_num
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${secrets_dict}=    evaluate  json.loads($secrets)    json
  ${installer}=   Get Installer Name   ${EXECDIR}/pluginpackage/${BUILD_NO}/${pos.plugin_installer_dir}/
  ${extra}=   Create Dictionary    orch_ip=${orch_ip}    secrets=${secrets_dict}   installer_dir=${EXECDIR}/pluginpackage/${BUILD_NO}/${pos.plugin_installer_dir}/    installer=${installer}
  Run Playbook On Host   manual-install-using-script.yml   extra=${extra}    inventory=${t_inv}


Run Manual Installer Using avocado_config.sample
  [Arguments]      ${secrets}
  ${BUILD_NO}=    Get Parallel Value For Key   ${pos.plugin_installer_dir}_build_num
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  ${secrets_dict}=    evaluate  json.loads($secrets)    json
  ${installer}=   Get Installer Name   ${EXECDIR}/pluginpackage/${BUILD_NO}/${pos.plugin_installer_dir}/
  ${extra}=   Create Dictionary    orch_ip=${orch_ip}    secrets=${secrets_dict}   installer_dir=${EXECDIR}/pluginpackage/${BUILD_NO}/${pos.plugin_installer_dir}/    installer=${installer}
  Run Playbook On Host   manual-install-using-config.yml   extra=${extra}    inventory=${t_inv}

Whitelist All Python Applications
  ${t_inv}=  Copy Dictionary    ${inv}    deepcopy=true
  Set To Dictionary  ${t_inv.all.children.ungrouped}    hosts=${plugin}
  Run Playbook On Host   whitelist-python.yml   inventory=${t_inv}

Verify Plugin Is Shown As Active On Orchestrator
  Verify Plugin Status    ${True}