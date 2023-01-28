from distutils.command.build import build
import os
import time
import jenkins
import yaml
from retry import retry
from robot.libraries.BuiltIn import BuiltIn
import requests
import urllib3
import shutil
# from robot.api import logger
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
os.environ['PYTHONHTTPSVERIFY'] = '0'

class AvocadoBuildUtils:
  __version__ = '0.1'
  ROBOT_LIBRARY_DOC_FORMAT = 'reST'
  ROBOT_LIBRARY_SCOPE = 'GLOBAL'

  def __init__(self, major_release , build_num=None, run_standalone = False ):
    self.run_standalone = run_standalone
    self.build_num = build_num
    self.major_release = 'Release_'+major_release.replace('.', '_')


  def get_plugins_jenkins_server(self, build_system='new'):
    if self.run_standalone:
      vars = yaml.safe_load(open('variables/common.yml', 'r'))
      conf = vars['plugins_jenkins'][build_system]
    else:
      conf = BuiltIn().get_variable_value('${plugins_jenkins}', 'NOT FOUND')
      self.build_num = BuiltIn().get_variable_value('${BUILD_NUM}', 'latest')
      conf = conf[build_system]
      BuiltIn().should_not_be_equal(conf,'NOT FOUND', 'Unable to load jenkins server configuration')
    print(conf)
    job = conf['job'][self.major_release]
    url = conf['url']
    user = conf['user']
    pwd = conf['pwd']
    params = conf['params']
    self.download_dir = conf['download_dir']
    artifacts = conf['artifacts']
    return AvocadoJenkins(url, user, pwd, job, params, artifacts)

  def get_orchestrator_jenkins_server(self):
    if self.run_standalone:
      vars = yaml.safe_load(open('variables/common.yml', 'r'))
      conf = vars['orchestror_jenkins']
    else:
      conf = BuiltIn().get_variable_value('${orchestror_jenkins}', 'NOT FOUND')
      self.build_num = BuiltIn().get_variable_value('${BUILD_NUM}', 'latest')
      BuiltIn().should_not_be_equal(conf,'NOT FOUND', 'Unable to load jenkins server configuration')
    print(conf)
    url = conf['url']
    user = conf['user']
    pwd = conf['pwd']
    job = conf['job'][self.major_release]
    params = conf['params']
    self.download_dir = conf['download_dir']
    artifacts = conf['artifacts']
    return OrchestratorJenkins(url, user, pwd, job, params, artifacts)

  def download_orchestrator_build(self, orch_build='latest'):
    jenkins = self.get_orchestrator_jenkins_server()
    self.build_num = orch_build
    if self.build_num == 'latest':
      lsb, ls_artifacts = jenkins.get_last_successful_build_artifacts()
    else:
      bld_status = jenkins.get_build_status(int(self.build_num))
      BuiltIn().should_be_equal(bld_status, 'SUCCESS', 'Given Build# %s was not SUCCESSFUL, hence FAILING' % self.build_num)
      lsb, ls_artifacts = jenkins.get_build_artifacts(int(self.build_num))

    if(os.path.exists(self.download_dir + '/' + str(lsb))):
      print('Last successful build %s already downloaded, will reuse' % str(lsb))
      if not self.run_standalone:
        pli = BuiltIn().get_library_instance('pabot.PabotLib')
        pli.set_parallel_value_for_key('orch_build_num', str(lsb))
      return
    for artifact in ls_artifacts:
      download_dir = self.download_dir + '/' + str(lsb) + '/'
      self.download_artifact(artifact['url'], download_dir)
    if not self.run_standalone:
      pli = BuiltIn().get_library_instance('pabot.PabotLib')
      pli.set_parallel_value_for_key('orch_build_num', str(lsb))

  def download_plugins_build(self, build_system='new'):
    print('Using major_release : ', self.major_release)
    if build_system=='new':
      jenkins = self.get_plugins_jenkins_server()
      if self.build_num == 'latest':
        lsb, ls_artifacts = jenkins.get_last_successful_build_artifacts()
      else:
        bld_status = jenkins.get_build_status(int(self.build_num))
        BuiltIn().should_be_equal(bld_status, 'SUCCESS', 'Given Build# %s was not SUCCESSFUL, hence FAILING' % self.build_num)
        lsb, ls_artifacts = jenkins.get_build_artifacts(int(self.build_num))
      BuiltIn().set_global_variable('${BUILD_NUM}', str(lsb))
      with open("plugin_version","w") as f:
        f.writelines([str(lsb)])
        f.flush()
      pli = BuiltIn().get_library_instance('pabot.PabotLib')
      pli.set_parallel_value_for_key('build_num', str(lsb))
      if(os.path.exists(self.download_dir + '/' + str(lsb))):
        print('Last successful build %s already downloaded, will reuse' % str(lsb))
        return
      for artifact in ls_artifacts:
        if  artifact['os'] :
          download_dir = self.download_dir + '/' + str(lsb) + '/' + artifact['os']
        else:
          download_dir = self.download_dir + '/' + str(lsb) + '/'
        self.download_artifact(artifact['url'], download_dir)
      for artifact in ls_artifacts:
        if  artifact['os'] :
          installer = self.download_dir + '/' + str(lsb) + '/' + 'install_adpl.sh' 
          dest_path = self.download_dir + '/' + str(lsb) + '/' + artifact['os'] + '/' + 'install_adpl.sh' 
          shutil.copyfile(installer, dest_path)
    else:
      build_systems = ['centos7','ubuntu16','ubuntu18','rhel8']
      for build_system in build_systems:
        jenkins = self.get_plugins_jenkins_server(build_system)
        if self.build_num == 'latest':
          lsb, ls_artifacts = jenkins.get_last_successful_build_artifacts()
          print("--------------->",ls_artifacts)
        else:
          bld_status = jenkins.get_build_status(int(self.build_num))
          BuiltIn().should_be_equal(bld_status, 'SUCCESS', 'Given Build# %s was not SUCCESSFUL, hence FAILING' % self.build_num)
          lsb, ls_artifacts = jenkins.get_build_artifacts(int(self.build_num))
        # if not self.run_standalone:
        #   BuiltIn().set_global_variable('${BUILD_NUM}', str(lsb))
        #   DISTRO_BUILD_NUM = build_system + '_BUILD_NUM'
        #   BuiltIn().set_global_variable('${DISTRO_BUILD_NUM}', str(lsb))
        #   print("--------------->", DISTRO_BUILD_NUM, '=', str(lsb))

        with open("plugin_version","w") as f:
          f.writelines([str(lsb)])
          f.flush()

        with open(build_system + "_version","w") as f:
          f.writelines([str(lsb)])
          f.flush()
        
        if not self.run_standalone:
          pli = BuiltIn().get_library_instance('pabot.PabotLib')
          pli.set_parallel_value_for_key('build_num', str(lsb))
          DISTRO_BUILD_NUM = build_system + '_build_num'
          print('DISTRO_BUILD_NUM=',DISTRO_BUILD_NUM)
          BuiltIn().set_global_variable('${'+DISTRO_BUILD_NUM+'}', str(lsb))
          pli.set_parallel_value_for_key(DISTRO_BUILD_NUM,str(lsb))
          print("--------------->", DISTRO_BUILD_NUM, '=', str(lsb))

        if(os.path.exists(self.download_dir + '/' + str(lsb) + '/' + build_system)):
          print('Last successful build %s already downloaded, will reuse' % str(lsb))
          continue
        for artifact in ls_artifacts:
          if  artifact['os'] :
            download_dir = self.download_dir + '/' + str(lsb) + '/' + artifact['os']
          else:
            download_dir = self.download_dir + '/' + str(lsb) + '/'
          self.download_artifact(artifact['url'], download_dir)
        for artifact in ls_artifacts:
          if  artifact['os'] :
            installer = self.download_dir + '/' + str(lsb) + '/' + 'install_adpl.sh' 
            dest_path = self.download_dir + '/' + str(lsb) + '/' + artifact['os'] + '/' + 'install_adpl.sh' 
            shutil.copyfile(installer, dest_path)

  def download_artifact(self, artifact_url, download_dir):
    print('artifact_url = %s' % artifact_url)
    if artifact_url.find('/'):
      filename = artifact_url.rsplit('/', 1)[1]
      print('Downloading %s under %s' % (filename, download_dir))
      filename = download_dir + '/' + filename
      if not os.path.exists(download_dir):
        os.makedirs(download_dir)
      if artifact_url :
        try:
          response = requests.head(artifact_url,verify=False,timeout=5,allow_redirects=True)
          header = response.headers
          print(header)
          content_length = header.get('content-length', None)
          print('Expected File Size = %s' % content_length)
          response = requests.get(artifact_url, verify=False, timeout=60, allow_redirects=True)
          response.raise_for_status()
          if os.path.exists(filename) :
            os.remove(filename)
          open(filename, 'wb').write(response.content)
          fs = os.path.getsize(filename)
          print('Downloaded File Size = %s' % str(fs))
          BuiltIn().should_be_equal_as_integers(fs, int(content_length), 'Incomplete Download of %s' % filename)
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

