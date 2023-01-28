*** Variables ***
${hostname}   192.168.100.178
# without sudo
#${ansible_password}  root_password
# with sudo
${ansible_user}             avocado
${ansible_become_password}  Avocado@2020
${default_container_image}  ubuntu
${default_container_command}  '["sleep", "1d"]'
${default_proxmox_node}     192.168.100.15
${proxmox_password}         Avcd@95135
${proxmox_api_user}         root@pam
${proxmox_node_name}        pve-02
${VM_name}      robot-centos84
${VM_template}  template-centos84

*** Settings ***
library  Impansible
library  Collections
library  OperatingSystem
#Force Tags      smoke
#Default Tags    sanity    smoke

*** Test Cases ***
Setup docker containers
[Tags]  sanity
  ${x}=   Setup  ${hostname}
  ${y}=   get from dictionary  ${x}   ansible_facts
  Log to console  ${x}
  yum   ${hostname}   name=yum-utils                        state=latest
  yum   ${hostname}   name=python3-virtualenv               state=latest
  yum   ${hostname}   name=python3-setuptools               state=latest
  yum   ${hostname}   name=device-mapper-persistent-data    state=latest
  yum   ${hostname}   name=lvm2                             state=latest
  get_url   ${hostname}  url=https://download.docker.com/linux/centos/docker-ce.repo  dest=/etc/yum.repos.d/docer-ce.repo
  ini_file  ${hostname}  dest=/etc/yum.repos.d/docer-ce.repo  section='docker-ce-edge'  option=enabled  value=0
  ini_file  ${hostname}  dest=/etc/yum.repos.d/docer-ce.repo  section='docker-ce-test'  option=enabled  value=0
  package   ${hostname}  name=docker-ce   state=latest
  service   ${hostname}   name=docker     state=started   enabled=yes
  user      ${hostname}   name=avocado  groups=docker   append=yes
  pip       ${hostname}   name=docker
  ${z}=   docker_image    ${hostname}   name=${default_container_image}   source=pull
  Log to console  ${z}
  docker_container    ${hostname}   name=${default_container_image}   image=${default_container_image}   image=${default_container_image}   state=present

Cloning virtual machine from ${VM_template} with name ${VM_name} 
  # [Tags]    smoke
  ${ansible_user}=    Set Variable    root
  ${ansible_become_password}=     Set Variable    Avcd@95135
  ${x}=   Setup  ${default_proxmox_node}
  ${y}=   get from dictionary  ${x}   ansible_facts
  Log to console  ${x}
  proxmox_kvm   ${default_proxmox_node}   api_user=${proxmox_api_user}   api_password=${proxmox_password}   api_host=${default_proxmox_node}   name=${VM_name}   node=${proxmox_node_name}   clone=${VM_template}        timeout="300"

Get current state of vm
  # [Tags]    smoke
  ${ansible_user}=    Set Variable    root
  ${ansible_become_password}=     Set Variable    Avcd@95135
  ${x}=   Setup  ${default_proxmox_node}
  ${y}=   get from dictionary  ${x}   ansible_facts
  ${state}=   proxmox_kvm   ${default_proxmox_node}   api_user=${proxmox_api_user}   api_password=${proxmox_password}   api_host=${default_proxmox_node}   name=${VM_name}   node=${proxmox_node_name}   state=current
  Log to console  ${state}

Turn on VM_name and get IP address
  [Tags]    smoke
  ${ansible_user}=    Set Variable    root
  ${ansible_become_password}=     Set Variable    Avcd@95135
  ${x}=   Setup  ${default_proxmox_node}
  ${y}=   get from dictionary  ${x}   ansible_facts
  ${state}=   proxmox_kvm   ${default_proxmox_node}   api_user=${proxmox_api_user}   api_password=${proxmox_password}   api_host=${default_proxmox_node}   name=${VM_name}   node=${proxmox_node_name}   state=started    timeout="300"
  Log to console  ${state}
  ${vmid}=    Get From Dictionary  ${state}   msg
  Log To Console  ${vmid}
  ${facts}=    Get From Dictionary  ${state}   ansible_facts
  Log To Console  ${facts}
