#!/bin/bash
### encoding: UTF-8, Format: Unix(LF) ###
# yamabuki_bakery@outlook.jp
# Last edit: Aug 08, 2021
# 傳承了 薩格爾王 瑪納斯 江格爾 偉大史詩

LOGGING_LEVEL=2 # 1:DEBUG

RETURN_VALUE=""
TEMPDIR="/tmp/wgddnsbash114514/"
WGDIR="/etc/wireguard"
 
IPV4_REGEX="[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
IPV6_REGEX="\(\([0-9A-Fa-f]\{1,4\}:\)\{1,\}\)\(\([0-9A-Fa-f]\{1,4\}\)\{0,1\}\)\(\(:[0-9A-Fa-f]\{1,4\}\)\{1,\}\)"

############################################################################
# function name: main
# function description: main function
# parameters: 🈚️️
# return: 🈚️️
############################################################################
function main() {
    logging 2 "wgddns watchdog started"

    if [[ $(id -u) -ne 0 ]]; then
        logging 3 "你需要是 root 權限才能操作 wg，，，"
        sleep 3
    fi

    if check_openwrt; then
        logging 3 "您正在使用 OpenWRT，俺幫你呼叫 /usr/bin/wireguard_watchdog"
        /usr/bin/wireguard_watchdog
        error_exit "Line $LINENO: System is OpenWRT."
    fi

    check_commands  # 確認本腳本所需命令
    
    prepare_tmp_folder  # 新建臨時文件夾

    # 列出所有運行的 wg 介面
    #wg show | grep -i interface | sed "s/interface\:\s\(.*\)$/\1/" > ${TEMPDIR}/interfaces.tmp
    
    local interfaces=($(wg show interfaces))  # 介面的名字，數組
    local amount=${#interfaces[@]}  # 介面的數量，整數

    logging 2 "${amount} wg interface(s) found"

    # 對每一個介面分別操作
    for interface in ${interfaces[@]}; do
        logging 2 "正在屌查 ${interface}"
        
        ################################# 確認該介面的運行狀態 ###############################
        # 尋找該介面的監聽端口
        local listening_port=$(wg show ${interface} listen-port)
        # 列出所有 peer 的公鑰
        #wg show ${interface} | grep "peer\:\s" | sed -E "s/peer\:\s([a-zA-Z0-9=]+)/\1/"> ${TEMPDIR}/interface-${interface}.pubkeys
        # 和所在的行數
        #wg show ${interface} | grep -n "peer\:\s" | sed -E "s/([0-9]+)\:.*+$/\1/" > ${TEMPDIR}/interface-${interface}.linecount
        # 取區間到文件尾的時候有用
        #echo 99999999 >> ${TEMPDIR}/interface-${interface}.linecount
        
        local peers=($(wg show ${interface} peers))  # peer 的數組，用公鑰區分
        local peer_count=${#peers[@]}  # peer 的個數
        logging 2 "+ Interface ${interface} 🈶️️ ${peer_count} 個 peer"
        
        
        #local lines=($(cat ${TEMPDIR}/interface-${interface}.linecount))  # 每一個 peer 在 wg 命令輸出中的行數
        ################################# 確認該介面的運行狀態 ###############################

        ################################# 確認該介面的配置文件 ###############################
        # 此處不可使用 wg showconf，因爲無論如何都會顯示正在監聽的端口
        # 尋找該介面的監聽端口
        local conf_listening_port=$(cat ${WGDIR}/${interface}.conf | grep -i listen | grep -o "[0-9]\{1,5\}")
        # cat ${WGDIR}/${interface}.conf 
        # 尋找每個 peer 的行數區間
        cat ${WGDIR}/${interface}.conf | grep -i -F -n "[Peer]" | sed -E "s/([0-9]+)\:.*+$/\1/" > ${TEMPDIR}/conf-interface-${interface}.linecount
        # 取區間到文件尾的時候有用
        echo 99999999 >> ${TEMPDIR}/conf-interface-${interface}.linecount
        # cat ${TEMPDIR}/conf-interface-${interface}.linecount

        # 在每個區間內尋找 peer 的公鑰和地址
        local conf_lines=($(cat ${TEMPDIR}/conf-interface-${interface}.linecount)) 
        local conf_peer_count=$((${#conf_lines[@]}-1))
        logging 1 "+ 屌查 ${interface} 的配置文件，監聽端口爲：${conf_listening_port}，🈶️️ ${conf_peer_count} 個 peer"
        for ((i = 0 ; i < ${conf_peer_count} ; i++)); do
            local conf_start=${conf_lines[$i]}
            local conf_end=${conf_lines[$(($i+1))]}
            # local endpoint_line=$(wg show ${interface} | sed "${start},${end}!d" | grep -i endpoint) 以下抄這條命令
            local conf_pubkey=$(cat ${WGDIR}/${interface}.conf | sed "${conf_start},${conf_end}!d" | grep -i PublicKey | grep -o "[a-zA-Z0-9\+\/\=]\{44\}")
            local conf_endpoint=$(cat ${WGDIR}/${interface}.conf | sed "${conf_start},${conf_end}!d" | grep -i endpoint | sed -E "s/.*=\s*(.*)\:[0-9]{1,5}\s*$/\1/")
            local conf_endpoint_port=$(cat ${WGDIR}/${interface}.conf | sed "${conf_start},${conf_end}!d" | grep -i endpoint | sed -E "s/.*=\s*.*\:([0-9]{1,5})\s*$/\1/")

            echo -e "${conf_pubkey},${conf_endpoint},${conf_endpoint_port}" >> ${TEMPDIR}/conf-interface-${interface}.peeraddr
        done
        ################################# 確認該介面的配置文件 ###############################

        #local loop_count=0  # 下面的循環次數

        # 對每一個 peer 分別操作
        for peer in ${peers[@]}; do
            logging 2 "++ 正在屌查 peer：${peer}"
            # 屌查端點地址
            #local start=${lines[$loop_count]}
            #local end=${lines[$(($loop_count+1))]}
            local endpoint_line=$(wg show ${interface} endpoints | grep ${peer})  # 取出那一行來
            logging 1 "+++ endpoint line: ${endpoint_line}"

            # 抄的 OpenWRT /usr/bin/wireguard_watchdog
            local IPV4=$(echo ${endpoint_line} | grep -m 1 -o "$IPV4_REGEX")    # $ for do not detect ip in 0.0.0.0.example.com
            local IPV6=$(echo ${endpoint_line} | grep -m 1 -o "$IPV6_REGEX")

            logging 1 "+++ v4: ${IPV4}, v6: ${IPV6}"
            if [[ -n ${IPV4} ]]; then
                logging 2 "+++ 現在該 peer 的 ipv4 地址是 ${IPV4}"
                local peer_ip=${IPV4}
            else
                if [[ -n ${IPV6} ]]; then
                    logging 2 "+++ 現在該 peer 的 ipv6 地址是 ${IPV6}"
                    local peer_ip=${IPV6}
                else
                    logging 2 "+++ 沒有發現該 peer 的 IP 地址，該 peer 可能是主動發起連線的一方"
                    #loop_count=$((${loop_count}+1))
                    continue  # 該 peer 可能不需要處理
                fi
            fi
            # 已經拿到該 peer 的 ip，現在和配置文件進行比較。
            # local conf_endpoint=$(cat ${TEMPDIR}/conf-interface-${interface}.peeraddr | grep ${peer} | sed -E "s/.*\s(.*)$/\1/" )
            local conf_peer=$(cat ${TEMPDIR}/conf-interface-${interface}.peeraddr | grep ${peer})
            IFS=',' read -ra fields <<< "${conf_peer}"

            local conf_endpoint=${fields[1]}
            local conf_endpoint_port=${fields[2]}

            local conf_IPV4=$(echo ${conf_endpoint} | grep -m 1 -o "$IPV4_REGEX")    # $ for do not detect ip in 0.0.0.0.example.com
            local conf_IPV6=$(echo ${conf_endpoint} | grep -m 1 -o "$IPV6_REGEX")

            logging 1 "++ v4: ${conf_IPV4}, v6: ${conf_IPV6}"
            if [[ -n ${conf_IPV4} ]]; then
                logging 2 "+++ 配置中該 peer 的 ipv4 地址是 ${conf_IPV4}:${conf_endpoint_port}，屬於靜態地址跳过"
                continue
            else
                if [[ -n ${conf_IPV6} ]]; then
                    logging 2 "+++ 配置中該 peer 的 ipv6 地址是 ${conf_IPV6}:${conf_endpoint_port}，屬於靜態地址跳过"
                    continue
                else
                    if [[ -n ${conf_endpoint} ]]; then
                        logging 2 "+++ 該 peer 的端點是 ${conf_endpoint}:${conf_endpoint_port} 不是 IP 地址，嘗試進行解析"
                        if resolve ${conf_endpoint}; then
                            local addr=${RETURN_VALUE}
                            logging 1 "+++ ${conf_endpoint} 解析的地址是 ${addr}"
                            if [[ ${addr} == ${peer_ip} ]]; then  # 這裏 peer_ip 的 v6 也沒有加框
                                logging 2 "+++ 地址没有改变，跳过！"
                                continue
                            else
                                # 檢查是否需要 v6 加框
                                local v6test=$(echo ${addr} | grep -m 1 -o "$IPV6_REGEX")
                                if [[ -n ${v6test} ]]; then
                                    logging 2 "+++ 地址改变了，需要更改 wg 端点，新地址是 [${addr}]:${conf_endpoint_port}"
                                    wg set ${interface} peer ${peer} endpoint "[${addr}]:${conf_endpoint_port}"
                                else
                                    logging 2 "+++ 地址改变了，需要更改 wg 端点，新地址是 ${addr}:${conf_endpoint_port}"
                                    wg set ${interface} peer ${peer} endpoint ${addr}:${conf_endpoint_port}
                                fi
                            fi
                        else
                            logging 2 "+++ ${conf_endpoint} 解析失败，跳过"
                            continue
                        fi
                    else
                        logging 2 "+++ 配置文件中沒有 peer 的地址，跳過"
                        continue
                    fi
                fi
            fi
        done
    done

    rm -rf ${TEMPDIR}
    logging 1 "Temp folder ${TEMPDIR} 已削除"
    logging 2 "All done!"
}

############################################################################
# function name: prepare_tmp_folder
# function description: mkdir, if failed then rm, if it fails again then abort
# parameters: 🈚️️
# return: 0 for ok, exit for error
############################################################################
function prepare_tmp_folder () {
    if mkdir $TEMPDIR &> /dev/null; then
        logging 1 "Temp folder $TEMPDIR is ready"
        return 0
    else
        logging 3 "Cannot mkdir $TEMPDIR, trying to rm it"
        if rm -rf $TEMPDIR &> /dev/null; then
            if mkdir $TEMPDIR &> /dev/null; then
                logging 1 "Temp folder $TEMPDIR is ready"
                return 0  
            else
                error_exit "Line $LINENO: Cannot mkdir again, cannot prepare temp folder."
            fi
        else
            error_exit "Line $LINENO: Cannot rm the folder, cannot prepare temp folder."
        fi
    fi
}

############################################################################
# function name: check_commands
# function description: check if these commands exist, if not then abort
# parameters: none
# return: 0 for ok, exit for error
############################################################################
function check_commands(){ # no params
    local commands=("wg" "cat" "nslookup")
    for command in "${commands[@]}" 
    do
        logging 1 "Checking command ${command}"
        if ! [ -x "$(command -v "${command}")" ]; then
            error_exit "Line $LINENO: Command ${command} not found"
        fi
    done
    logging 1 "Requirements Check OK"
    return 0
}

############################################################################
# function name: logging
# function description: print a log message
# parameters: $1:level{"debug", "info", "warning", "error"} $2:message
# return: none
############################################################################
function logging(){
    local level=$1; message=$2
    # params #

    local datetime
    datetime=$(date "+%c")
    local errorlevel=("VERBOSE" "DEBUG" "INFO " "WARN " "ERROR")

    if [[ $level -ge ${LOGGING_LEVEL} ]]; then
        echo -e "[${datetime}] ${errorlevel[$1]}: $message"
    fi
}

############################################################################
# function name: error_exit
# function description: abort the shell and print a message when error
# parameters: $1:message
# return: exit 1
############################################################################
function error_exit (){
    local message=$1
    # params #

    logging 4 "$0: ${message:-"Unknown Error"}" 1>&2
    exit 1
}

############################################################################
# function name: resolve
# function description: resolve ip of given host, v6 first
# parameters: $1: the host
# return: 0 for ok, 1 for error, return value (string) IP as 1.1.1.1 240c::6666 不帶框
############################################################################
function resolve (){
    local result=$(nslookup $1 | tail -n2 | grep "^Addr" | sed -E "s/^Address.*:\s(.*)$/\1/" | tail -n1)
    if [[ -n ${result} ]]; then
        RETURN_VALUE=${result}
        return 0
    else
        RETURN_VALUE=""
        return 1
    fi
}

############################################################################
# function name: check_openwrt
# function description: check if the system is openwrt
# parameters: 无
# return: 0 for yes, 1 for no
############################################################################
function check_openwrt () {
    local result=$(cat /etc/os-release | grep -i OPENWRT_RELEASE)
    if [[ -n ${result} ]]; then
        # is openwrt
        return 0
    else
        return 1
    fi
}

main

# 模板
############################################################################
# function name: 
# function description: 
# parameters: 
# return: 
############################################################################