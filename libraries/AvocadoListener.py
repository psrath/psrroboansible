import sys
import time
from robot.libraries.BuiltIn import BuiltIn
from robot.result.model  import TestCase as resTc
from robot.api import logger
EXECUTE = 'if-'

class AvocadoListener(object):
  ROBOT_LISTENER_API_VERSION = 3
  ROBOT_LIBRARY_SCOPE = 'TEST SUITE'

  def __init__(self):
    self.ROBOT_LIBRARY_LISTENER = self
    self.current_suite = None
    self.default_app = None
    # ms = time.time()*1000.0
    # self.outfile = open('./reports/listner-'+str(ms) +'.log' , 'w')
    # self.outfile.flush()

  def _end_test(self, test, result):
    self.listner_log(result)
    # self.listner_log('PASS = '+ str(result.passed))
    if result.status == 'PASS':
      self.listner_log('PASS')
    else:
      self.listner_log(result.message)

  def listner_log(self, message):
    message = str(message)
    logger.info(message)
    # print(message)
    self.outfile.write(message+'\n') 
    self.outfile.flush()

  def _start_suite(self, suite, result):
    caller_id = BuiltIn().get_variable_value('${CALLER_ID}', 'NOT FOUND')
    self.outfile = open('./reports/listner-' + caller_id + '.log' , 'w')
    self.outfile.flush()
    # save current suite so that we can modify it later
    self.current_suite = suite
    app_os = BuiltIn().get_variable_value('${${APP_OS}}', 'NOT FOUND')
    platform = app_os['osType']
    # osName = app_os['osName']
    # osVersion = app_os['osVersion']
    # suiteName = result.name
    # result.name =  suiteName + ' ' + osName + osVersion
    self.listner_log("Inside _start_suite")
    self.listner_log(app_os)
    self.listner_log(platform)
    # self.listner_log(result.name)
    app_on_template = []
    tcs_to_remove = []
    if platform != 'NOT FOUND':
      tcs = suite.tests
      for tc in tcs:
        self.listner_log(str(tc.tags))
        for tc_platform in tc.tags: 
          self.listner_log(tc_platform)
          if tc_platform.startswith('platform'):
            pl = tc_platform.replace('platform','')
            if pl not in [ platform, 'All'] :
              self.listner_log('Removing test case %s as it run on platform %s' % (tc, pl))
              tcs_to_remove.append(tc)
      for tc in tcs_to_remove:
        tcs.remove(tc)
      tcs_to_remove.clear()

    if app_os != 'NOT FOUND':
      BuiltIn().set_suite_variable('${APP_NAME}', app_os.default_app)
      self.listner_log('APP_NAME = %s' % app_os.default_app)
      for app in app_os.apps.keys():
        app_on_template.append(app)
      tcs = suite.tests

      for tc in tcs:
        self.listner_log(str(tc.tags))
        for tag in tc.tags:
          if tag.startswith(EXECUTE):
            app = tag.replace(EXECUTE,'')
            if not app in app_on_template:
              self.listner_log('Removing test case %s as it needs %s on current vm from ' % (tc, app) + app_os.image.vm )
              tcs_to_remove.append(tc)
      for tc in tcs_to_remove:
        tcs.remove(tc)

    app_os_str = BuiltIn().get_variable_value('${APP_OS}', 'NOT FOUND')
    self.listner_log('app_os_str = %s' % app_os_str)
    for tc in self.current_suite.tests:
      if app_os_str != 'NOT FOUND':
        if len(app_os_str.split('_')) > 1 :
          tc.tags.add(app_os_str.split('_')[1])
        else:
          os_tag = (app_os.osName + ' ' + app_os.osVersion).replace(' ', '')
          tc.tags.add(os_tag)
      self.listner_log('tags here = %s' % str(tc.tags))
      if 'orchestrator' not in tc.tags:
        kw = tc.body.create_keyword(name='Acquire Plugin')
        kw = tc.body.pop()
        tc.body.insert(0,kw)
        tc.body.create_keyword(name='Release Plugin')

# To get our class to load, the module needs to have a class
# with the same name of a module. This makes that happen:
globals()[__name__] = AvocadoListener