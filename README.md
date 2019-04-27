## 用法

下载：

```shell
$ git clone https://github.com/practicemp/ocsp.git
```

示例：

```shell
$ sudo ocsp/ocsp.sh -d [证书所在目录] -o [响应文件的路径] -t [最大重试次数，默认为0]
$ sudo ocsp/ocsp.sh \
-d /etc/local/nginx/ssl \
-o /etc/local/nginx/ocsp/ocsp_resp.der \
-t 3 \
-v
# 结合重载 Nginx 配置
$ sudo ocsp/ocsp.sh \
-d /etc/local/nginx/ssl \
-o /etc/local/nginx/ocsp/ocsp_resp.der \
-t 3 \
-v && sudo nginx -s reload
```

该脚本可接受 3 个参数：

* `-h`：显示帮助信息。
* `-d`：设置证书所在目录。需要对其有 `rx` 权限。该目录下应该存在名为 `cert.pem` 的域名证书，以及名为 `chain.pem` 的中间证书。
* `-o`：设置 OCSP 响应文件路径。如果该文件不存在，脚本会自动创建该文件。需要对其所在目录有 `rwx` 权限。如果获取响应成功，脚本还会在该响应文件同级目录下创建一个名为 `ocsp_resp_temp.der` 的临时文件。脚本通过比对临时文件和目标文件（也就是第二个参数所指文件）内容是否一致来判断是否需要更新目标文件内容。该临时文件在脚本运行后不会被删除。
* `-t`：设置最大重试次数。默认为 `0`。由于网络等原因，在向 Let's Encrypt 的 OCSP 服务器发送请求时，可能获取不到成功的响应。例如，设置该参数为 `3`，脚本将在第一次失败后，最多再尝试 3 次，也就是最多共计发送 4 次请求。在脚本最终无法获取成功的结果时，将会打印 OCSP 服务器的响应内容。
* `-v`：显示详细信息。无异常时默认不输出任何内容。