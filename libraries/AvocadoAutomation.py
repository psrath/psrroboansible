import os
import requests
import yaml
import json
import time
import jmespath
import base64
import re
from datetime import datetime, timedelta
from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn

from requests.packages.urllib3.exceptions import InsecureRequestWarning

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

DEFULT_SLEEP_INTERVAL = 0.5

tokens = {'administrator': {'auth': 'Basic YW5ndWxhci11aTphbmd1bGFyLXNlY3JldA=='} ,'manoj': {'auth': 'Basic YW5ndWxhci11aTphbmd1bGFyLXNlY3JldA=='}, 'andrzej': {'auth': 'Basic YW5ndWxhci11aTphbmd1bGFyLXNlY3JldA=='},'sankalp': {'auth': 'Basic YW5ndWxhci11aTphbmd1bGFyLXNlY3JldA=='}}

class AvocadoAutomation:
  __version__ = '0.1'
  ROBOT_LIBRARY_DOC_FORMAT = 'reST'
  # conf = yaml.safe_load(open('config/test-data.yaml', 'r'))
  session = requests.Session()
  ROBOT_LIBRARY_SCOPE = 'GLOBAL'
  create_pol = None
  access_token = ''
  
  def __init__(self, orch_ip=None) -> None:
    self.readJsons()
    self.orch_ip = orch_ip
    if self.orch_ip:
      global base_url, user_name, password, auth
      base_url = 'https://%s:8443/orchestrator' % orch_ip
      user_name =  'administrator'
      password = 'Avocado_protect@20'
      auth = 'Basic YW5ndWxhci11aTphbmd1bGFyLXNlY3JldA=='
    else:
      self.set_environment()
    # self.login_into_orchestrator()
    # self.action = self.get_actions()
    # self.subActions = self.get_sub_actions()
    self.clientSecrets = {}

  def readJsons(self):
    with open("config/createPolicy.json", encoding = 'utf-8') as f:
      self.create_pol = json.load(f)
    with open("config/schedulePolicy.json", encoding = 'utf-8') as f:
      self.schedule_pol = json.load(f)
    with open("config/createClient.json", encoding = 'utf-8') as f:
      self.createClient = json.load(f)
    with open("config/createPushClient.json", encoding = 'utf-8') as f:
      self.createPushClient = json.load(f)
    with open("config/uploadPackage.json", encoding = 'utf-8') as f:
      self.uploadPackage = json.load(f)
    with open("config/createUser.json", encoding = 'utf-8') as f:
      self.createUser = json.load(f)
    with open("config/createPCREPolicy.json", encoding = 'utf-8') as f:
      self.createPCREPolicy = json.load(f)
    with open("config/createPolicyUnsecDomain.json", encoding = 'utf-8') as f:
      self.createPolicyUnsecDomain = json.load(f)
    with open("config/createPushClientExclusive.json", encoding = 'utf-8') as f:
      self.createPushClientExclusive = json.load(f)
    with open("config/createFromAllPolicy.json", encoding = 'utf-8') as f:
      self.createFromAllPolicy = json.load(f)
    with open("config/createRegisterPlugin.json", encoding = 'utf-8') as f:
      self.createRegisterPlugin = json.load(f)
    with open("config/createReport.json", encoding = 'utf-8') as f:
      self.createReport = json.load(f)
    with open("config/createReportApplicationModel.json", encoding = 'utf-8') as f:
      self.createReportApplicationModel = json.load(f)

  def set_environment(self):
    global base_url, user_name, password, auth
    # base_url = self.conf[env]["base_url"]
    # user_name = self.conf[env]["orch_admin"]
    # password = self.conf[env]["orch_pwd"]
    # auth = self.conf[env]["auth"]
    base_url = BuiltIn().get_variable_value('${base_url}', None)
    logger.info('base_url = %s ' % base_url)
    user_name = BuiltIn().get_variable_value('${orch_admin}', None)
    password = BuiltIn().get_variable_value('${orch_pwd}', None)
    auth = BuiltIn().get_variable_value('${auth}', None)

  def login_into_orchestrator(self):
    if not self.orch_ip:
      self.set_environment()
    endpoint=base_url+'/oauth/token'
    logger.info('Inside login_into_orchestrator - orch_url = %s ' % endpoint)
    response = self.session.post(endpoint,
        headers={
          "Authorization": auth,
          "Content-Type": "application/x-www-form-urlencoded"
        }, 
        verify=False,
        data={
          "username": user_name,
          "password": password,
          "grant_type": "password"
        }
    )
    self.access_token = response.json()['access_token']
    logger.info("*INFO:%d* access_token = %s" % ((time.time()*1000), self.access_token))
    self.get_orch_version()
    self.action = self.get_actions()
    self.subActions = self.get_sub_actions()

  def login_into_orchestrator_as(self, user_name):
    if not self.orch_ip:
      self.set_environment()
    endpoint=base_url+'/oauth/token'
    session = requests.session()
    tokens[user_name]['sess'] = session
    auth = tokens[user_name]['auth']
    response = session.post(endpoint,
        headers={
          "Authorization": auth,
          "Content-Type": "application/x-www-form-urlencoded"
        }, 
        verify=False,
        data={
          "username": user_name,
          "password": password,
          "grant_type": "password"
        }
    )
    json_resp = response.json()
    access_token = json_resp['access_token']
    BuiltIn().should_not_be_empty(access_token, 'FAIL: Did not get access_token, login failed')
    tokens[user_name]['access_token'] = access_token
    logger.info("PASS: Login to orchestrator as %s was successful" % user_name)
    logger.info("access_token: %s" % access_token)
    time.sleep(2)

  def login_for_first_time(self, user_name, old_pwd, new_pwd):
    if not self.orch_ip:
      self.set_environment()
    endpoint=base_url+'/oauth/token'
    logger.info("Using Orchestrator URL : %s" % endpoint)
    session = requests.session()
    tokens[user_name]['sess'] = session
    auth = tokens[user_name]['auth']
    response = session.post(endpoint,
        headers={
          "Authorization": auth,
          "Content-Type": "application/x-www-form-urlencoded"
        }, 
        verify=False,
        data={
          "username": user_name,
          "password": old_pwd,
          "grant_type": "password"
        }
    )
    logger.info(response.json())
    pwd_reset = response.json()['required_password_reset']
    BuiltIn().should_be_true(pwd_reset, 'FAIL: required_password_reset is not true')
    endpoint = base_url + '/api/user/updateUserCredentialsAndEULA.ws'
    data={
      "username": user_name,
      "password": old_pwd,
      "newPassword": new_pwd,
      "confirmNewPassword": new_pwd,
      "eulaAccepted": True
    }
    json_data = json.dumps(data)
    response = session.post(endpoint,
        headers={
          "Content-Type": "application/json"
        }, 
        verify=False,
        data = json_data
    )
    logger.info(response.json())
    BuiltIn().should_contain(response.json()['message'], 'User updated successfully.')
    return True

  def execute_get_api(self, api_url, params=None, user='administrator', non_json=False):
    endpoint=base_url+api_url
    access_token = self.access_token
    if user != 'administrator' :
      access_token = tokens[user]['access_token']
    logger.info("*INFO:%d* GET url = %s" % ((time.time()*1000), endpoint))
    logger.info("*INFO:%d* GET params = %s" % ((time.time()*1000), params))
    response = self.session.get(endpoint,
        headers={
          "Authorization": 'Bearer %s' % access_token
        }, 
        verify=False,
        params=params
    )
    logger.info("*INFO:%d* Response statusCode = %d" % ((time.time()*1000), response.status_code))
    content = response.content.decode('utf-8')
    logger.info("*INFO:%d* Response content = %s" % ((time.time()*1000), content))
    if response.status_code == 401 and self.checkForTokenExpiry(content):
      logger.info("*INFO:%d* Retrying execute_get_api %s" % ((time.time()*1000), api_url))
      return self.execute_get_api(api_url, params)
    if non_json:
      return content
    return response.json()

  def checkForTokenExpiry(self, resp):
    # print("*INFO:%d* Inside checkForTokenExpiry = %s" % ((time.time()*1000), "resp = %s" % resp))
    try:
      json_resp = json.loads(resp)
      err = jmespath.search('@.error', json_resp)
      logger.info("*INFO:%d* ERROR = %s" % ((time.time()*1000), "err = %s" % err))
      if err == 'invalid_token':
        logger.info("*INFO:%d* ERROR = %s" % ((time.time()*1000), "Access Token Has Expired.. Re-login"))
        self.login_into_orchestrator()
        return True
    except json.decoder.JSONDecodeError:
      logger.info("*INFO:%d* NON JSON RESPONSE = %s" % ((time.time()*1000), resp))
    return False

  def execute_post_api(self, api_url, payload=None, params=None, files=None, data=None):
    endpoint=base_url+api_url
    logger.info("*INFO:%d* POST url = %s" % ((time.time()*1000), endpoint))
    logger.info("*INFO:%d* POST payload = %s" % ((time.time()*1000), payload))
    logger.info("*INFO:%d* POST params = %s" % ((time.time()*1000), params))
    response = self.session.post(endpoint,
        headers={
          "Authorization": 'Bearer %s' % self.access_token
        }, 
        verify=False,
        json=payload,
        params=params,
        data=data,
        files=files
    )
    time.sleep(DEFULT_SLEEP_INTERVAL)
    logger.info("*INFO:%d* Response statusCode = %d" % ((time.time()*1000), response.status_code))
    content = response.content.decode('utf-8')
    logger.info("*INFO:%d* Response content = %s" % ((time.time()*1000), content))
    if self.checkForTokenExpiry(response.content):
      logger.info("*INFO:%d* Retry operation execute_post_api = %s" % ((time.time()*1000), api_url))
      return self.execute_post_api(api_url, payload, params, files, data)
    try:
      return response.json()
    except json.decoder.JSONDecodeError:
      logger.info("*WARN:%d* NON JSON RESPONSE FOR POST = %s" % ((time.time()*1000), response.content))
      return response

  def execute_put_api(self, api_url, payload=None, params=None, files=None, data=None):
    endpoint=base_url+api_url
    logger.info("*INFO:%d* POST url = %s" % ((time.time()*1000), endpoint))
    logger.info("*INFO:%d* POST payload = %s" % ((time.time()*1000), payload))
    logger.info("*INFO:%d* POST params = %s" % ((time.time()*1000), params))
    response = self.session.put(endpoint,
        headers={
          "Authorization": 'Bearer %s' % self.access_token
        }, 
        verify=False,
        json=payload,
        params=params,
        data=data,
        files=files
    )
    time.sleep(DEFULT_SLEEP_INTERVAL)
    logger.info("*INFO:%d* Response statusCode = %d" % ((time.time()*1000), response.status_code))
    content = response.content.decode('utf-8')
    logger.info("*INFO:%d* Response content = %s" % ((time.time()*1000), content))
    if self.checkForTokenExpiry(content):
      logger.info("*INFO:%d* Retry operation execute_put_api = %s" % ((time.time()*1000), api_url))
      return self.execute_put_api(api_url, payload, params, files, data)
    return response.json()

  def execute_delete_api(self, api_url, params=None):
    endpoint=base_url+api_url
    logger.info("*INFO:%d* DELETE url = %s" % ((time.time()*1000), endpoint))
    logger.info("*INFO:%d* DELETE params = %s" % ((time.time()*1000), params))
    response = self.session.delete(endpoint,
        headers={
          "Authorization": 'Bearer %s' % self.access_token
        }, 
        verify=False,
        params=params
    )
    time.sleep(DEFULT_SLEEP_INTERVAL)
    logger.info("*INFO:%d* Response statusCode = %d" % ((time.time()*1000), response.status_code))
    content = response.content.decode('utf-8')
    logger.info("*INFO:%d* Response content = %s" % ((time.time()*1000), content))
    if self.checkForTokenExpiry(content):
      logger.info("*INFO:%d* Retry operation execute_delete_api = %s" % ((time.time()*1000), api_url))
      return self.execute_delete_api(api_url, params)
    return response.json()

  def get_users(self):
    api_url = '/api/user/views.ws'
    return self.execute_get_api(api_url)

  def get_orch_version(self):
    api_url = '/api/dashboard/version.ws'
    content = self.execute_get_api(api_url,non_json=True)
    with open("orch_version","w") as f:
      f.writelines([content])
      f.flush()
    logger.info('Using orchestrator version = %s' % content)
    return content

  def verify_user_is_added(self, user_name):
    list_users = self.get_users()
    uname = jmespath.search('@[?username==\'' + user_name + '\'] | [0].username', list_users)
    logger.info('user_name found was = %s' % uname)
    BuiltIn().should_be_equal(user_name, uname, "user not found, usercreation failed")
    return True

  def delete_user(self, user_name):
    api_url = '/api/user/delete.ws'
    list_users = self.get_users()
    userId = jmespath.search('@[?username==\'' + user_name + '\'] | [0].userId', list_users)
    logger.info('userId found was = %s' % userId)
    BuiltIn().should_not_be_empty(str(userId), "user not found, usercreation failed")
    resp = self.execute_delete_api(api_url, params={'userId': userId})
    BuiltIn().should_contain(str(resp) ,"User deleted successfully.")
    return True
    

  def create_user(self, uname, pwd, domain_name='All', subdomain_name='All', writeAccess=False):
    api_url = '/api/user/create.ws'
    user = self.createUser
    if(domain_name == 'All'):
      custId = 0
    else:
      domain_list = self.get_domains()
      custId = jmespath.search('listCustomers[?custName == \'' + domain_name + '\'].custId | [0]', domain_list)
    logger.info('custId = %s' % custId)
    if(subdomain_name == 'All'):
      deptId = 0
    else:
      sd_list = self.get_sub_domains_of(domain_name)
      deptId = jmespath.search('listDepartments[?deptName == \'' + domain_name + '\'].deptId | [0]', sd_list)
    logger.info('deptId = %s' % deptId)
    user['username'] = uname
    user['firstName'] = uname
    user['password'] = pwd
    user['confirmPassword'] = pwd
    user['email'] = uname+'@avocadosys.com'
    user['listTenancy'][0]['customer']['custId'] = custId
    user['listTenancy'][0]['department']['custId'] = custId
    user['listTenancy'][0]['department']['deptId'] = deptId

    if writeAccess:
      user['listTenancy'][0]['userRW'] = True
      user['listTenancy'][0]['settingsRW'] = True
      user['listTenancy'][0]['policyRW'] = True
      user['listTenancy'][0]['applicationRW'] = True
    else:
      user['listTenancy'][0]['userRW'] = False
      user['listTenancy'][0]['settingsRW'] = False
      user['listTenancy'][0]['policyRW'] = False
      user['listTenancy'][0]['applicationRW'] = False
    ret = self.execute_post_api(api_url, payload=user)
    BuiltIn().should_contain(str(ret), "User created successfully.")
    return ret

  def get_domains(self):
    api_url = '/api/customer/views.ws'
    self.domains = self.execute_get_api(api_url, {"offset": 0, "pageSize": 100})
    return self.domains

  def add_domain(self, name):
    api_url = '/api/customer/create.ws'
    resp = self.execute_post_api(api_url, payload={"custName": name })
    return resp
  
  def add_subdomain(self, name, domain_name):
    api_url = '/api/department/create.ws'
    domain_list = self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \'' + domain_name + '\'].custId | [0]', domain_list)
    logger.info('custId = %s' % custId)    
    return self.execute_post_api(api_url, payload={"custId": custId, "deptName": name})

  def delete_subdomain(self, name, domain_name):
    api_url = '/api/department/delete.ws'
    domain_list = self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \'' + domain_name + '\'].custId | [0]', domain_list)
    logger.info('custId = %s' % custId)
    sd_list = self.get_sub_domains_of(domain_name)
    deptId = jmespath.search('listDepartments[?deptName == \'' + name + '\'].deptId | [0]', sd_list)
    logger.info('deptId = %s' % deptId)
    return self.execute_delete_api(api_url, params={"custId": custId, "deptId": deptId})
  
  def delete_domain(self, name):
    api_url = '/api/customer/delete.ws'
    domain_list = self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \'' + name + '\'].custId | [0]', domain_list)
    logger.info('custId = %s' % custId)    
    return self.execute_delete_api(api_url, params={"custId": custId })

  def get_sub_domains_of(self, domain_name):
    api_url = '/api/department/views.ws'
    custId = jmespath.search('listCustomers[?custName == \''+domain_name+'\'].custId | [0]', self.domains)
    logger.info('custId = %s' % custId)
    return self.execute_get_api(api_url, {"custId": custId , "offset": 0, "pageSize": 100})

  def get_applications(self, domain_name, subdomain_name):
    api_url = '/api/application/views.ws'
    self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \''+domain_name+'\'].custId | [0]', self.domains)
    sub_domains = self.get_sub_domains_of(domain_name)
    deptId = jmespath.search('listDepartments[?deptName == \''+subdomain_name+'\'].deptId | [0]', sub_domains)
    return self.execute_get_api(api_url, {"custId": custId, "deptId": deptId})

  def get_discovered_apps_from_tenancy(self, domain_name, subdomain_name):
    api_url = '/api/application/views.ws'
    self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \''+domain_name+'\'].custId | [0]', self.domains)
    sub_domains = self.get_sub_domains_of(domain_name)
    deptId = jmespath.search('listDepartments[?deptName == \''+subdomain_name+'\'].deptId | [0]', sub_domains)
    return self.execute_get_api(api_url, {"custId": custId, "deptId": deptId, "isRegistered": 0, "offset": 0, "pageSize": 100})

  def get_registered_apps_from_tenancy(self, domain_name, subdomain_name):
    api_url = '/api/application/views.ws'
    self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \''+domain_name+'\'].custId | [0]', self.domains)
    sub_domains = self.get_sub_domains_of(domain_name)
    deptId = jmespath.search('listDepartments[?deptName == \''+subdomain_name+'\'].deptId | [0]', sub_domains)
    return self.execute_get_api(api_url, {"custId": custId, "deptId": deptId, "isRegistered": 1})

  def get_all_discovered_apps(self):
    api_url = '/api/application/views.ws'
    params = {"isRegistered": 0, "offset": 0, "pageSize": 100}
    return self.execute_get_api(api_url, params)

  def get_all_registered_apps(self):
    api_url = '/api/application/views.ws'
    params = {"isRegistered": 1, "offset": 0, "pageSize": 100}
    return self.execute_get_api(api_url,  params)

  def get_all_apps_count(self):
    app_list = self.get_all_apps()
    return int(app_list['totalRows'])

  def get_all_policies(self):
    api_url = '/api/applicationSecurityPolicy'
    # TODO: Change page size 
    return self.execute_get_api(api_url, {"offset": 0, "pageSize": 500})

  def get_actions(self):
    api_url = '/api/applicationSecurityPolicy/policyAction/views.ws'
    # TODO: Change page size 
    return self.execute_get_api(api_url)
  
  def get_plugin_packages(self):
    api_url = '/api/pluginPackages/packages.ws'
    return self.execute_get_api(api_url)

  def get_sub_actions(self):
    api_url = '/api/applicationSecurityPolicy/policySubAction/views.ws'
    # TODO: Change page size 
    return self.execute_get_api(api_url)

  def get_active_registered_app_from_tenancy_on_host(self, mgmtIp, appName, domain, subDomain):
    apps_list = self.get_registered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    active_app_on_host = []
    for app in apps:
      server =  self.get_server_for_appid(app['appId'])['listServerInfo'][0]
      if server['managementIP'] == mgmtIp and server['active'] == True:
        active_app_on_host.append(app)
    BuiltIn().should_be_true(len(active_app_on_host) == 1, "Multiple or Zero active registered apps found")
    return active_app_on_host

  def get_registered_app_from_tenancy_on_host(self, mgmtIp, appName, domain, subDomain):
    apps_list = self.get_registered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    app_on_host = []
    for app in apps:
      server =  self.get_server_for_appid(app['appId'])['listServerInfo'][0]
      if server['managementIP'] == mgmtIp:
        app_on_host.append(app)
    # BuiltIn().should_be_true(len(active_app_on_host) == 1, "Multiple or Zero active registered apps found")
    return app_on_host

  def view_notifications(self):
    api_url = '/api/notifications/views.ws'
    response = self.execute_get_api(api_url)
    return response

  def create_basic_policy(self, name, hostIP1, appName1, direction, action, subAction, app1_dom, app1_sub, hostIP2=None, appName2=None, app2_dom=None, app2_sub=None):
    api_url = '/api/applicationSecurityPolicy/create.ws'
    pol = self.create_pol
    pol["policyName"] = name
    pol["direction"] = direction
    action = jmespath.search('@[?actionName==\'' + action + '\'] | [0].{actionId: actionId, actionName: actionName}', self.action)
    subAction = jmespath.search('@[?subActionName==\'' + subAction + '\'] | [0].{subActionId: subActionId, subActionName: subActionName}', self.subActions)
    pol['action'] = action
    pol['subAction'] = subAction
    if(appName1):
      if(appName1=='Unsecured Application'):
        appId1 = 1  
      else:
        appList1 = self.get_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
        if len(appList1)>1 :
          logger.info("*INFO:%d*  %s" % ((time.time()*1000), "Multiple Apps with same name found on same host, finding active amongst them"))
          appList1 = self.get_active_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
          BuiltIn().should_be_true(len(appList1) == 1, "Multiple or Zero active registered apps found")
        appId1 = appList1[0]['appId']
    else:
      appId1 = 0
    if(appName2):
      if(appName2=='Unsecured Application'):
        appId2 = 1  
      else:
        appList2 = self.get_active_registered_app_from_tenancy_on_host(hostIP2, appName2, app2_dom, app2_sub)
        if len(appList2)>1 :
          logger.info("*INFO:%d*  %s" % ((time.time()*1000), "Multiple Apps with same name found on same host, finding active amongst them"))
          appList2 = self.get_active_registered_app_from_tenancy_on_host(hostIP2, appName2, app2_dom, app2_sub)
          BuiltIn().should_be_true(len(appList2) == 1, "Multiple or Zero active registered apps found")
        appId2 = appList2[0]['appId']
    else:
      appId2 = 0
    pol['app1']['appId'] = appId1 
    pol['app2']['appId'] = appId2
    ret = self.execute_post_api(api_url, pol)
    BuiltIn().should_contain(str(ret), "Policy created successfully.")
    return ret

  def create_basic_policy_for_unsecure_domain(self, name, hostIP1, appName1, action, subAction, app1_dom, app1_sub):
    api_url = '/api/applicationSecurityPolicy/create.ws'
    pol = self.createPolicyUnsecDomain
    pol["policyName"] = name
    # pol["direction"] = direction
    action = jmespath.search('@[?actionName==\'' + action + '\'] | [0].{actionId: actionId, actionName: actionName}', self.action)
    subAction = jmespath.search('@[?subActionName==\'' + subAction + '\'] | [0].{subActionId: subActionId, subActionName: subActionName}', self.subActions)
    pol['action'] = action
    pol['subAction'] = subAction
    appList1 = self.get_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
    BuiltIn().should_be_true(len(appList1) > 0, "Zero registered apps found")
    if len(appList1) > 1 :
      logger.info("*INFO:%d*  %s" % ((time.time()*1000), "Multiple Apps with same name found on same host, finding active amongst them"))
      appList1 = self.get_active_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
      BuiltIn().should_be_true(len(appList1) == 1, "Multiple or Zero active registered apps found")
    pol['app1']['appId'] = 1 
    pol['app2']['appId'] = appList1[0]['appId']
    ret = self.execute_post_api(api_url, pol)
    BuiltIn().should_contain(str(ret), "Policy created successfully.")
    return ret

  def create_basic_policy_from_all_domain(self, name, hostIP1, appName1, action, subAction, app1_dom, app1_sub):
    api_url = '/api/applicationSecurityPolicy/create.ws'
    pol = self.createFromAllPolicy
    pol["policyName"] = name
    # pol["direction"] = direction
    action = jmespath.search('@[?actionName==\'' + action + '\'] | [0].{actionId: actionId, actionName: actionName}', self.action)
    subAction = jmespath.search('@[?subActionName==\'' + subAction + '\'] | [0].{subActionId: subActionId, subActionName: subActionName}', self.subActions)
    pol['action'] = action
    pol['subAction'] = subAction
    appList1 = self.get_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
    BuiltIn().should_be_true(len(appList1) > 0, "Zero registered apps found")
    if len(appList1) > 1 :
      logger.info("*INFO:%d*  %s" % ((time.time()*1000), "Multiple Apps with same name found on same host, finding active amongst them"))
      appList1 = self.get_active_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
      BuiltIn().should_be_true(len(appList1) == 1, "Multiple or Zero active registered apps found")
    pol['app1']['appId'] = 0 
    pol['app2']['appId'] = appList1[0]['appId']
    ret = self.execute_post_api(api_url, pol)
    BuiltIn().should_contain(str(ret), "Policy created successfully.")
    return ret

  def create_basic_policy_allow_both_domains(self, name, hostIP1, appName1, action, subAction, app1_dom, app1_sub,
                                             hostIP2, appName2, app2_dom, app2_sub):
    api_url = '/api/applicationSecurityPolicy/create.ws'
    pol = self.createFromAllPolicy
    pol["policyName"] = name
    pol["direction"] = 'bidirection'
    action = jmespath.search('@[?actionName==\'' + action + '\'] | [0].{actionId: actionId, actionName: actionName}', self.action)
    subAction = jmespath.search('@[?subActionName==\'' + subAction + '\'] | [0].{subActionId: subActionId, subActionName: subActionName}', self.subActions)
    pol['action'] = action
    pol['subAction'] = subAction
    appList1 = self.get_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
    BuiltIn().should_be_true(len(appList1) > 0, "Zero registered apps found")
    if len(appList1) > 1 :
      logger.info("*INFO:%d*  %s" % ((time.time()*1000), "Multiple Apps with same name found on same host, finding active amongst them"))
      appList1 = self.get_active_registered_app_from_tenancy_on_host(hostIP1, appName1, app1_dom, app1_sub)
      BuiltIn().should_be_true(len(appList1) == 1, "Multiple or Zero active registered apps found")
    
    appList2 = self.get_registered_app_from_tenancy_on_host(hostIP2, appName2, app2_dom, app2_sub)
    BuiltIn().should_be_true(len(appList2) > 0, "Zero registered apps found")
    if len(appList2) > 1 :
      logger.info("*INFO:%d*  %s" % ((time.time()*1000), "Multiple Apps with same name found on same host, finding active amongst them"))
      appList1 = self.get_active_registered_app_from_tenancy_on_host(hostIP2, appName2, app2_dom, app2_sub)
      BuiltIn().should_be_true(len(appList2) == 1, "Multiple or Zero active registered apps found")
    pol['app1']['appId'] = appList1[0]['appId'] 
    pol['app2']['appId'] = appList2[0]['appId']
    ret = self.execute_post_api(api_url, pol)
    BuiltIn().should_contain(str(ret), "Policy created successfully.")
    return ret

  def schedule_policy_always(self, name, always=True):
    api_url = '/api/policySchedule/schedule.ws'
    policies = self.get_all_policies()
    logger.info('listAppSecurityPolicy[?policyName==\'' + name + '\'] | [0].policyId')
    policyId = jmespath.search('listAppSecurityPolicy[?policyName==\'' + name + '\'] | [0].policyId', policies)
    logger.info('policyId = %s ',policyId)
    self.schedule_pol['policyId'] = policyId
    self.schedule_pol['isRepeat'] = False
    self.schedule_pol['repeatType'] = 0
    self.schedule_pol['repeatCount'] = 0
    logger.info(self.schedule_pol)
    return self.execute_post_api(api_url,self.schedule_pol)

  def get_clients(self):
    api_url = '/api/client/views.ws'
    params = {"offset": 0, "pageSize": 100}
    return self.execute_get_api(api_url, params)

  def get_packages(self):
    api_url = '/api/pluginPackages/views.ws'
    return self.execute_get_api(api_url)

  def set_polling_interval(self, interval=30):
    api_url = '/api/globalSettings/pollingInterval.ws'
    params = { "pollingInterval" : interval } 
    return self.execute_post_api(api_url, None, params)

  def set_process_polling_interval(self, interval=15):
    api_url = '/api/globalSettings/processInterval.ws'
    params = { "processInterval" : interval } 
    return self.execute_post_api(api_url, None, params)

  def delete_client_if_exists_by_ip(self, mgmtIp, msg= 'Plugin deleted successfully.'):
    api_url = '/api/client/delete.ws'
    client_list = self.get_clients()
    client_Ids = jmespath.search('listClients | [].clientId', client_list)
    client_id = None
    for id in client_Ids:
      client = self.get_severinfo_by_cl_id(id)
      if(client['totalRows'] > 0  and mgmtIp == client['listServerInfo'][0]['managementIP']):
        client_id = client['listServerInfo'][0]['clientId']
        break
    if client_id:
      logger.info("*INFO:%d*  %s" % ((time.time()*1000), '-------->Deleting client_id %s' % client_id))
      resp = self.execute_delete_api(api_url, {"clientId": client_id})
      BuiltIn().should_contain(resp, msg)
      logger.info("*INFO:%d*  %s" % ((time.time()*1000), resp))


  def create_client_push_install(self, name, enabled, domain, subDomain, 
                                executionMode, osType, osName, osVersion,
                                ipAddress, userName, password):
    api_url = '/api/client/create.ws'
    self.get_domains()
    sub_domains = self.get_sub_domains_of(domain)
    client = self.createPushClient
    client['clientName'] = name
    client['enabled'] = enabled
    client['execution']['executionMode'] = executionMode
    #TODO currently only role AppManager
    client['role']['roleId'] = 2 
    custId = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custId | [0]', self.domains)
    custName = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custName | [0]', self.domains)
    deptId = jmespath.search('listDepartments[?deptName == \'' + subDomain + '\'].deptId | [0]', sub_domains)
    deptName = jmespath.search('listDepartments[?deptName == \'' + subDomain + '\'].deptName | [0]', sub_domains)
    client['listTenancy'][0]['customer']['custId'] = 0
    client['listTenancy'][0]['department']['custId'] = 0
    client['listTenancy'][0]['department']['deptId'] = 0
    client['execution']['defaultCustomer']['custId'] = custId
    client['execution']['defaultCustomer']['custName'] = custName
    client['execution']['defaultDepartment']['deptId'] = deptId
    client['execution']['defaultDepartment']['deptName'] = deptName
    packages = self.get_packages()
    searchExp = '@[?(osName==\''+osName+'\' && osType==\''+osType+'\' && osVersion==\''+osVersion+'\')] | [0].pluginPackage'
    logger.info(searchExp)
    pluginPackage = jmespath.search(searchExp , packages)
    logger.info(pluginPackage)
    client['pluginInstallationInfoList'][0]['hostIp'] = ipAddress
    client['pluginInstallationInfoList'][0]['hostUserName'] = userName
    client['pluginInstallationInfoList'][0]['hostUserPassword'] = password
    client['pluginInstallationInfoList'][0]['os'] = osType + '#' + osName + '#' + osVersion
    client['pluginInstallationInfoList'][0]['pluginPackage'] = pluginPackage
    logger.info(client)
    secretStr = self.execute_post_api(api_url, client)
    logger.info(secretStr)
    return secretStr

  def create_register_plugin(self, name, enabled, domain, subDomain, executionMode):
    api_url = '/api/client/create.ws'
    self.get_domains()
    sub_domains = self.get_sub_domains_of(domain)
    client = self.createRegisterPlugin
    client['clientName'] = name
    client['enabled'] = enabled
    client['execution']['executionMode'] = executionMode
    #TODO currently only role AppManager
    client['role']['roleId'] = 2
    custId = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custId | [0]', self.domains)
    custName = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custName | [0]', self.domains)
    deptId = jmespath.search('listDepartments[?deptName == \'' + subDomain + '\'].deptId | [0]', sub_domains)
    deptName = jmespath.search('listDepartments[?deptName == \'' + subDomain + '\'].deptName | [0]', sub_domains)
    client['listTenancy'][0]['customer']['custId'] = custId
    client['listTenancy'][0]['department']['custId'] = custId
    client['listTenancy'][0]['department']['deptId'] = deptId
    client['execution']['defaultCustomer']['custId'] = custId
    client['execution']['defaultCustomer']['custName'] = custName
    client['execution']['defaultDepartment']['deptId'] = deptId
    client['execution']['defaultDepartment']['deptName'] = deptName
    logger.info(client)
    secretStr = self.execute_post_api(api_url, client)
    logger.info(secretStr)
    return secretStr

  def create_client_push_install_with_exclusive_tenancy(self, name, enabled, domain, subDomain, 
                                executionMode, osType, osName, osVersion,
                                ipAddress, userName, password):
    api_url = '/api/client/create.ws'
    self.get_domains()
    sub_domains = self.get_sub_domains_of(domain)
    client = self.createPushClient
    client['clientName'] = name
    client['enabled'] = enabled
    client['execution']['executionMode'] = executionMode
    #TODO currently only role AppManager
    client['role']['roleId'] = 2 
    custId = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custId | [0]', self.domains)
    custName = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custName | [0]', self.domains)
    deptId = jmespath.search('listDepartments[?deptName == \'' + subDomain + '\'].deptId | [0]', sub_domains)
    deptName = jmespath.search('listDepartments[?deptName == \'' + subDomain + '\'].deptName | [0]', sub_domains)
    client['listTenancy'][0]['customer']['custId'] = custId
    client['listTenancy'][0]['department']['custId'] = custId
    client['listTenancy'][0]['department']['deptId'] = deptId
    client['execution']['defaultCustomer']['custId'] = custId
    client['execution']['defaultCustomer']['custName'] = custName
    client['execution']['defaultDepartment']['deptId'] = deptId
    client['execution']['defaultDepartment']['deptName'] = deptName
    packages = self.get_packages()
    searchExp = '@[?(osName==\''+osName+'\' && osType==\''+osType+'\' && osVersion==\''+osVersion+'\')] | [0].pluginPackage'
    logger.info(searchExp)
    pluginPackage = jmespath.search(searchExp , packages)
    logger.info(pluginPackage)
    client['pluginInstallationInfoList'][0]['hostIp'] = ipAddress
    client['pluginInstallationInfoList'][0]['hostUserName'] = userName
    client['pluginInstallationInfoList'][0]['hostUserPassword'] = password
    client['pluginInstallationInfoList'][0]['os'] = osType + '#' + osName + '#' + osVersion
    client['pluginInstallationInfoList'][0]['pluginPackage'] = pluginPackage
    logger.info(client)
    secretStr = self.execute_post_api(api_url, client)
    logger.info(secretStr)
    return secretStr

  def upload_package(self, osType, osName, osVersion, packageDir):
    api_url = '/api/pluginPackages/create.ws'
    self.uploadPackage["osType"] = osType
    self.uploadPackage["osName"] = osName
    self.uploadPackage["osVersion"] = osVersion
    package = [f for f in os.listdir('%s/' % packageDir) if 'avcdadpl' in f.lower()][0]
    installer = [f for f in os.listdir('%s/' % packageDir) if 'install_adpl' in f.lower()][0]
    print('package = %s' % package)
    print('installer = %s' % installer)
    self.uploadPackage["pluginPackage"] = package
    self.uploadPackage["installerFile"] = installer
    pFile = '%s/%s' % (packageDir, package)
    iFile = '%s/%s' % (packageDir, installer)
    files = [
              ("files" , (package,  open(pFile, 'rb'), 'application/octet-stream')),
              ("files" , (installer, open(iFile, 'rb'), 'text/x-sh' )),
            ]
    data =  {"request": str(self.uploadPackage).replace('\'','"')}
    # logger.info(requests.Request('POST', 'http://httpbin.org/post', data=data, files=files).prepare().body)
    return self.execute_post_api(api_url, data=data, files=files)

  def delete_package(self, osType, osName, osVersion):
    api_url = '/api/pluginPackages/delete.ws'
    packages  = self.get_packages()
    searchExp = '@[?(osName==\''+osName+'\' && osType==\''+osType+'\' && osVersion==\''+osVersion+'\')] | [0].id'
    pluginPackageId = jmespath.search(searchExp , packages)
    logger.info("Deleting package id = %s" % pluginPackageId)
    return self.execute_delete_api(api_url, {"id": pluginPackageId})

  def wait_for_client_push_to_finish(self, name, loops=150):
    """
    Wait for push installation of plugin be repeatedly calling get_clients(), 
    Timeout by default in 4500 seconds, fails if push status is not Success even after timeout

    Args:
      name(str): name of client push install

    """
    pushStatus = 'In progress'
    for i in range(loops):
      time.sleep(30)
      client_list = self.get_clients()
      srch = 'listClients[?starts_with(clientName,\''+name+'\')] | [0].pushStatus'
      pushStatus = jmespath.search(srch, client_list)
      print('pushStatus = %s' % pushStatus)
      if pushStatus != None:
        if pushStatus != 'In progress' :
          break
    logger.info('Client push status = %s' % pushStatus)
    if pushStatus == 'Success':
      logger.info('Waiting for 10 seconds for appManager to start = %s' % pushStatus)
      logger.info('Waiting for 10 seconds for appManager to start')
      time.sleep(10)
      return True
    # BuiltIn().should_be_equal(pushStatus, 'Success','Push install is not successful')
    return False

  def get_server_for_appid(self, appId):
    """
    Gets host for given application id, 
    /api/application/serverInfo/views.ws

    Args:
      appId(str): appId

    Returns:
      resp(obj): api response of /api/application/serverInfo/views.ws
    """
    api_url = '/api/application/serverInfo/views.ws'
    params = { "appId" : appId } 
    return  self.execute_get_api(api_url, params)

  def register_app_from_tenancy(self, mgmtIp, appName, domain, subDomain):
    """
    Registers an application  on given host from tenancy by executing api, 
    /api/application

    Args:
      mgmtIp(str): IP of application host
      appName(str): name of application
      domain(str): name of domain
      subDomain(str): name of sub domain

    Returns:
      resp(obj): api response of /api/application
    """
    api_url = '/api/application'
    apps_list = self.get_discovered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    responses = []
    app_on_host = [app for app in apps if self.get_server_for_appid(app['appId'])['listServerInfo'][0]['managementIP'] == mgmtIp]
    logger.info('Found %s %s apps on host %s' % (len(app_on_host), appName, mgmtIp))
    for app in app_on_host:
      app['isRegistered'] = 1
      # app['isAdplEnabled'] = 1
      app['appAliasName'] = appName + '-' + mgmtIp
      resp = self.execute_put_api(api_url, payload=app)
      responses.append(resp)
    return responses

  def protect_app_from_tenancy(self, mgmtIp, appName, domain, subDomain):
    """
    Protects a registered application  on given host from tenancy by executing api, 
    /api/application

    Args:
      mgmtIp(str): IP of application host
      appName(str): name of application
      domain(str): name of domain
      subDomain(str): name of sub domain

    Returns:
      resp(obj): api response of /api/application
    """
    api_url = '/api/application'
    apps_list = self.get_registered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    responses = []
    app_on_host = [app for app in apps if self.get_server_for_appid(app['appId'])['listServerInfo'][0]['managementIP'] == mgmtIp]
    logger.info('Found %s %s apps on host %s' % (len(app_on_host), appName, mgmtIp))
    for app in app_on_host:
      app['isAdplEnabled'] = 1
      logger.info('app dict in proctect %s' % str(app))
      resp = self.execute_put_api(api_url, payload=app)
      responses.append(resp)
    return responses

  def verify_app_is_discovered_on_host_from_tenancy(self, mgmtIp, appName, domain, subDomain):
    """
    Verifies if an application is discovered in given tenancy and on given host, 
    Fails if application if not found discovered

    Args:
      mgmtIp(str): IP of application host
      appName(str): name of application
      domain(str): name of domain
      subDomain(str): name of sub domain

    """
    apps_list = self.get_discovered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    app_on_host = []
    for app in apps:
      servers = self.get_server_for_appid(app['appId'])
      if servers['totalRows'] != 0:
        mgmtIps = [server['managementIP'] for server in servers['listServerInfo']]
        if mgmtIp in mgmtIps:
          app_on_host.append(app)
    BuiltIn().should_be_true(len(app_on_host)>0)
    logger.info('Found %s %s apps on host %s' % (len(app_on_host), appName, mgmtIp))

  def allow_app_from_tenancy(self, mgmtIp, appName, domain, subDomain):
    """
    Allows a registered application on given host from tenancy by executing api, 
    /api/application

    Args:
      mgmtIp(str): IP of application host
      appName(str): name of application
      domain(str): name of domain
      subDomain(str): name of sub domain

    Returns:
      resp(obj): api response of /api/application
    """
    api_url = '/api/application'
    apps_list = self.get_registered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    responses = []
    app_on_host = [app for app in apps if self.get_server_for_appid(app['appId'])['listServerInfo'][0]['managementIP'] == mgmtIp]
    logger.info('Found %s %s apps on host %s' % (len(app_on_host), appName, mgmtIp))
    for app in app_on_host:
      app['isAdplEnabled'] = 0
      logger.info('app dict in allow %s' % str(app))
      resp = self.execute_put_api(api_url, payload=app)
      responses.append(resp)
    return responses

  def delete_registered_app_from_tenancy(self, mgmtIp, appName, domain, subDomain):
    """
    Deletes a registered application from tenancy by executing api, 
    /api/application

    Args:
      mgmtIp(str): IP of application host
      appName(str): name of application
      domain(str): name of domain
      subDomain(str): name of sub domain

    Returns:
      resp(obj): api response of /api/application
    """
    api_url = '/api/application'
    apps_list = self.get_registered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    app_on_host = [app for app in apps if self.get_server_for_appid(app['appId'])['listServerInfo'][0]['managementIP'] == mgmtIp]
    responses = []
    for app in app_on_host:
      appId = app['appId']
      params = { "appId" : appId }
      resp = self.execute_delete_api(api_url, params)
      responses.append(resp)
    return responses

  def delete_discovered_app_from_tenancy(self, mgmtIp, appName, domain, subDomain):
    """
    Deletes a discovered application from tenancy by executing api, 
    /api/application

    Args:
      mgmtIp(str): IP of application host
      appName(str): name of application
      domain(str): name of domain
      subDomain(str): name of sub domain

    Returns:
      resp(obj): api response of /api/application
    """
    api_url = '/api/application'
    apps_list = self.get_discovered_apps_from_tenancy(domain,subDomain)
    apps = jmespath.search('listApplications[?appName==\'' + appName + '\']', apps_list)
    app_on_host = [app for app in apps if self.get_server_for_appid(app['appId'])['listServerInfo'][0]['managementIP'] == mgmtIp]
    responses = []
    for app in app_on_host:
      appId = app['appId']
      params = { "appId" : appId }
      resp = self.execute_delete_api(api_url, params)
      responses.append(resp)
    return responses

  def verify_that_the_policy_is_created(self, policy_name):
    """
    Verifies if application security policy exists by executing api, 
    /api/applicationSecurityPolicy/delete.ws
    fails if policy not found

    Args:
      pol_name(str): name of application security policy

    """
    policy_list = self.get_all_policies()
    policy = jmespath.search('listAppSecurityPolicy[?policyName==\'' + policy_name + '\']', policy_list)
    BuiltIn().should_be_true(len(policy) == 1, "Policy Not Found")
    logger.info("*INFO:%d* Found policy -> %s" % ((time.time()*1000), policy_name))

  def delete_policy_and_verify(self, policy_name, msg = 'Policy deleted successfully.'):
    """
    Deletes and verifies application security policy by executing api, 
    fails if policy not found or could not be deleted
    /api/applicationSecurityPolicy/delete.ws
    
    Args:
      pol_name(str): name of application security policy
      msg(str): optional response message to verify against

    """
    api_url = '/api/applicationSecurityPolicy/delete.ws'
    domain_list = policy_list = self.get_all_policies()
    policyId = jmespath.search('listAppSecurityPolicy[?policyName==\'' + policy_name + '\'].policyId | [0]', policy_list)
    BuiltIn().should_be_true(policyId != None, "Policy Not Found")
    logger.info("*INFO:%d* Found policy -> %s" % ((time.time()*1000), policy_name))
    resp = self.execute_delete_api(api_url, params={"policyId": policyId})
    BuiltIn().should_contain(resp, msg)
    logger.info("*INFO:%d*  %s" % ((time.time()*1000), resp))

  def suspend_policy_and_verify(self, policy_name, msg = 'Policy is suspended successfully.'):
    """
    Suspends and verifies application security policy by executing api, 
    fails if policy not found or could not be suspended
    /api/policySchedule/suspend.ws
    
    Args:
      pol_name(str): name of application security policy
      msg(str): optional response message to verify against

    """
    api_url = '/api/policySchedule/suspend.ws'
    domain_list = policy_list = self.get_all_policies()
    policy = jmespath.search('listAppSecurityPolicy[?policyName==\'' + policy_name + '\']', policy_list)
    BuiltIn().should_be_true(len(policy) == 1, "Policy Not Found")
    logger.info("*INFO:%d* Found policy -> %s" % ((time.time()*1000), policy[0]))
    resp = self.execute_post_api(api_url,payload=policy[0])
    BuiltIn().should_contain(resp, msg)
    logger.info("*INFO:%d*  %s" % ((time.time()*1000), resp))

  def get_severinfo_by_cl_id(self, clientId):
    """
    Gets an associated severinfo for given clientId by executing api
    /api/client/serverInfo/views.ws
    
    Args:
      clientId(str): clientId for an application

    Returns:
      resp(obj): api response of /api/client/serverInfo/views.ws
    """
    api_url = '/api/client/serverInfo/views.ws'
    return self.execute_get_api(api_url, { "clientId": clientId, "offset" : 0, "pageSize": 100})

  def get_application_policy_by_name(self, pol_name):
    """
    Gets an existing application security policy by executing api
    /api/applicationSecurityPolicy/views.ws
    
    Args:
      pol_name(str): name of application security policy

    Returns:
      resp(obj): api response of /api/applicationSecurityPolicy/views.ws
    """
    api_url = '/api/applicationSecurityPolicy/views.ws'
    params = {"policyName" : pol_name,"offset": 0, "pageSize": 100}
    return self.execute_get_api(api_url, params)

  def get_pcre_policy_by_name(self, pol_name):
    """
    Gets an existing given pcre policy by executing api, fails if policy not present
    /api/pcre-policy
    
    Args:
      pol_name(str): name of pcre policy

    Returns:
      resp(obj): api response of /api/pcre-policy
    """
    api_url = '/api/pcre-policy'
    params = {"policyName" : pol_name,"offset": 0, "pageSize": 100}
    policy_list =  self.execute_get_api(api_url, params)
    policy = jmespath.search('listPCREPolicy[?policyName==\'' + pol_name + '\']', policy_list)
    BuiltIn().should_be_true(len(policy) == 1, 'FAIL: zero or more policies found')
    return policy[0]

  def delete_pcre_policy_by_name(self, pol_name, msg = 'Secure data policy deleted successfully.'):
    """
    Deletes and verifies given pcre policy by executing api
    /api/pcre-policy
    
    Args:
      pol_name(str): name of pcre policy
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy
    """
    api_url = '/api/pcre-policy'
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId'] 
    params = {"policyId" : policyId}
    response = self.execute_delete_api(api_url, params)
    BuiltIn().should_contain(response['message'], msg, "FAIL: Pcre policy deletion failed")
    return response

  def create_pcre_policy_for_registered_app(self, pol_name, app_name, domain, sub_domain, hostIp='::', msg='Secure data policy created successfully.'):
    """
    Creates and verifies pcre policy for a registered application by executing api
    /api/pcre-policy
    
    Args:
      pol_name(str): name of pcre policy
      app_name(str): Name of registered application
      domain(str): name of domain
      sub_domain(str): name of sub domain
      hostIp(str): optional ip address of application host default ::
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy
    """
    api_url = '/api/pcre-policy'
    apps_list = self.get_registered_apps_from_tenancy(domain, sub_domain)
    apps = jmespath.search('listApplications[?appName==\'' + app_name + '\']', apps_list)
    BuiltIn().should_be_true(len(apps) == 1, 'Found zero or multiple apps of same name, currently multiple apps are not supported')
    appId = apps[0]['appId']
    pol = self.createPCREPolicy
    pol['policyName'] = pol_name
    pol['appIP'] = hostIp
    pol['application']['appId'] = appId
    response = self.execute_post_api(api_url, payload=pol)
    BuiltIn().should_contain(response['message'], msg, "FAIL: Pcre policy creation failed")
    return response

  def activate_pcre_policy(self, pol_name, msg = 'Secure data policy updated successfully.'):
    """
    Activates and verifies pcre policy by executing api
    /api/pcre-policy
    
    Args:
      pol_name(str): name of pcre policy
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy
    """
    api_url = '/api/pcre-policy'
    policy = self.get_pcre_policy_by_name(pol_name)
    payload = dict.copy(policy)
    payload['_original'] = dict.copy(policy)
    payload['enabled'] = True
    resp = self.execute_put_api(api_url, payload)
    BuiltIn().should_contain(resp['message'], msg, "FAIL: Pcre policy activation failed")
    return resp

  def suspend_pcre_policy_and_verify(self, pol_name, msg = 'Secure data policy updated successfully.'):
    """
    Suspends and verifies pcre policy by executing api
    /api/pcre-policy
    
    Args:
      pol_name(str): name of pcre policy
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy
    """
    api_url = '/api/pcre-policy'
    policy = self.get_pcre_policy_by_name(pol_name)
    payload = dict.copy(policy)
    payload['_original'] = dict.copy(policy)
    payload['enabled'] = False
    resp = self.execute_put_api(api_url, payload)
    BuiltIn().should_contain(resp['message'], msg, "FAIL: Pcre policy suspension failed")
    return resp

  def enable_pcre_rule(self, pol_name, rule_id, msg = 'PCRE rule added successfully.'):
    """
    Enables and verifies pcre rule on pcre policy by executing api
    /api/pcre-policy/add-or-remove-pcre-rules
    
    Args:
      pol_name(str): name of pcre policy
      rule_id(int): pcre rule id to disable.
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy/add-or-remove-pcre-rules
    """
    api_url = '/api/pcre-policy/add-or-remove-pcre-rules'
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId']
    params = { "addPCRERuleId": rule_id, "policyId" : policyId }
    resp = self.execute_post_api(api_url, params=params)
    BuiltIn().should_contain(resp.content.decode('utf-8'), msg, 'FAIL: add pcre rule failed')
    return resp

  def enable_all_pcre_rules_of_type(self, pol_name, rule_type, msg = 'PCRE rule added successfully.'):
    """
    Enables and verifies all pcre rules of given type on pcre policy by executing api
    /api/pcre-policy/add-or-remove-pcre-rules
    
    Args:
      pol_name(str): name of pcre policy
      rule_type(str): pcre rule type string.
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy/add-or-remove-pcre-rules
    """
    api_url = '/api/pcre-policy/add-or-remove-pcre-rules'
    typeId = self.get_pcre_rule_type_by_name(rule_type)
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId']
    params = { "addAll": 1, "policyId" : policyId, "typeId": typeId }
    resp = self.execute_post_api(api_url, params=params)
    BuiltIn().should_contain(resp.content.decode('utf-8'), msg, 'FAIL: add pcre rule failed')
    return resp

  def disable_all_pcre_rules_of_type(self, pol_name, rule_type, msg = 'PCRE rule removed successfully'):
    """
    Disables and verifies all pcre rules of given type from pcre policy by executing api
    /api/pcre-policy/add-or-remove-pcre-rules
    
    Args:
      pol_name(str): name of pcre policy
      rule_type(str): pcre rule type string.
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy/add-or-remove-pcre-rules
    """
    api_url = '/api/pcre-policy/add-or-remove-pcre-rules'
    typeId = self.get_pcre_rule_type_by_name(rule_type)
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId']
    params = { "removeAll": 1, "policyId" : policyId, "typeId": typeId }
    resp = self.execute_post_api(api_url, params=params)
    BuiltIn().should_contain(resp.content.decode('utf-8'), msg, 'FAIL: add pcre rule failed')
    return resp
  
  def remove_pcre_rule(self, pol_name, rule_id, msg = 'PCRE rule removed successfully'):
    """
    Disables and verifies pcre rule from pcre policy by executing api
    /api/pcre-policy/add-or-remove-pcre-rules
    
    Args:
      pol_name(str): name of pcre policy
      rule_id(int): pcre rule id to disable.
      msg(str): optional response message to verify against

    Returns:
      resp(obj): api response of /api/pcre-policy/add-or-remove-pcre-rules
    """
    api_url = '/api/pcre-policy/add-or-remove-pcre-rules'
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId']
    params = { "removePCRERuleId": rule_id, "policyId" : policyId }
    resp = self.execute_post_api(api_url, params=params)
    BuiltIn().should_contain(resp.content.decode('utf-8'), msg, 'FAIL: remove pcre rule failed')
    return resp

  def get_pcre_rule_type_by_name(self, rule_type):
    """
    Get id of pcre rule type by executing api
    /api/pcre-rule/types
    
    Args:
      rule_type(str): name of the pcre rule type.

    Returns:
      (int): id of pcre rule type
    """
    api_url = '/api/pcre-rule/types'
    rule_list = self.execute_get_api(api_url) 
    typeId = jmespath.search('@[?typeName==\'' + rule_type + '\'] | [0].typeId', rule_list)
    BuiltIn().should_be_true(type(typeId) == int,'FAIL: unable to find ruleId for given ruleType')
    return typeId

  def verify_pcre_rule_is_enabled(self, pol_name, rule_id, rule_type):
    """
    Verifie if pcre rule id of given type from given policy is enabled by executing api
    /api/pcre-rules
    Verifies if 'applied' is true

    Args:
      pol_name(str): name of pcre policy.
      rule_id(int): pcre rule id to verify.
      rule_id(str): rule type of rule to verify.
    
    Returns:
      (bool): in case of success
    """
    api_url = '/api/pcre-rules'
    typeId = self.get_pcre_rule_type_by_name(rule_type)
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId']
    params = {
      "offset": 0,
      "pageSize": 20,
      "policyId": policyId,
      "scope": "policy",
      "typeId": typeId
    }
    rule_list = self.execute_get_api(api_url, params)
    applied = jmespath.search('listRules[?ruleId == `%s`] | [0].applied' % rule_id , rule_list)
    BuiltIn().should_be_true(applied,'FAIL: Given rule is not enabled')
    return applied

  def verify_rule_is_disabled(self, pol_name, rule_id, rule_type):
    """
    Verifie if pcre rule id of given type from given policy is disabled by executing api
    /api/pcre-rules
    Verifies if 'applied' is false

    Args:
      pol_name(str): name of pcre policy.
      rule_id(int): pcre rule id to verify.
      rule_type(str): rule type of rule to verify.
    
    Returns:
      (bool): in case of success
    """
    api_url = '/api/pcre-rules'
    typeId = self.get_pcre_rule_type_by_name(rule_type)
    policy = self.get_pcre_policy_by_name(pol_name)
    policyId = policy['policyId']
    params = {
      "offset": 0,
      "pageSize": 20,
      "policyId": policyId,
      "scope": "policy",
      "typeId": typeId
    }
    rule_list = self.execute_get_api(api_url, params)
    applied = jmespath.search('listRules[?ruleId == `%s`] | [0].applied' % rule_id , rule_list)
    BuiltIn().should_not_be_true(applied,'FAIL: Given rule is enabled')
    return applied

  def upload_and_verify_pcre_rule_file(self, file_path):
    """
    Uploads and verifies pcre files from given file path by executing api
    /api/pcre-rule/upload-file
    Verifies if 'message' in response is among allowed strings

    Args:
      file_path(str): file path of pcre file.
    
    Returns:
      (bool): in case of success
    """
    msgs = ['PCRE rule updated successfully.','PCRE rule created successfully.']
    api_url = '/api/pcre-rule/upload-file'
    file = open(file_path,'rb')
    files={'file': file}
    response =  self.execute_post_api(api_url, files=files)
    for rule in response:
      BuiltIn().should_be_true(rule['message'] in msgs, 'FAIL: rule *%s* was not uploaded successfully' % rule )
    return True

  def upload_and_verify_multiple_pcre_rule_files(self, folder_name):
    """
    Uploads and verifies all pcre files from given folder
    Args:
      folder_name(str): name of the folder containing pcre files.

    """
    for file in os.scandir('rules/%s' % folder_name):
      if '.conf' in file.path:
        self.upload_and_verify_pcre_rule_file(file.path)

  def get_dashboard_threats_summary(self):
    """
    Get overall threats by executing api
    /api/dashboard/threatSummary.ws
    Args:
      domain_name(str): name of the domain.

    Returns:
      (obj): response of /api/dashboard/threatSummary.ws
    """
    api_url = '/api/dashboard/threatSummary.ws'
    resp =  self.execute_get_api(api_url)
    return resp['threatsDetectedCount']
  
  def get_threats_for_domain(self, domain_name):
    """
    Get threats for given domain name by executing api
    /api/dashboard/domainSubdomainTiles.ws
    Args:
      domain_name(str): name of the domain.

    Returns:
      (obj): response of /api/dashboard/domainSubdomainTiles.ws.
    """
    api_url = '/api/dashboard/domainSubdomainTiles.ws'
    domain_list = self.execute_get_api(api_url)
    domain = jmespath.search('@[?Name == \'' + domain_name + '\'] | [0]', domain_list)
    return domain["Threats Detected"]

  def get_server_sessions(self, domain_name):
    """
    Get server sessions for given domain name by executing api
    /api/dashboard/server-session
    Args:
      domain_name(str): name of the domain.

    Returns:
      (obj): response of /api/dashboard/server-session.
    """
    app_url = '/api/dashboard/server-session'
    domain_list = self.get_domains()
    custId = jmespath.search('listCustomers[?custName == \'' + domain_name + '\'].custId | [0]', domain_list)
    return self.execute_get_api(app_url, {"domain_id": custId, "offset": 0, "pageSize": 20})

  def get_dashboard_unregistered_apps(self):
    """
    Get unregistered apps count by executing api
    /api/dashboard/threatSummary.ws
    Args:
      domain_name(str): name of the domain.

    Returns:
      (obj): response of /api/dashboard/threatSummary.ws
    """
    api_url = '/api/dashboard/threatSummary.ws'
    resp =  self.execute_get_api(api_url)
    return resp['unauthorizedApplicationsCount']

  def get_total_registered_apps_from_domainSubdomainTiles(self):
    """
    Get total app count by executing api
    /api/dashboard/domainSubdomainTiles.ws
    Args:

    Returns:
      (obj): total registered app count
    """
    api_url = '/api/dashboard/domainSubdomainTiles.ws'
    domain_list = self.execute_get_api(api_url)
    total = 0
    for domain in domain_list:
      total += int(domain['Registered Applications'])
      logger.info('Registered apps total so far = %s' % total)
    return total

  def get_total_domains_from_domainSubdomainTiles(self):
    """
    Get number of domains by from domainSubdomainTiles by executing api
    /api/dashboard/domainSubdomainTiles.ws
    
    Args:

    Returns:
      (obj): number of domains
    """
    api_url = '/api/dashboard/domainSubdomainTiles.ws'
    domain_list = self.execute_get_api(api_url)
    return len(domain_list)

  def verify_dashboard_apps_count(self):
    disc_apps_list = self.get_all_discovered_apps()
    disc_apps_cnt = int(disc_apps_list['totalRows'])
    dashboard_unreg_apps_list = self.get_dashboard_unregistered_apps()
    dashboard_unreg_apps_cnt = int(dashboard_unreg_apps_list)
    BuiltIn().should_be_equal(disc_apps_cnt, dashboard_unreg_apps_cnt, 'Total Unregisted Apps Mismatched between threatSummary.ws and application apis')
    all_reg_apps_list = self.get_all_registered_apps()
    all_reg_apps_cnt = int(all_reg_apps_list['totalRows'])
    logger.info('all_reg_apps_cnt = %s' % all_reg_apps_cnt)
    total1 = all_reg_apps_cnt + disc_apps_cnt
    total2 = int(self.get_total_registered_apps_from_domainSubdomainTiles())
    BuiltIn().should_be_equal(total1, total2, 'Total Apps Count Mismatched between domainSubdomainTiles, threatSummary.ws and application apis')

  def get_application_summary(self):
    """
    Get summary of application by executing api
    /api/dashboard/threatSummary.ws

    Args:

    Returns:
      (obj): response of /api/dashboard/applicationSummary.ws
    """
    api_url = '/api/dashboard/applicationSummary.ws'
    resp =  self.execute_get_api(api_url)
    return resp

  def verify_dashboard_domain_count(self):
    """
    Verifies if domain count between applicationSummary.ws and domainSubdomainTile.ws matches
    Fails if they do not match
    """
    app_summary = self.get_application_summary()
    domain_cnt1 = int(app_summary['customerCount'])
    domain_cnt2 = self.get_total_domains_from_domainSubdomainTiles()
    BuiltIn().should_be_equal(domain_cnt1, domain_cnt2, 'Total Domains reported mismatched between domainSubdomainTiles and applicationSummary.ws apis')

  def create_report(self, report_type, report_format, domain, sub_domain, ip_address):
    """
    Creates Report and returns create report response executing get api
    /api/report/create.ws
    Args:
      report_type(str):     type of the report to be created
      report_format(str):   format of the report to be created
      domain(str):          name of the domain
      sub_domain(str):      name of the subdomain
      ip_address(str):      ip address of the VM

    Returns:
      (obj): response of /api/report/create.ws.
    """
    api_url = '/api/report/backend/create.ws'
    create_report_json_request = self.createReport
    
    if report_type in ('Application_Details', 'Application_Forensic'):
      create_report_json_request['dataIP'] = ip_address
      create_report_json_request['managementIP'] = ip_address
    elif report_type in ('Attacked_Applications_Details', 'Secure_Application_Policy_Details'):
      create_report_json_request['dataIP'] = ip_address
    elif 'PCRE' in report_type:
      if report_type in ('PCRE_Attacking_Clients_Sessions', 'PCRE_Attacking_Clients_Stats_By_Apps',
                         'PCRE_Attacking_Clients_Stats'):
        create_report_json_request['dataIP'] = ip_address
        create_report_json_request['managementIP'] = ip_address
      elif report_type in ('PCRE_Affected_Server_Sessions_Details', 'PCRE_Affected_Server_Stats_By_Apps',
                         'PCRE_Affected_Server_Stats_Details'):
        create_report_json_request['dataIP'] = ip_address

    self.get_domains()
    sub_domains = self.get_sub_domains_of(domain)
    create_report_json_request['reportType'] = report_type
    create_report_json_request['reportFormate'] = report_format
    custId = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custId | [0]', self.domains)
    deptId = jmespath.search('listDepartments[?deptName == \'' + sub_domain + '\'].deptId | [0]', sub_domains)
    create_report_json_request['cid'] = custId
    create_report_json_request['did'] = deptId

    # generate reports from one-week period, to address potential timezone differences between orchestrator
    # and test runner machine make sure that period of time is longer and includes the day of tomorrow
    tomorrow_dt = datetime.now() + timedelta(days=1)
    tomorrow_timestamp = int(round(tomorrow_dt.timestamp()))
    tomorrow_timestamp *= 1000
    create_report_json_request['reportToDate'] = tomorrow_timestamp
    six_days_ago_dt = datetime.now() + timedelta(days=-6)
    six_days_ago_timestamp = int(round(six_days_ago_dt.timestamp()))
    six_days_ago_timestamp *= 1000
    create_report_json_request['reportFromDate'] = six_days_ago_timestamp

    # base64 encoding of json request
    logger.info(f'create_report_json_request: {create_report_json_request}')
    create_report_json_request_bytes = json.dumps(create_report_json_request).encode('ascii')
    create_report_request_bytes = base64.b64encode(create_report_json_request_bytes)
    create_report_request = create_report_request_bytes.decode('ascii')
    create_report_request = "p=" + create_report_request
    logger.info(f'create_report_request: {create_report_request}')

    create_report_response = self.execute_get_api(api_url, create_report_request)
    return create_report_response

  def create_report_application_model(self, report_type, report_format, model_type, domain, sub_domain):
    """
    Creates Application Model Report and returns create report response executing get api
    /api/report/create.ws
    Args:
      report_type(str):     type of the report to be created
      report_format(str):   format of the report to be created
      model_type(str):      application model type of the report to be created
      domain(str):          name of the domain
      sub_domain(str):      name of the subdomain

    Returns:
      (obj): response of /api/report/create.ws.
    """
    api_url = '/api/report/backend/create.ws'
    create_report_json_request = self.createReportApplicationModel

    self.get_domains()
    sub_domains = self.get_sub_domains_of(domain)
    create_report_json_request['reportType'] = report_type
    create_report_json_request['reportFormate'] = report_format
    create_report_json_request['modelType'] = model_type
    custId = jmespath.search('listCustomers[?custName == \'' + domain + '\'].custId | [0]', self.domains)
    deptId = jmespath.search('listDepartments[?deptName == \'' + sub_domain + '\'].deptId | [0]', sub_domains)
    create_report_json_request['cid'] = custId
    create_report_json_request['did'] = deptId

    # generate reports from one-day period, to address potential timezone differences between orchestrator
    # and test runner machine make sure that period of time is longer and includes the day of tomorrow
    tomorrow_dt = datetime.now() + timedelta(days=1)
    tomorrow_timestamp = int(round(tomorrow_dt.timestamp()))
    tomorrow_timestamp *= 1000
    create_report_json_request['reportToDate'] = tomorrow_timestamp
    yesterday_dt = datetime.now() + timedelta(days=-1)
    yesterday_timestamp = int(round(yesterday_dt.timestamp()))
    yesterday_timestamp *= 1000
    create_report_json_request['reportFromDate'] = yesterday_timestamp

    # base64 encoding of json request
    logger.info(f'create_report_json_request: {create_report_json_request}')
    create_report_json_request_bytes = json.dumps(create_report_json_request).encode('ascii')
    create_report_request_bytes = base64.b64encode(create_report_json_request_bytes)
    create_report_request = create_report_request_bytes.decode('ascii')
    create_report_request = "p=" + create_report_request
    logger.info(f'create_report_request: {create_report_request}')

    create_report_response = self.execute_get_api(api_url, create_report_request)
    return create_report_response

  def verify_report_generation_started(self, report_type, expected_response, create_report_response):
    """
    Verifies if report generation started successfully.
    Fails if report was not created successfully (i.e. contents of create report response do not match expected value).
    Args:
      report_type(str):             type of the report that was created
      expected_response(str):       expected contents of create report response
      create_report_response(str):  response of /api/report/create.ws
    """

    logger.info(f'Expected {expected_response} in {create_report_response}')
    if expected_response in create_report_response:
      logger.info(f'{expected_response} found in {create_report_response}')
    else:
      logger.info(f'Failed to find {expected_response} in {create_report_response}')
    BuiltIn().should_contain(create_report_response, expected_response,
                             f'FAIL: {report_type} was not generated successfully.')

  def get_report_generation_notification(self, report_name):
    """
    Gets a notification about report generation of the desired report name from all notifications available
    on Orchestrator instance
    Args:
      report_name(str):         name of the report for which we want to get report generation notification

    Returns:
      (str): report_filename:   name of .csv report file if report generation notification contains report_filename,
                                otherwise returns None
    """
    logger.info(f'Starting to look for report generation notification for {report_name} report.')
    report_filename = None
    is_data_found = True
    timeout = 60  # [seconds] - timeout defining maximum period of time for obtaining report generation notification
    timeout_start = time.time()
    while time.time() < timeout_start + timeout:
      raw_response = self.view_notifications()
      for index, item in enumerate(raw_response):
        if item['notificationMsg'] is None:
          logger.info(f'Failed to find report generation notification for {report_name} report.')
          continue
        elif report_name in item['notificationMsg']:
          if report_name == 'Application Details':
            if 'Attacked Application Details' in item['notificationMsg'] or \
                    'Discovered Application Details' in item['notificationMsg']:
              continue
          logger.info(f'Found report generation notification for {report_name} report.')
          logger.info(f'Report generation notification for {report_name} report: {item}')
          if 'generated successfully' in item['notificationMsg']:
            report_filename = re.search("download='(.*)'>Click here</a> to download.", item['notificationMsg'])
            report_filename = report_filename.group(1)
            logger.info(f'report_filename: {report_filename}')
          elif f'No data found for {report_name}' in item['notificationMsg']:
            is_data_found = False
      if report_filename is not None or not is_data_found:
        # do not send view_notifications queries anymore if report was generated successfully or no data was found for
        # a given report type
        break
      else:
        time.sleep(5) # [seconds] - delay between consecutive view_notifications queries
    else:
      logger.info(f'timeout: {timeout}sec for report generation has elapsed')

    return report_filename

  def download_report(self, report_filename, report_name):
    """
    Downloads a .csv report from Orchestrator using wget.
    Fails if there is no report file to be downloaded. Also fails if return code of the wget command is not equal to 0.
    Args:
      report_filename(str):     name of the report file to be downloaded from Orchestrator API URL
      report_name(str):         name of the report to be downloaded
    """

    logger.info(f'Checking if report filename and download link for {report_name} report are found in Notifications.')
    if report_filename is not None:
      was_report_generated = True
      logger.info(f'Found report file {report_filename} and its download link for {report_name} report in Notifications.')
    else:
      was_report_generated = False
      logger.info(f'Failed to find report file {report_filename} and its download link for {report_name} '
                  f'report in Notifications.')
    BuiltIn().should_be_true(was_report_generated,
                             f'Failed to generate {report_name} report. There is no report file to be downloaded')

    # create orchestrator_reports folder for .csv report files
    download_dir = os.path.join(os.getcwd(), 'orchestrator_reports')
    os.makedirs(download_dir, exist_ok=True)

    # compose a wget command to be used for downloading report file from Orchestrator API URL
    api_url = f'/api/report/downloads/{report_filename}'
    endpoint = base_url + api_url
    logger.info(f'Endpoint of report to be downloaded: {endpoint}')
    wget_command = \
      f'-d --no-check-certificate --header="Authorization: Bearer {self.access_token}" -P {download_dir} {endpoint}'
    wget_rc = os.system(f'wget {wget_command}')
    logger.info(f'"wget {wget_command}" command completed with the following return code: {wget_rc}')
    BuiltIn().should_be_equal_as_integers(wget_rc, 0, f'Failed to download report using wget command: {wget_command}')

  def verify_report_was_downloaded(self, report_filename):
    """
    Verifies if report file was downloaded successfully from Orchestrator API URL
    Fails if the report file downloaded from Orchestrator is not present in orchestrator_reports folder or if the size
    of the downloaded report file is not greater than 0.
    Args:
      report_filename(str):     name of the report file that has been downloaded from Orchestrator API URL
    """
    download_dir = os.path.join(os.getcwd(), 'orchestrator_reports')
    report_path = os.path.join(download_dir, report_filename)

    logger.info(f'Checking if {report_path} exists.')
    if os.path.exists(report_path):
      logger.info(f'Report file {report_filename} found in {download_dir}')
    else:
      logger.info(f'Failed to find report file {report_filename} in {download_dir}')
    logger.info(f'Checking if size of {report_path} is larger than zero.')
    if os.path.getsize(report_path) > 0:
      logger.info(f'Size of report file {report_path} is larger than zero. '
                  f'Actual report file size: {os.path.getsize(report_path)}')
    else:
      logger.info(f'Size of report file {report_path} is not larger than zero. '
                  f'Actual report file size: {os.path.getsize(report_path)}')

    if os.path.exists(report_path) and os.path.getsize(report_path) > 0:
      was_report_file_downloaded = True
    else:
      was_report_file_downloaded = False

    BuiltIn().should_be_true(was_report_file_downloaded, f'Failed to download report file: {report_filename}')


