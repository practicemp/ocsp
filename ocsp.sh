#!/bin/bash
# author: practicemp
# url: https://github.com/practicemp/ocsp
# 获取 Let's Encrypt 的 OCSP 响应文件，应用于 Nginx 配置文件中的 ssl_stapling_file 指令。
# 用法请查看上面的项目主页。

usage(){
    echo "-h   输出此帮助信息。"
    echo "-d   (必填)设置网站证书(cert.pem)及中间证书(chain.pem)所在目录。"
    echo "-o   (必填)设置 OCSP 响应文件路径。如果不存在会自动创建。"
    echo "-t   设置访问 OCSP 服务器的最大重试次数。"
    echo "-v   输出详细信息。"
}


# 如果传入的字符串 $1 为空，则发出自定义信息 $2 并退出脚本。
emptyString(){
    if [ -z $1 ]; then echo $2; exit 1; fi
}

# 如果传入的文件不存在，则发出信息，并退出脚本。
nonexistentFile(){
    if [[ ! -e $1 || ! -r $1 ]]; then echo $1 "不存在或不可读"; exit 1; fi
}

sslDir(){
    if [[ ! -e $1 || ! -d $1 || ! -r $1 || ! -x $1 ]]; then echo $1 "无效的目录，请检查是否存在，或者是否有rx权限"; exit 1; fi
}

ocspDir(){
    if [[ ! -e $1 || ! -d $1 || ! -r $1 || ! -w $1 || ! -x $1 ]]; then echo $1 "OCSP 响应文件所在的目录无效，请检查是否存在，或者是否有rwx权限"; exit 1; fi
}

validNumber(){
    expr $1 + 6 &>/dev/null
    if [[ $? -ne 0 || $1 -lt 0 ]]; then
        echo "最大重试次数应为非负整数，请重新输入"
        exit 1
    fi
}


retryMax=0

while getopts ":d:o:t:vh" opt
do
    case $opt in
        h)
            usage
            exit
            ;;
        d)
            sslDir "$OPTARG"
            ssl_dir=$OPTARG
            ;;
        o)
            ocspDir $(dirname "$OPTARG")
            ocsp_resp_file=$OPTARG
            ;;
        t)
            validNumber $OPTARG
            retryMax=$OPTARG
            ;;
        v)
            verbose=1
            ;;
        \?)
            echo "存在未知选项，请检查"
            usage
            exit 1
            ;;
    esac        
done


emptyString "$ssl_dir" "证书所在目录参数未输入"

emptyString "$ocsp_resp_file" "OCSP 响应文件路径参数未输入"


if [[ $verbose -eq 1 ]]; then
    echo "证书所在目录为：$ssl_dir"
    echo "OCSP 响应文件为：$ocsp_resp_file"
    echo "最大重试次数为：$retryMax"
fi

cert="$ssl_dir/cert.pem"
nonexistentFile $cert

chain="$ssl_dir/chain.pem"
nonexistentFile $chain

ocsp_url=`openssl x509 -in $cert -noout -ocsp_uri`
ocsp_url_host=`echo $ocsp_url | grep -oP '((?<=^http://)|(?<=^https://)).+$'`
emptyString "$ocsp_url_host" "无法从证书中获取到正确的 OSCP 服务器 URL"

ocsp_resp_temp_file=$(dirname $ocsp_resp_file)"/ocsp_resp_temp.der"

version_info=`openssl version`
version=${version_info:0:13}

case $version in
    'OpenSSL 1.0.2') header="Host ${ocsp_url_host}"
        ;;
    'OpenSSL 1.1.0'|'OpenSSL 1.1.1') header="Host=${ocsp_url_host}"
        ;;
    *) echo $version" 抱歉，该版本尚未测试，所以不支持，详情查看项目主页：https://github.com/practicemp/ocsp"; exit 1
        ;;
esac

retry=0
until [[ $retry -gt $retryMax ]]
do
    ocsp_resp=`openssl ocsp -issuer $chain -cert $cert -noverify -no_nonce -resp_text -url $ocsp_url -header $header -respout $ocsp_resp_temp_file 2>&1`
    if [[ $ocsp_resp =~ $cert": good" ]]
    then
        diff $ocsp_resp_temp_file $ocsp_resp_file >/dev/null 2>&1
        if [ $? != 0 ]; then
            cat $ocsp_resp_temp_file > $ocsp_resp_file
            # rm -f $ocsp_resp_temp_file
            if [[ $verbose -eq 1 ]]; then
            echo "响应文件已更新："
            echo "$ocsp_resp"
            fi
            exit
        else
            if [[ $verbose -eq 1 ]]; then
            echo "新响应内容无变化："
            echo "$ocsp_resp"
            fi
            exit
        fi
    fi
    let "retry++"
done

echo "OSCP 响应内容异常！以下为响应内容："
echo "$ocsp_resp"
exit 1