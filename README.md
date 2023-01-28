# Avocado Test Automation

## Test Framework overview
Main components of Avocado Test Automation framework:
* Robot Framework - https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html
* Python - https://docs.python.org/3.7/library/
* Ansible - https://docs.ansible.com/ansible/latest/index.html
* pabot - https://pabot.org/PabotLib.html

## Test Environment configuration

Automated tests should be executed on a Linux VM (script runner machine) residing on the same Proxmox VE server that is used for provisioning Linux/Windows VMs under test. The script runner machine communicates with Proxmox VE API using proxmoxer requests.

Supported Linux OSes fot the script runner machine are:
* CentOS 7
* RHEL 7.9

## Description Avocado Test Automation project structure

* **ansible_runner** – ansible project containing Ansible Playbooks for interacting with Windows/Linux Virtual Machines and Proxmox VE
* **config** – .json files with Web Services Request-Response patterns for interacting with Orchestrator
* **keywords** – .robot files with implementation of custom robot framework keywords
* **libraries** – Python files used by Avocado Test Automation framework for orchestrating test execution and interacting with Orchestrator
* **rules** – various files defining rules used in some tests
* **suites** – .robot test suites for ASP
* **variables** – detailed configuration files e.g. for VMs, applications running on VMs, Proxmox VE servers
* **requirements.txt** - set of packages that Avocado Test Automation framework depends on

## Prerequisites for script runner CentOS 7 / RHEL 7.9 VMs

```bash
sudo yum install -y git
sudo yum install -y wget
sudo yum install -y gcc openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel
cd /usr/src  
sudo wget https://www.python.org/ftp/python/3.7.11/Python-3.7.11.tgz
sudo tar xzf Python-3.7.11.tgz 
cd Python-3.7.11 
sudo ./configure --enable-optimizations 
sudo make altinstall 
```

## Creating Python Virtual Environment and installing requirements

The first step is to verify if Python has been successfully installed: 
```bash
python3.7 --version 
pip3.7 --version
```
Expected version of Python is Python 3.7.11. Expected version of pip is pip 20.1.1. 

Note: Newer versions of Python 3.x and pip are also compatible with Avocado Test Framework.

The next step is to check out git repository if it has not been done yet:
```bash
git clone http://192.168.100.19:8008/avocado/testautomation.git
cd testautomation
```

The last step is to create Python Virtual Environment, export Python libraries, install requirements and change access permissions to ssh_keys:
```bash
python3.7 -m venv myvenv
source myvenv/bin/activate
export PYTHONPATH=$PYTHONPATH:.:./libraries
pip install -r requirements.txt
chmod 400 ansible_runner/env/ssh_keys/*
```

## Running Automated Tests 

### Running tests on a single VM under test

Make sure you are inside the previously created Python Virtual Environment and run the following command:

```bash
app_os="w12s16t9"
prefix="test"
proxmox_ve="proxmox16"
orch_ip="192.168.102.226"
python -m robot.run --variable APP_OS:$app_os --variable PROXMOX:$proxmox_ve --variable orch_ip:${orch_ip} --variable PREFIX:$prefix --outputdir reports suites/windows-tests.robot
```

The above command will execute `windows-tests.robot` test suite on the following units under tests:
*  Orchestrator instance `https://192.168.102.226:8443/orchestrator`
* `test-w12s16t9-1` VM residing on `proxmox16` Proxmox VE server

Note:`$app_os` parameter must match the name of one of the VM configs defined in `variables/common.yml`. `$proxmox_ve` parameter must match the name of one of the Proxmox VE configs defined in `variables/common.yml`. All config details for `win2016` and `proxmox16` will be retrieved from `variables/common.yml`.

To download test execution logs to your local machine, replace `username`  and `linux_vm_ip_addr` with the actual username and IP address of the script runner machine and run the following command:
```bash
scp username@linux_vm_ip_addr:~/testautomation/reports/* .
```

### Running tests on multiple VMs under test in parallel

Create an arg file for each VM to be tested. The below are examples of `arg1.txt` and `arg2.txt` files contents for `win2012` and `win2016` VMs residing on `proxmox16` Proxmox VE server:
```bash
$ cat arg1.txt
--variable APP_OS:w12s16t9
--variable PROXMOX:proxmox16
```
```bash
$ cat arg2.txt
--variable APP_OS:w16s12t8
--variable PROXMOX:proxmox16
```

Make sure you are inside the previously created Python Virtual Environment and run the following command:

```bash
pabot --verbose --pabotlib --argumentfile1 arg1.txt  --argumentfile2 arg2.txt --variable orch_ip:${orch_ip} --variable PREFIX:test --outputdir reports suites/windows-tests.robot
```

The above command will execute `windows-tests.robot` test suite in parallel on `test-w12s16t9-1` and `test-w16s12t8-1` VMs and Orchestrator instance `orch_ip`.