if __name__ == "__main__":
  aClient = AvocadoAutomation('192.168.100.186')
  aClient.add_domain("testDomain5")
  aClient.add_subdomain('testSubDomain1', 'testDomain5')
  aClient.create_register_plugin('test', True, 'testDomain5', 'testSubDomain1', False)
  # create_register_plugin(self, name, enabled, domain, subDomain, executionMode):

  # print(aClient.get_orch_version())
  # print(aClient.verify_dashboard_domain_count())
  # print(aClient.get_application_summary())
  # print(aClient.verify_dashboard_apps_count())
  # aClient.get_all_discovered_apps()
  # aClient.get_all_registered_apps()

  # print(aClient.verify_app_is_discovered_on_host_from_tenancy('192.168.100.204', 'mysqld',  ))
  # aClient.enable_pcre_rule('PCRE2_SQLi_192.168.102.203', 942160)
  # print(aClient.delete_user('manoj'))
  # print(aClient.create_user('andrzej','Avocado_protect@21'))
  # print(aClient.verify_user_is_added('andrzej'))
  # print(aClient.login_for_first_time('andrzej','Avocado_protect@21','Avocado_protect@20'))
  # print(aClient.login_into_orchestrator_as('andrzej'))
  # print(aClient.get_domains())
  # print(aClient.register_app_from_tenancy('192.168.102.202', 'python2.7','mysql_192-168-102-202','sub_mysql_192-168-102-202'))
  # print(aClient.protect_app_from_tenancy('192.168.102.202', 'python2.7','mysql_192-168-102-202','sub_mysql_192-168-102-202'))
  # print(aClient.allow_app_from_tenancy('192.168.102.202', 'python2.7','mysql_192-168-102-202','sub_mysql_192-168-102-202'))

  # print(aClient.create_basic_policy_allow_both_domains('Test2_192.168.102.201','192.168.102.201','java','allow','mirror','tomcat_192-168-102-201','sub_tomcat_192-168-102-201','192.168.102.202', 'mysqld','mysql_192-168-102-202','sub_mysql_192-168-102-202' ))
  # print(aClient.create_basic_policy_from_all_domain('Test_192.168.102.201','192.168.102.201','java','allow','mirror','tomcat_192-168-102-201','sub_tomcat_192-168-102-201'))
  # aClient.delete_discovered_app_from_tenancy('192.168.102.201', 'python2.7', 'mysql', 'sub_mysql')
  # print(aClient.get_application_policy_by_name('Basic_mysql_mysqld_192.168.102.201'))
  # print(aClient.create_basic_policy_for_unsecure_domain('Basic_mysql_mysqld_192.168.102.201','192.168.100.174','mysql','allow','mirror','mysql','sub_mysql'))
  # print(aClient.delete_client('192.168.100.178'))
  # aClient.suspend_policy_and_verify('Basic_NS_SAP1')
  # aClient.delete_policy_and_verify('Basic_NS_SAP1','Policy is active. Cannot perform the requested operation.')

  # aClient.create_basic_policy('p2','192.168.100.149','java','left','drop','mirror','tomcat','sub_tomcat')
  # aClient.create_basic_policy('p3','192.168.100.149','java','left','allow','mirror','tomcat','sub_tomcat')
  # aClient.schedule_policy_always('p3')

  # aClient.verify_that_the_policy_is_created('Basic_NS_SAP1')
  # aClient.get_discovered_apps_from_tenancy('tomcat','sub_tomcat')
  # print(aClient.get_server_for_appid(4))
  
  # print(aClient.register_app_from_tenancy('192.168.100.149', 'java','tomcat','sub_tomcat'))
  # print(aClient.allow_app_from_tenancy('192.168.100.149', 'java','tomcat','sub_tomcat'))
  # print(aClient.protect_app_from_tenancy('192.168.100.149', 'java','tomcat','sub_tomcat'))
  # print(aClient.delete_registered_app_from_tenancy('192.168.100.149', 'java', 'tomcat','sub_tomcat'))
  # print(aClient.get_registered_apps_from_tenancy('tomcat','sub_tomcat'))

  # aClient.get_clients()
  # aClient.get_packages()
 
  # print(aClient.get_active_registered_app_from_tenancy_on_host('192.168.100.149', 'java', 'tomcat', 'sub_tomcat'))
  # aClient.create_basic_policy('helloWorld6','mysql','mysql','sub_mysql','mysql','mysql','sub_mysql','bidirection','allow','mirror')
  # aClient.schedule_policy('helloWorld6')
  # aClient.delete_client('manoj')
  # aClient.create_client_manual_install('manoj', True, 'tomcat', 'sub_tomcat', True)
  # aClient.get_packages()
  # aClient.create_client_push_install('manoj', True, 'tomcat', 'sub_tomcat',
  #                                     True, 'Linux', 'Ubuntu', '16.0',
  #                                     '192.168.100.178', 'root', 'Avocado@2020')
  # aClient.set_polling_interval(60)
  # aClient.set_process_polling_interval(15)
  
  # print(aClient.get_all_registered_apps())
  # print(aClient.get_packages())
  # print(aClient.upload_package('Linux', 'Centos', '8.0', 'rhel8'))
  # aClient.create_client_push_install('manoj', True, 'tomcat', 'sub_tomcat',
  #                                     True, 'Linux', 'Centos', '8.0',
  #                                     '192.168.100.149', 'root', 'Avocado@2020')
  # aClient.wait_for_client_push_to_finish('manoj')

  # print(aClient.delete_package('Linux', 'Ubuntu', '16'))
  # aClient.add_domain("testDomain5")
  # aClient.add_subdomain('testSubDomain1', 'testDomain5')
  # aClient.delete_subdomain("testSubDomain1", 'testDomain5')
  # aClient.add_subdomain('testSubDomain2', 'testDomain4')
  # aClient.add_subdomain('testSubDomain3', 'testDomain4')
  # aClient.add_subdomain('testSubDomain4', 'testDomain4')
  # aClient.delete_domain("testDomain4")
  # aClient.get_sub_domains_of('testDomain4')