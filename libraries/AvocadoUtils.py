import os
import requests
import yaml
import json
import time
import jmespath
from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn
from pabot.pabotlib import PabotLib as pl

ROBOT_LIBRARY_DOC_FORMAT = 'reST'
ROBOT_LIBRARY_SCOPE = 'GLOBAL'


def set_proxmox_ip_list(proxmox, ip_list):
  proxmox['vm_ips'] = ip_list

def get_unused_ip(inventory, proxmox, in_deploy):
    """Collecting unused ip addresses.

  - ``inventory`` argument.
  - ``proxmox`` argument.
  - ``in_deploy`` argument.

  Examples:
  | ${result} = | Get Unused Ip | 100    |  192.168.100.15  |    |

  """
    logger.info('proxmox = %s' % str(proxmox))
    logger.info('Length of invetory = %d' % len(inventory))
    logger.info('Inventory = {}'.format(inventory))
    logger.info('in deploy ips = {}'.format(in_deploy))
    if proxmox != 'NOT FOUND' and proxmox['vm_ip'] == 'static':
        available_ips = proxmox['vm_ips']
        logger.info('available_ips = {}'.format(available_ips))
        available_ips = list(set(available_ips) - set(in_deploy))
        logger.info('available_ips now = {}'.format(available_ips))
        available_ips.sort()
        logger.info('available_ips now = {}'.format(available_ips))
        used_ips = []
        for plugin in inventory:
            logger.info('Plugin = {}'.format(plugin))
            for ip in plugin.keys():
                used_ips.append(ip)
    logger.info('Used IP = {}'.format(used_ips))
    for available_ip in available_ips:
        if available_ip not in used_ips:
            logger.info('Found unused ip {}'.format(available_ip))
            return available_ip
    return 'NOT FOUND'


def get_dash_ip(ip):
    """Replacing dots ``.`` in ip addresses to dashes ``-``.

  - ``ip`` argument.



  Examples:
  | ${result} = | Get Dash Ip | 192.168.100.15 |
  =>
  | ${result} = 192-168-100-15

  """
    return ip.replace('.', '-')


def get_dash_name(app_os_name):
    """Replacing underscore ``_`` in app os name to dashes ``-``.
  And adding -instance cnt at the end of returned string

  - ``app_os_name`` argument.

  Examples:
  | ${result} = | Get Dash Name | example_app_name    |
  =>
  | ${result} = example-app-name-cnt

  """
    pli = _get_pabot_library_instance()
    instance_cnt = pli.get_parallel_value_for_key('instance_cnt')
    if app_os_name in instance_cnt.keys():
        instance_cnt[app_os_name] = instance_cnt[app_os_name] + 1
    else:
        instance_cnt[app_os_name] = 1
    cnt = instance_cnt[app_os_name]
    pli.set_parallel_value_for_key('instance_cnt', instance_cnt)
    instance_cnt = pli.get_parallel_value_for_key('instance_cnt')
    logger.info("instance_cnt = %s" % str(instance_cnt))
    return app_os_name.replace('_', '-') + '-' + str(cnt)


def get_vm_id_to_assign(vmid, proxmox_ip):
    """Collecting vm id to be addigned

  - ``vmid`` argument.
  - ``proxmox_ip`` argument.

  Examples:
  | ${result} = | Get Vm Id To Assign | 100  |  192.168.100.15  |
  =>
  | ${result} = 102
  """
    newid = int(vmid)
    vmid_list = []
    with open('/tmp/%s/tmp/vmList.txt' % proxmox_ip) as f:
        vmid_list = [int(line.strip()) for line in f]
    logger.info("vmid_list = %s" % str(vmid_list))
    newid += 1
    while newid in vmid_list:
        newid += 1
        if newid in vmid_list:
            newid += 1
    pli = _get_pabot_library_instance()
    pli.set_parallel_value_for_key('newid', str(newid))
    logger.info("setting newid = %s" % str(newid))
    return newid

