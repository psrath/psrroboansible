from hashlib import sha1
import os, glob
import time
import yaml
import ansible_runner
import jmespath
import fileinput
import random
import string
import logging
import shutil
from robot.libraries.BuiltIn import BuiltIn
from robot.api import logger
from random import randint
from time import sleep

DEFULT_SLEEP_INTERVAL = 0.5


class AvocadoAnsibleRunner:
    __version__ = '0.1'
    ROBOT_LIBRARY_DOC_FORMAT = 'reST'
    conf = yaml.safe_load(open('config/test-data.yaml', 'r'))
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'

    def run_playbook(self, playbook, extra=None, inventory=None):
        """Triggering ansible playbook.

        - ``playbook`` argument.
        - ``extra``  argument.
        - ``inventory``  argument.

      Examples:
      | ${result} = | Run Playbook |  playbook.yml |  extra={app_url=http://192.168.102.204:8080/} | inventory={'all': {'children': {'ungrouped': {'hosts': None}}}} |
      =>
      | ${result} = status=successful: return code=0
      """
        logger.info(" given inventory  = %s" % str(inventory))
        logger.info(os.getcwd())
        with open('ansible_runner/inventory/hosts.yml', 'w') as f:
            yaml.dump(inventory, f, allow_unicode=True, default_flow_style=False)
        r = ansible_runner.run(private_data_dir='ansible_runner', playbook=playbook, extravars=extra)
        logger.info("*INFO:{}* {}: {}".format(time.time() * 1000, r.status, r.rc))
        BuiltIn().should_be_equal_as_integers(r.rc, 0, "Playbook execution failed")

    def generate_inventory_yml(self, inventory, playbook):
        """Generating temporary private data directories for projects,
        inventory, scripts and playbooks

        - ``inventory``  argument.
        - ``playbook`` argument.

      Examples:
      | Generate Inventory Yml | {'all': {'children': {'ungrouped': {'hosts': None}}}} |  playbook.yml |

      """
        suffix = str(''.join(random.choices(string.ascii_lowercase, k=15)))
        logger.info('Random Suffix generated = %s' % suffix)
        if not os.path.exists('private_data_dir'):
            os.makedirs('private_data_dir')
        if not os.path.exists('private_data_dir/' + suffix):
            os.makedirs('private_data_dir/' + suffix)
        if not os.path.exists('private_data_dir/' + suffix + '/project'):
            os.makedirs('private_data_dir/' + suffix + '/project')

        private_data_dir = 'ansible_runner/private_data_dir/' + suffix
        inv_file = 'ansible_runner/private_data_dir/' + suffix + '/inventory/hosts.yml'
        shutil.copytree('ansible_runner/env', private_data_dir + '/env')
        shutil.copytree('ansible_runner/inventory', private_data_dir + '/inventory')
        shutil.copytree('ansible_runner/project/scripts', private_data_dir + '/project/scripts')
        shutil.copyfile('ansible_runner/project/' + playbook, private_data_dir + '/project/' + playbook)
        with open(inv_file, 'w') as f:
            yaml.dump(inventory, f, allow_unicode=True, default_flow_style=False)
        with fileinput.FileInput(inv_file, inplace=True, backup='') as file:
          for line in file:
            if '!!python/object/apply:robot.utils.dotdict.DotDict' in line :
              print(line.replace('!!python/object/apply:robot.utils.dotdict.DotDict',''), end='')
            else:
              print(line,end='')
        with fileinput.FileInput(inv_file, inplace=True, backup='') as file:
          for line in file:
            if 'dictitems:' in line :
              print(line.replace('dictitems:',''), end='')
            else:
              print(line,end='')
        return private_data_dir

    def run_playbook_on_host(self, playbook, extra=None, inventory=None):
        """Triggering ansible playbook on host machines.

        - ``playbook`` argument.
        - ``extra``  argument.
        - ``inventory``  argument.

      Examples:
      | ${result} = | Run Playbook |  playbook.yml |  extra={app_url=http://192.168.102.204:8080/} | inventory={'all': {'children': {'ungrouped': {'hosts': None}}}} |
      =>
      | ${result} = status=successful: return code=0
      """
        sleep(randint(1, 10))
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(inventory)))
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(extra)))
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, type(extra)))
        dir = os.getcwd() + '/ansible_runner/inventory'
        for file in os.scandir(dir):
            if 'hosts.yml' in file.path:
                logging.info('Deleting %s' % file.path)
                os.remove(file.path)
        allHosts = inventory['all']['children']['ungrouped']['hosts']
        host = list(allHosts.keys())[0]
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(host)))
        attrs = allHosts[host]
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(attrs)))
        attrs['ansible_host'] = host
        if (str(host) != 'localhost'):
            if 'app_os' in allHosts[host].keys():
                for key in allHosts[host]['app_os'].keys():
                    if (key.startswith('ansible')):
                        attrs[key] = allHosts[host]['app_os'][key]
        else:
            attrs['ansible_connection'] = 'local'
        private_data_dir = self.generate_inventory_yml(inventory, playbook)
        logger.info('inventory file path = %s' % private_data_dir)
        logger.info("*INFO:{}* {}".format(time.time() * 1000, str(inventory)))
        r = ansible_runner.run(private_data_dir=private_data_dir, playbook=playbook, extravars=extra)
        logger.info("*INFO:{}* status={}: return code={}".format(time.time() * 1000, r.status, r.rc))
        BuiltIn().should_be_equal_as_integers(r.rc, 0, "Playbook execution failed")

    def run_playbook_on_proxmox(self, playbook, extra=None, inventory=None):
        """Triggering ansible playbook on proxmox.

        - ``playbook`` argument.
        - ``extra``  argument.
        - ``inventory``  argument.

      Examples:
      | ${result} = | Run Playbook |  playbook.yml |  extra={app_url=http://192.168.102.204:8080/} | inventory={'all': {'children': {'ungrouped': {"proxmox": {	"host": "192.168.101.16"}}}} |
      =>
      | ${result} = status=successful: return code=0
      """
        sleep(randint(1, 5))
        # print("inside run_playbook_on_proxmox", html=True, also_console=True)
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(inventory)))
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(extra)))
        dir = os.getcwd() + '/ansible_runner/inventory'
        for file in os.scandir(dir):
            if 'hosts.yml' in file.path:
                logging.info('Deleting %s' % file.path)
                os.remove(file.path)
        allHosts = inventory['all']['children']['ungrouped']['hosts']
        host = list(allHosts.keys())[0]
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(host)))
        attrs = allHosts[host]
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(attrs)))
        attrs['ansible_host'] = host
        for key in allHosts[host]['proxmox'].keys():
            if (key.startswith('ansible')):
                attrs[key] = allHosts[host]['proxmox'][key]
        private_data_dir = self.generate_inventory_yml(inventory, playbook)
        logger.info("*INFO:{}* {}".format(time.time() * 1000, str(inventory)))
        r = ansible_runner.run(private_data_dir=private_data_dir, playbook=playbook, extravars=extra)
        logger.info("*INFO:{}* status={}: return code={}".format(time.time() * 1000, r.status, r.rc))
        BuiltIn().should_be_equal_as_integers(r.rc, 0, "Playbook execution failed")

    def run_playbook_on_orchestrator(self, playbook, extra=None, inventory=None):
        """Triggering ansible playbook on orchestrator.
      Examples:
      | ${result} = | Run Playbook |  playbook.yml |  extra={app_url=http://192.168.102.204:8080/} | inventory={'all': {'children': {'ungrouped': {'hosts': None}}}} |
      =>
      | ${result} = status=successful: return code=0
      """
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(inventory)))
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(extra)))
        dir = os.getcwd() + '/ansible_runner/inventory'
        for file in os.scandir(dir):
            if 'hosts.yml' in file.path:
                logging.info('Deleting %s' % file.path)
                os.remove(file.path)
        allHosts = inventory['all']['children']['ungrouped']['hosts']
        host = list(allHosts.keys())[0]
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(host)))
        attrs = allHosts[host]
        logger.info("*DEBUG:{}* {}".format(time.time() * 1000, str(attrs)))
        attrs['ansible_host'] = host
        for key in allHosts[host]['orchestrator'].keys():
            if (key.startswith('ansible')):
                attrs[key] = allHosts[host]['orchestrator'][key]
        private_data_dir = self.generate_inventory_yml(inventory, playbook)
        logger.info("*INFO:{}* {}".format(time.time() * 1000, str(inventory)))
        r = ansible_runner.run(private_data_dir=private_data_dir, playbook=playbook, extravars=extra)
        logger.info("*INFO:{}* status={}: return code={}".format(time.time() * 1000, r.status, r.rc))
        BuiltIn().should_be_equal_as_integers(r.rc, 0, "Playbook execution failed")


    def get_vm_ip(self, json, os_type, ip_to_assign):
        """ Retrieving  ip addresses from two os type Windows and Linux
    
         - ``json`` argument.
         - ``os_type``  argument.
         - ``ip_to_assign``  argument.
    
       Examples:
       | ${result} = | Get Vm Ip | proxmox_instance_host.json | Windows |
       | ${result} = | Get Vm Ip | proxmox_instance_host.json | Linux |
       =>
       | ${result} = 192.168.100.12
         """
        if os_type == 'Linux':
            sub = jmespath.search('@[?name == \'eth0\'] | [0]."ip-addresses"', json)
            ip = jmespath.search('@[?"ip-address-type" == \'ipv4\'] | [0]."ip-address"', sub)
        elif os_type == 'Windows':
            sub = jmespath.search('[0]."ip-addresses"', json)
            ip_addresses = []
            for ip_address in sub:
                ip_addresses.append(jmespath.search('"ip-address"', ip_address))
            if ip_to_assign in ip_addresses:
                ip = ip_to_assign
            else:
                ip = ip_addresses[0]
        return ip

# def event_handler(self, data):
#   return True

# def status_handler(self, data):
#   print("came here in status handler")
#   return True

if __name__ == "__main__":
    ansibleClient = AvocadoAnsibleRunner()
    # ansibleClient.run_playbook('deploy-vm.yml', extra={"app_os": "tomcat9_centos84", "proxmox": "proxmox15"})
    # dict = {"192.168.100.149": {
    #   "app_os": "tomcat9_centos84", "proxmox": "proxmox15", "ansible_ssh_host": "192.168.100.149",
    #   "ansible_user": "avocado",
    #   "ansible_ssh_private_key_file": "../env/ssh_keys/key-connect-to-proxmox15"
    # }}
    ansibleClient.run_playbook_test('test-playbook.yml', extra={"service_name": "tomcat"}, inventory="192.168.100.149")