class AvocadoJenkins:
  def __init__(
      self,
      jenkins_url,
      jenkins_user,
      jenkins_pwd,
      jenkins_job,
      jenkins_params=None,
      artifacts=None,
    ):
    self.parameters = jenkins_params
    print(jenkins_url)
    print(jenkins_user)
    print(jenkins_pwd)
    self.jenkins_server = jenkins.Jenkins(jenkins_url, username=jenkins_user, password=jenkins_pwd)
    print('Connected to Jenkins version %s ' %  self.jenkins_server.get_version())
    vers = self.jenkins_server.get_version()
    self.jenkins_job = jenkins_job
    self.artifacts = artifacts

  def build_job(self):
    running, build_num = self.is_any_build_running()
    if not running:
      # print(self.jenkins_server.get_job_info(self.jenkins_job))
      self.build_number = self.jenkins_server.get_job_info(self.jenkins_job)['nextBuildNumber']
      print("Build Number = %s" % self.build_number)
      self.queue_item = self.jenkins_server.build_job(self.jenkins_job, self.parameters)
      print("queue_item = %s" % self.queue_item)
      time.sleep(10)
    else:
      self.build_number = build_num
      print('Job already running')

  def get_last_successful_build_num(self):
    job_info = self.jenkins_server.get_job_info(self.jenkins_job)
    return job_info['lastSuccessfulBuild']['number']

  def get_build_status(self, build_num):
    build_info = self.jenkins_server.get_build_info(self.jenkins_job, build_num)
    print(build_info)
    result = build_info['result']
    return result

  def get_build_artifacts(self, build_num):
    build = self.jenkins_server.get_build_info(self.jenkins_job, build_num)
    url = build['url']
    print('Fetching build artifacts from %s' % url)
    print(self.artifacts)
    print(build['artifacts'])
    for artifact in build['artifacts']:
      for wanted_artifact in self.artifacts:
        if wanted_artifact['foldername'] in artifact['relativePath'] \
           and \
           wanted_artifact['packageExtn'] in artifact['relativePath'] :
          wanted_artifact['url'] = url + '/artifact/' + artifact['relativePath']
    return build_num, self.artifacts

  def get_last_successful_build_artifacts(self):
    job_info = self.jenkins_server.get_job_info(self.jenkins_job)
    build_num = job_info['lastSuccessfulBuild']['number']
    url = job_info['lastSuccessfulBuild']['url']
    print('Last Sucessful Build Number %d' % build_num)
    print('Last Sucessful Build Url %s' % url)
    return self.get_build_artifacts(build_num)

