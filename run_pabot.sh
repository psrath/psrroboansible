echo -----------SETTING VARIABLES-----------
ARGFILE=--argumentfile
PARS=--verbose' '--pabotlib' '--pabotlibport' '8888
OTHER=--variable' 'PROXMOX:$PROXMOX' '--variable' 'orch_ip:$ORCH_IP' '--variable' 'PREFIX:$PREFIX' '--variable' 'build_num:$BUILD_NUM
ROBOTS=--outputdir' 'reports' '$SUITES
RUN_CENTOS7=
RUN_UBUNTU18=
RUN_RHEL8=
RUN_WIN12=
RUN_WIN16=

echo -----------READING INPUT PARAMETERS-----------

IFS="," read -a myarray <<< $OSes
IFS=" " read -a centosarray <<< $CENTOS7
IFS=" " read -a ubuntuarray <<< $UBUNTU18
IFS=" " read -a rhelarray <<< $RHEL8
IFS=" " read -a win12array <<< $WIN12
IFS=" " read -a win16array <<< $WIN16


echo -----------PREPARING ARGUMENT FILES COMMAND-----------


if [[ " ${myarray[*]} " =~ "CentOS7" ]]; then
    for I in "${centosarray[@]}"
    do    
        CENTOS7_COMMAND=${CENTOS7_COMMAND:+$CENTOS7_COMMAND }' '$ARGFILE$RANDOM' 'arg_files/$I
    done
    RUN_CENTOS7=$CENTOS7_COMMAND
fi


if [[ " ${myarray[*]} " =~ "Ubuntu18" ]]; then
    for I in "${ubuntuarray[@]}"
    do    
        UBUNTU18_COMMAND=${UBUNTU18_COMMAND:+$UBUNTU18_COMMAND }' '$ARGFILE$RANDOM' 'arg_files/$I
    done
    RUN_UBUNTU18=$UBUNTU18_COMMAND
fi


if [[ " ${myarray[*]} " =~ "Rhel8" ]]; then
    for I in "${rhelarray[@]}"
    do    
        RHEL8_COMMAND=${RHEL8_COMMAND:+$RHEL8_COMMAND }' '$ARGFILE$RANDOM' 'arg_files/$I
    done
    RUN_RHEL8=$RHEL8_COMMAND
fi


if [[ " ${myarray[*]} " =~ "Win2012" ]]; then
    for I in "${win12array[@]}"
    do    
        WIN12_COMMAND=${WIN12_COMMAND:+$WIN12_COMMAND }' '$ARGFILE$RANDOM' 'arg_files/$I
    done
    RUN_WIN12=$WIN12_COMMAND
fi


if [[ " ${myarray[*]} " =~ "Win2016" ]]; then
    for I in "${win16array[@]}"
    do    
        WIN16_COMMAND=${WIN16_COMMAND:+$WIN16_COMMAND }' '$ARGFILE$RANDOM' 'arg_files/$I
    done
    RUN_WIN16=$WIN16_COMMAND
fi


echo ----------- Running automation on orchestrator @ $ORCH_IP -----------

python3 -m venv myenv
source myenv/bin/activate
export PYTHONPATH=$PYTHONPATH:.:./libraries
python -m pip install --upgrade pip
pip3 install -r requirements.txt
chmod 400 ansible_runner/env/ssh_keys/*
rm -rf ansible_runner/private_data_dir/*
rm -rf reports/listner*.log


echo ----------- TRIGGERING PABOT COMMAND -----------

pabot $PARS $RUN_CENTOS7 $RUN_UBUNTU18 $RUN_RHEL8 $RUN_WIN12 $RUN_WIN16 $OTHER $ROBOTS