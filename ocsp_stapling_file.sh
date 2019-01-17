#!/bin/bash
# author: practicemp
# url: https://github.com/practicemp/ocsp
# 获取 Let's Encrypt 的 OCSP 响应文件，应用于 Nginx 配置文件中的 ssl_stapling_file 指令。
# 用法请查看上面的项目主页。

# 如果传入的字符串 $1 为空，则发出自定义信息 $2 并退出脚本。
emptyString(){
    if [ -z $1 ]; then echo $2; exit 1; fi
}

# 如果传入的文件不存在，则发出信息，并退出脚本。
nonexistentFile(){
    if [[ ! -e $1 || ! -r $1 ]]; then echo $1 "不存在或不可读"; exit 1; fi
}

emptyString "$1" "证书域名参数未输入"
domain=$1

emptyString "$2" "OCSP 响应文件路径参数未输入"
ocsp_resp_file=$2

if [ -z $3 ]; then
    retryMax=0
else
    expr $3 + 6 &>/dev/null
    if [[ $? -eq 0 && $3 -ge 0 ]]; then
        retryMax=$3
    else
        echo "最大重试次数应为非负整数，请重新输入"
        exit 1
    fi
fi

cert="/etc/letsencrypt/live/$domain/cert.pem"
nonexistentFile $cert

chain="/etc/letsencrypt/live/$domain/chain.pem"
nonexistentFile $chain

ocsp_url=`openssl x509 -in $cert -noout -ocsp_uri`
ocsp_url_host=`echo $ocsp_url | grep -oP '((?<=^http://)|(?<=^https://)).+$'`
emptyString "$ocsp_url_host" "无法从证书中获取到正确的 OSCP 服务器 URL"

ocsp_resp_temp_file=$(dirname $ocsp_resp_file)"/ocsp_resp_temp.der"

version_info=`openssl version`
version=${version_info:0:13}

case $version in
    'OpenssL 1.0.2') header="Host ${ocsp_url_host}"
        ;;
    'OpenSSL 1.1.0'|'OpenSSL 1.1.1') header="Host=${ocsp_url_host}"
        ;;
    *) echo $version" 该版本尚未测试，所以不支持，详情查看项目主页：https://github.com/practicemp/ocsp"; exit
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
#            rm -f $ocsp_resp_temp_file
#            echo "响应文件已更新"
#            echo "$ocsp_resp"
            exit
        else 
#            echo "新响应内容无变化"
#            echo "$ocsp_resp"
            exit
        fi
    fi
    let "retry++"
done

echo "OSCP 响应内容异常！以下为响应内容："
echo "$ocsp_resp"
exit 1