class OrchestratorJenkins:
  def __init__(
      self,
      jenkins_url,
      jenkins_user,
      jenkins_pwd,
      jenkins_job,
      jenkins_params=None,
      artifacts=None,
    ):
    self.parameters = jenkins_params
    self.jenkins_server = jenkins.Jenkins(jenkins_url, username=jenkins_user, password=jenkins_pwd)
    print('Connected to Jenkins version %s ' %  self.jenkins_server.get_version())
    vers = self.jenkins_server.get_version()
    self.jenkins_job = jenkins_job
    self.artifacts = artifacts

  def get_build_status(self, build_num):
    build_info = self.jenkins_server.get_build_info(self.jenkins_job, build_num)
    print(build_info)
    result = build_info['result']
    return result

  def get_last_successful_build_num(self):
    job_info = self.jenkins_server.get_job_info(self.jenkins_job)
    return job_info['lastSuccessfulBuild']['number']

  def get_last_successful_build_artifacts(self):
    job_info = self.jenkins_server.get_job_info(self.jenkins_job)
    self.build_num = job_info['lastSuccessfulBuild']['number']
    url = job_info['lastSuccessfulBuild']['url']
    print('Last Sucessful Build Number %d' % self.build_num)
    print('Last Sucessful Build Url %s' % url)
    return self.get_build_artifacts(self.build_num)

  def get_build_artifacts(self, build_num):
    build = self.jenkins_server.get_build_info(self.jenkins_job, build_num)
    url = build['url']
    print('Fetching build artifacts from %s' % url)
    print(len(build['artifacts']))
    for artifact in build['artifacts']:
      print(artifact)
      for wanted_artifact in self.artifacts:
        print(wanted_artifact['foldername'])
        print(wanted_artifact['packageExtn'])
        if wanted_artifact['foldername'] in artifact['relativePath'] \
           and \
           wanted_artifact['packageExtn'] in artifact['relativePath'] :
          print('came here')
          wanted_artifact['url'] = url + '/artifact/' + artifact['relativePath']
    print(self.artifacts)
    return build_num, self.artifacts

if __name__ == '__main__':
  abu = AvocadoBuildUtils(major_release='2.5', build_num='latest', run_standalone=True)
  #print(abu.download_plugins_build('centos7'))
  print(abu.download_orchestrator_build())
  # aj = AvocadoJenkins('http://192.168.100.25:8080/','admin','avcd@94539','ADPL-2.4-Ubuntu16')
  # print(art)
