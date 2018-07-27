#!/bin/bash

#================================================================
#scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#printf "DBG scriptDir = $scriptDir \n"

#================================================================
helpFunc () {
    printf "./cubridcmd.sh [command [args]]\n"
    printf "    clone [repository=cub]\n"
    printf "        cub         = cubrid                            ==> repo\n"
    printf "        tt [prefix=cubrid-test] [port=2000] = cubrid -tools, -tools-internal\n"
    printf "        tc [prefix=cubrid-test] = cubrid -cases, -cases-private, -cases-private-ex\n"
    printf "    gen [Debug|Release] [instDir=../cubrid] = generate|configure cubrid ==> build\n"
    printf "    build [arg=-j5]         = build cubrid [using 5 cores]\n"
    printf "    inst [port=2000]        = install cubrid, update config files ==> inst\n"
    printf "    db [database=testdb]    = cubrid createdb testdb    ==> db\n"
    printf "    test [scenario=tcases/sql]\n"
    printf "    pull [repo=repo]        = pushd repo, git pull, popd\n"
    printf "    vg                      = valgrind ...\n"
    printf "    webconsole              = start webconsole: pushd ttools/CTP , bin/ctp.sh webconsole start , popd\n"
}

#================================================================
runCmd () {
    #echo "TR0 $@"; eval "$@"; local rc=$?
    echo "TR0 $@"
    eval "$@"
    local rc=$?
    return $rc
}

#================================================================
chkCmd () {
    runCmd "$@"
    local rc=$?
    if [ $rc -ne 0 ]
    then
        echo "ERR $rc $@"
        exit $rc
    fi
}

#================================================================
cloneFunc () {
    #1st arg is the repository alias
    local repo=${1:-cub} #default repo alias is cub
    case ${repo} in
        cub)
            runCmd "rm -rf repo"
            chkCmd "git clone https://github.com/bsolomenco/cubrid repo"
            chkCmd "pushd repo"
            chkCmd "git remote add upstream https://github.com/CUBRID/cubrid"
            chkCmd "git remote -v"
            chkCmd "git fetch"
            chkCmd "git fetch upstream"
            #chkCmd "git merge upstream/develop"
            chkCmd "popd"
            ;;
        tt)
            local prefix="${2:-t}"
            local cubPort="${3:-"2000"}"
            local haPort=$((${cubPort}+1))
            local brokerPort=$((${cubPort}+2))
            local wcPort=$((${cubPort}+3))
            runCmd "rm -rf ${prefix}tools"
            chkCmd "git clone https://github.com/CUBRID/cubrid-testtools ${prefix}tools"
            runCmd sed -i -e "s:web_port=.*:web_port="${wcPort}":"                          ${prefix}tools/CTP/conf/webconsole.conf
            runCmd sed -i -e "s:scenario=.*:scenario=${HOME}/cubrid/${prefix}cases/sql:"    ${prefix}tools/CTP/conf/sql.conf
            runCmd sed -i -e "s:cubrid_port_id=.*:cubrid_port_id="${cubPort}":"                ${prefix}tools/CTP/conf/sql.conf
            runCmd sed -i -e "s:MASTER_SHM_ID=.*:MASTER_SHM_ID="${cubPort}":"                  ${prefix}tools/CTP/conf/sql.conf
            runCmd sed -i -e "s:BROKER_PORT=.*:BROKER_PORT="${brokerPort}":"                ${prefix}tools/CTP/conf/sql.conf
            runCmd sed -i -e "s:APPL_SERVER_SHM_ID=.*:APPL_SERVER_SHM_ID="${brokerPort}":"  ${prefix}tools/CTP/conf/sql.conf
            runCmd sed -i -e "s:ha_port_id=.*:ha_port_id="${haPort}":"                      ${prefix}tools/CTP/conf/sql.conf
            runCmd sed -i -e "s:scenario=.*:scenario=${HOME}/cubrid/${prefix}cases/medium:" ${prefix}tools/CTP/conf/medium.conf
            runCmd sed -i -e "s:cubrid_port_id=.*:cubrid_port_id="${cubPort}":"                ${prefix}tools/CTP/conf/medium.conf
            runCmd sed -i -e "s:MASTER_SHM_ID=.*:MASTER_SHM_ID="${cubPort}":"                  ${prefix}tools/CTP/conf/medium.conf
            runCmd sed -i -e "s:BROKER_PORT=.*:BROKER_PORT="${brokerPort}":"                ${prefix}tools/CTP/conf/medium.conf
            runCmd sed -i -e "s:APPL_SERVER_SHM_ID=.*:APPL_SERVER_SHM_ID="${brokerPort}":"  ${prefix}tools/CTP/conf/medium.conf
            runCmd sed -i -e "s:ha_port_id=.*:ha_port_id="${haPort}":"                      ${prefix}tools/CTP/conf/medium.conf
            
            runCmd sed -i -e "s:scenario=.*:scenario=${HOME}/cubrid/${prefix}cases/isolation:" ${prefix}tools/CTP/conf/isolation.conf

            #runCmd "rm -rf ${prefix}tools-internal"
            #chkCmd "git clone https://github.com/CUBRID/cubrid-testtools-internal ${prefix}tools-internal"
            ;;
        tc)
            local prefix="${2:-t}"
            runCmd "rm -rf ${prefix}cases"
            chkCmd "git clone https://github.com/CUBRID/cubrid-testcases ${prefix}cases"
            #runCmd "rm -rf ${prefix}cases-private"
            #chkCmd "git clone https://github.com/CUBRID/cubrid-testcases-private ${prefix}cases-private"
            #runCmd "rm -rf ${prefix}cases-private-ex"
            #chkCmd "git clone https://github.com/CUBRID/cubrid-testcases-private-ex ${prefix}cases-private-ex"
            ;;
        *)
            printf "ERR unknown repository: ${repo}\nSYNTAX: clone <repository>\n"
            ;;
    esac
}