def get_installer_name(installer_dir):
  """Get name of either the first rpm or deb file present in installer_dir

    - ``installer_dir`` argument.

    Examples:
    | ${result} = | Get Installer Dir     |  installer_dir  |
    =>
    | ${result} = [*.deb]
  """
  insaller = None
  for filename in os.listdir(installer_dir):
    f = os.path.join(installer_dir, filename)
    # checking if it is a file
    if os.path.isfile(f):
      logger.info("file name in installer_dir = %s" % filename)
      if '.deb' in filename or '.rpm' in filename:
        logger.info("found installer = %s" % filename)
        return filename
  BuiltIn().should_not_be_empty(insaller,'no .deb or .rpm file found in %s' % installer_dir)


def remove_ip_from_list(ip_list, ip):
  """Deleting ip addresses from provided ip list

  - ``ip_list`` argument.
  - ``ip`` argument.

  Examples:
  | ${result} = | Remove Ip From List | [192.168.100.15, 192.168.100.12]    |  192.168.100.15  |
  =>
  | ${result} = [192.168.100.12]
  """
  if not ip_list:
      if ip in ip_list:
          ip_list.remove(ip)
  return ip_list


def get_first_mysql_ip():
  """Collecting unused ip addresses. Method is getting available IP from inventory
    and returning

    Examples:
    | ${result} = | Get First Mysql Ip |
    =>
    | ${result} = 192.168.100.12
  """
  pli = BuiltIn().get_library_instance('pabot.PabotLib')
  pos = BuiltIn().get_variable_value('${pos}')
  BuiltIn().should_not_be_empty(pos,'Unable to find variable pos')
  platform = pos['osType']
  os = pos['osName']
  osver = pos['osVersion']
  inventory = pli.get_parallel_value_for_key('inventory')
  logger.info(inventory)
  for item in inventory:
    for k in item.keys():
      inv_os_type = item[k]['app_os']['osType']
      inv_os = item[k]['app_os']['osName']
      inv_os_ver = item[k]['app_os']['osVersion']
      apps = item[k]['app_os']['apps']
      if inv_os_type == platform and inv_os == os and inv_os_ver == osver:
        for app in apps:
          if app == 'mysqld' and 'in_use' not in app:
            logger.info("Found plugin with exact match mysql %s" % k)
            apps[app]['in_use'] = True
            pli.set_parallel_value_for_key('inventory', inventory)
            return k
  for item in inventory:
    for k in item.keys():
      inv_os_type = item[k]['app_os']['osType']
      inv_os = item[k]['app_os']['osName']
      apps = item[k]['app_os']['apps']
      if inv_os_type == platform and inv_os == os:
        for app in apps:
          if app == 'mysqld' and 'in_use' not in app:
            logger.warn("Found plugin only with matching osType and osName %s" % k)
            apps[app]['in_use'] = True
            pli.set_parallel_value_for_key('inventory', inventory)
            return k
  for item in inventory:
    for k in item.keys():
      inv_os_type = item[k]['app_os']['osType']
      inv_os = item[k]['app_os']['osName']
      if inv_os_type == platform:
        for app in apps:
          if app == 'mysqld' and 'in_use' not in app:
            logger.warn("Found plugin only with matching osType %s" % k)
            apps[app]['in_use'] = True
            pli.set_parallel_value_for_key('inventory', inventory)
            return k
  BuiltIn().should_be_equal(1,0,'Unable to find plugin with mysql')

def fetch_plugin_from_inventory_by_ip(ip):
    """Fetching ip addresses. Script is matching plugin if with IP stored in inventory.

  - ``ip`` argument.

  Examples:
  | ${result} = | Fetch Plugin From Inventory By Ip |   192.168.100.15 |
  =>
  | ${result} = plugin?
    """

    inventory = _loading_pabot_invetory()
    logger.info(inventory)
    for plugin in inventory:
        for k in plugin.keys():
            if k == ip:
                logger.info("found %s in inventory %s" % (ip, str(plugin[k])))
                return plugin

def _loading_pabot_invetory():
    pli = _get_pabot_library_instance()
    inventory = pli.get_parallel_value_for_key('inventory')
    return inventory


def _get_pabot_library_instance():
    pli = BuiltIn().get_library_instance('pabot.PabotLib')
    return pli
