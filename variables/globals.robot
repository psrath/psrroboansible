*** Variables ***
${base_url}          https://${orch_ip}:8443/orchestrator
${orch_admin}        administrator
${orch_pwd}          Avocado_protect@20
${auth}              Basic YW5ndWxhci11aTphbmd1bGFyLXNlY3JldA==
@{used_ips}          @{EMPTY}
@{ips_in_deploy}     @{EMPTY}
&{instance_cnt}      &{EMPTY}
${PREFIX}            demo
${BUILD_NUM}         latest
${ORCH_BUILD_NUM}    latest
${NEW_BUILD}         ${FALSE}
${DEPLOY_ORCH}       ${EMPTY}

*** Settings ***
Variables  ../variables/common.yml
Library   Collections
Library   String
Library   RequestsLibrary
Library   JSONLibrary
Library   AvocadoListener
Library   AvocadoAutomation
Library   AvocadoAnsibleRunner
Library   AvocadoUtils
Library   AvocadoBuildUtils   ${NEW_BUILD}
Library   pabot.PabotLib
Resource  ../keywords/orch-api-keywords.robot