#================================================================
genFunc () {
    local type=${1:-"Debug"}
    local instDir=${2:-${CUBRID}}
    local generator="???"
    printf "DBG platform/OS: ${OSTYPE}\n"
    case ${OSTYPE} in
        linux*) #assume Linux
            generator='"Unix Makefiles"'
            ;;
        msys*) #assume mingw on Windows
            generator='"Visual Studio 15 2017 Win64"'
            ;;
        *)
            printf "ERR unknown platform/OS: ${OSTYPE}\n"
            ;;
    esac
    local unitTest=${3:-"OFF"}
    runCmd "rm -rf build"
    chkCmd "mkdir build"
    chkCmd "pushd build"
    chkCmd "cmake -G ${generator} -DCMAKE_BUILD_TYPE=${type} -DCMAKE_INSTALL_PREFIX=${instDir} -DUNIT_TESTS=${unitTest} ../repo"
    chkCmd "popd"
}

#================================================================
buildFunc () { #use -j7 on Linux to build using 5 CPU cores
    case ${OSTYPE} in
        linux*) #assume Linux
            local arg=${1:-"-j7"}
            ;;
        msys*) #assume mingw on Windows
            local arg=${1:-""}
            ;;
        *)
            local arg=${1:-""}
            ;;
    esac
    chkCmd "pushd build"
    printf "DBG platform/OS: ${OSTYPE}\n"
    chkCmd "cmake --build . -- ${arg}"
    chkCmd "popd"
}

#================================================================
build2Func () {
    chkCmd "cp build/sa/Debug/cubridsa.dll build/util/Debug/"
    chkCmd "cp build/sa/Debug/cubridsa.pdb build/util/Debug/"
}

