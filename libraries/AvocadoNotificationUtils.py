import os
import time
import jenkins
import yaml
from retry import retry
from robot.libraries.BuiltIn import BuiltIn
import requests
import urllib3
import shutil
from  copy import deepcopy
import json
import xml.etree.ElementTree as ET
# from robot.api import logger
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
os.environ['PYTHONHTTPSVERIFY'] = '0'

class AvocadoNotificationUtils:
  OS_TAGS = {
    "centos7":"CentOS 7", 
    "ol7": "Oracle Linux 7", 
    "rhel7":"RHEL 7", 
    "rhel84" : "RHEL 8.4", 
    "ubuntu16": "Ubuntu 16.04", 
    "ubuntu18": "Ubuntu 18.04",
    "WindowsServer2012R2SERVERSTANDARD": "Windows 2012 R2 STANDARD",
    "WindowsServer2016SERVERSTANDARD": "Windows 2016 STANDARD"
  }

  def __init__(self, run_standalone = False ):
    self.run_standalone = run_standalone

  def add_card_contents(self, card_contents):
    parent_job = os.environ.get('P_JOB_NAME', None)
    parent_bld = os.environ.get('P_BUILD_NUM', None)
    parent_url = os.environ.get('P_URL', None)
    jenkins_home  = os.environ.get('JENKINS_HOME', None)
    parent_workspace = os.environ.get('P_WORKSPACE', None)
    if not parent_job or not parent_bld or not parent_url:
      print('Parent job paramters empty')
      exit(-1)
    print('Triggered from -> %s' % parent_job)
    print('Triggered from build number -> %s' % parent_bld)
    print('Parent job can be found @ %s' % parent_url)
    output_xml = jenkins_home + '/jobs/' + parent_job + '/builds/' + str(parent_bld) + '/robot-plugin/output.xml'
    tree = ET.parse(output_xml)
    root = tree.getroot()
    total =  root.find('./statistics/total/stat')
    tot_tests = int(total.attrib['pass']) + int(total.attrib['fail']) + int(total.attrib['skip']) 
    card_contents["body"][0]["items"][0]["facts"].append({"title":"Total Tests:", "value": tot_tests})
    card_contents["body"][0]["items"][0]["facts"].append({"title":"Pass:", "value": total.attrib['pass']})
    card_contents["body"][0]["items"][0]["facts"].append({"title":"Fail:", "value": total.attrib['fail']})
    card_contents["body"][0]["items"][0]["facts"].append({"title":"Skipped:", "value": total.attrib['skip']})


    for item in root.findall('./statistics/tag/stat'):
      print('Stats Item -> %s' % item.text)
      if item.text in self.OS_TAGS.keys():
        print('Stats %s' % str(item))
        card_contents["body"].append(deepcopy(card_contents["body"][1]))
        colSet =  card_contents["body"][len(card_contents["body"])-1]
        colSet["columns"][0]["items"][0]["text"] = self.OS_TAGS[item.text]
        colSet["columns"][1]["items"][0]["text"] = item.attrib['pass']
        colSet["columns"][2]["items"][0]["text"] = item.attrib['fail']
        colSet["columns"][3]["items"][0]["text"] = item.attrib['skip']

    for col in card_contents["body"][1]["columns"]:
      col["items"][0]["weight"] = 'Bolder'

    action = {
            "type": "ActionSet",
            "actions": [
                {
                    "type": "Action.OpenUrl",
                    "title": "Open Sanity Test Run",
                    "url": "%s/display/redirect" % parent_url
                    # "url": "http://192.168.100.139:8080/blue/organizations/jenkins/TestAutomation/detail/TestAutomation/592/tests"
                }
            ]
        }
    card_contents["body"].append(action)
    orch_version = 'empty'
    plugin_version = 'empty'

    with open(parent_workspace + "/orch_version") as f:
      orch_version = f.readline().strip()
    with open(parent_workspace + "/plugin_version") as f:
      plugin_version = f.readline().strip()

    card_contents["body"][0]["items"][0]["facts"][0]["value"] = orch_version
    card_contents["body"][0]["items"][0]["facts"][1]["value"] = plugin_version
    card_contents["body"][0]["items"][0]["facts"][2]["value"] = parent_bld

  def publish_notification(self):
    if self.run_standalone:
      vars = yaml.safe_load(open('variables/common.yml', 'r'))
      conf = vars['notification_details']
    else:
      conf = BuiltIn().get_variable_value('${notification_details}', 'NOT FOUND')
      BuiltIn().should_not_be_equal(conf,'NOT FOUND', 'Unable to load notification details')
    print(conf)
    connector_url = conf['connector_url']
    with open("config/AdaptiveMessage.json", encoding = 'utf-8') as f:
      message_contents = json.load(f)
    with open("config/AdaptiveCard.json", encoding = 'utf-8') as f:
      card_contents = json.load(f)
    self.add_card_contents(card_contents)
    message_contents["attachments"][0]["content"]["body"] = card_contents["body"]

    self.post_on_connector(connector_url, message_contents)

  def post_on_connector(self, connector_url, card_json):
    print('connector_url = %s' % connector_url)
    if connector_url :
      try:
        headers = {"Content-Type": "application/json"}
        response = requests.post(connector_url, headers=headers, json=card_json, verify=False, timeout=60, allow_redirects=True)
        response.raise_for_status()
      except requests.exceptions.HTTPError as errh:
        print(errh)
      except requests.exceptions.ConnectionError as errc:
        print(errc)
      except requests.exceptions.Timeout as errt:
        print(errt)
      except requests.exceptions.RequestException as err:
        print(err)
      except Exception as ex:
        print('unknown error occ' + str(ex))

if __name__ == '__main__':
  anu = AvocadoNotificationUtils(run_standalone=True)
  anu.publish_notification()
  # anu.parseXML()