#================================================================
instFunc () {
    #stop everything before install
    runCmd "cubrid service stop"
    runCmd "cubrid server stop testdb"

    printf "DBG backup configuration files...\n"
    runCmd "cp inst/conf/cubrid_ha.conf         ."

    chkCmd "pushd build"
    chkCmd "cmake --build . --target install"
    chkCmd "popd"

    local cubPort=${1:-"2000"}      #cubrid base port
    local qebPort=$((${cubPort}+1)) #query_editor broker port
    local b1bPort=$((${cubPort}+2)) #%BROKER1 broker port
    local regexp='"/^\[common\]/        , /\[/{s/^cubrid_port_id[ ]*=[ ]*.*/cubrid_port_id='"${cubPort}"'/}"'
    runCmd sed -i "${regexp}" ${CUBRID}/conf/cubrid.conf
    local regexp='"/^\[broker\]/        , /\[/{s/^MASTER_SHM_ID[ ]*=[ ]*.*/MASTER_SHM_ID='"${cubPort}"'/}"'
    runCmd sed -i "${regexp}" ${CUBRID}/conf/cubrid_broker.conf

    local regexp='"/^\[%query_editor\]/ , /\[/{s/^BROKER_PORT[ ]*=[ ]*.*/BROKER_PORT='"${qebPort}"'/}"'
    runCmd sed -i "${regexp}" ${CUBRID}/conf/cubrid_broker.conf
    local regexp='"/^\[%query_editor\]/ , /\[/{s/^APPL_SERVER_SHM_ID[ ]*=[ ]*.*/APPL_SERVER_SHM_ID='"${qebPort}"'/}"'
    runCmd sed -i "${regexp}" ${CUBRID}/conf/cubrid_broker.conf

    local regexp='"/^\[%BROKER1\]/      , /\[/{s/^BROKER_PORT[ ]*=[ ]*.*/BROKER_PORT='"${b1bPort}"'/}"'
    runCmd sed -i "${regexp}" ${CUBRID}/conf/cubrid_broker.conf
    local regexp='"/^\[%BROKER1\]/      , /\[/{s/^APPL_SERVER_SHM_ID[ ]*=[ ]*.*/APPL_SERVER_SHM_ID='"${b1bPort}"'/}"'
    runCmd sed -i "${regexp}" ${CUBRID}/conf/cubrid_broker.conf

    printf "DBG restore configuration files...\n"
    runCmd "mv cubrid_ha.conf     inst/conf/"
}

#================================================================
dbFunc () {
    local db=${1:-testdb}
    runCmd "rm -rf ${CUBRID_DATABASES}"
    runCmd "mkdir ${CUBRID_DATABASES}"
    chkCmd "pushd ${CUBRID_DATABASES}"
    runCmd "cubrid server stop ${db}"
    runCmd "cubrid deletedb ${db}"
    chkCmd "cubrid createdb ${db} en_US"
    chkCmd "cubrid server start ${db}"
    chkCmd "cubrid service status"
    chkCmd "cubrid server stop ${db}"
    #csql -S testdb
    chkCmd "cubrid service status"
    chkCmd "popd"
}

#================================================================
testFunc () {
    local scenario=${1:-tcases/sql}
    local path=`pwd`
    local cfg="${CTP_HOME}/conf/sql.conf"
    runCmd sed -i -e "s:scenario=.*:scenario=${path}/${scenario}:"    ${cfg}
    chkCmd "pushd ${CTP_HOME}"
    runCmd "bin/ctp.sh sql -c ${cfg}"
    chkCmd "popd"
}

#================================================================
pullFunc(){
    local repo=${1:-repo}
    chkCmd "pushd ${repo}"
    runCmd "git pull"
    chkCmd "popd"
}

#================================================================
vgFunc () {
    #chkCmd "valgrind --trace-children=yes --log-file=$HOME/cubrid/vg/broker_%p.txt --xml=yes --xml-file=$HOME/cubrid/vg/broker_%p.xml --leak-check=full --error-limit=no --num-callers=50 $@"
    chkCmd "valgrind --log-file=vg.txt --leak-check=full --trace-children=yes --track-origins=yes --error-limit=no --num-callers=50 $@"
}

#================================================================
webconsoleFunc () {
    chkCmd "pushd ${CTP_HOME}"
    runCmd "bin/ctp.sh webconsole start"
    chkCmd "popd"
}

#================================================================
dt0=$(date +"%Y-%m-%d %H:%M:%S")

#consider 1st arg as command and execute it with th rest of args
cmd=${1:-help} #default command is help
eval "${cmd}""Func" "${@:2}"

dt1=$(date +"%Y-%m-%d %H:%M:%S")

printf "================================================================ SUMMARY\n"
#printf "DBG scriptDir = $scriptDir \n"
printf "TIM %s\nTIM %s\n" "$dt0" "$dt1"
