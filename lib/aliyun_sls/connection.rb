require "addressable/uri"
require 'rest_client'
require 'hmac-sha1'
require "base64"
require "zlib"
require "time"

# log = AliyunSls::Protobuf::Log.new(:time => Time.now.to_i, :contents => [])

# [
#     ['value1', '12'],
#     ['value2', '24'],
#     ['value3', '36'],
#     ['value4', '48']
# ].each { |e|  
#     k = e[0]
#     v = e[1]
#     log_item = AliyunSls::Protobuf::Log::Content.new(:key => k, :value => v)
#     log.contents << log_item
# }
# log_list = AliyunSls::Protobuf::LogGroup.new(:logs => [])
# log_list.logs << log

# con = AliyunSls::Connection.new("project", "region", "access_key_secret", "aliyun_access_key")
# con.puts_logs("store", log_list)

# con = AliyunSls::Connection.new("project", "region", "access_key_secret", "aliyun_access_key")
# con.list_logstores

module AliyunSls
    class Connection
# region:
# 杭州：cn-hangzhou.sls.aliyuncs.com
# 青岛：cn-qingdao.sls.aliyuncs.com
# 北京：cn-beijing.sls.aliyuncs.com
# 深圳：cn-shenzhen.sls.aliyuncs.com
        def initialize(project, region, access_key_secret, aliyun_access_key, opts={})
            default_headers = {
                "x-sls-apiversion" => "0.4.0",
                "x-sls-signaturemethod" => "hmac-sha1"
            }
            @headers = default_headers.update opts
            @aliyun_access_key = aliyun_access_key
            @access_key_secret = access_key_secret
            @host = "#{project}.#{region}"
        end

        # http://docs.aliyun.com/#/pub/sls/api/apilist&PutLogs
        def puts_logs(logstorename, content)
            # 压缩content数据
            compressed = Zlib::Deflate.deflate(content.encode.to_s)
            headers = compact_headers(content, compressed)
            headers["Authorization"] = signature("POST", logstorename, headers, content, {})

            u = URI.parse("http://#{@host}/logstores/#{logstorename}")
            rsp = RestClient.post u.to_s, compressed, headers
            parse_response(rsp)
        end

        # http://docs.aliyun.com/#/pub/sls/api/apilist&ListLogstores
        def list_logstores
            headers = compact_headers(nil, nil)
            headers["Authorization"] = signature("GET", nil, headers, nil, {})

            u = URI.parse("http://#{@host}/logstores")
            headers["Referer"] = u.to_s
            rsp = RestClient.get u.to_s, headers
            parse_response(rsp)
        end

        # http://docs.aliyun.com/#/pub/sls/api/apilist&GetLogs
        def get_logs(logstorename, opts={})
            default_opts = {
                :type => "log",
                :from => Time.now.to_i - 60*5,#默认是五分钟前
                :to => Time.now.to_i,
                :line => 100,
                :offset => 0,
                :reverse => false
            }
            opts = default_opts.update opts
            headers = compact_headers(nil, nil)
            headers["Authorization"] = signature("GET", logstorename, headers, nil, opts)

            u = Addressable::URI.parse("http://#{@host}/logstores/#{logstorename}")
            headers["Referer"] = u.to_s
            u.query_values = opts
            rsp = RestClient.get u.to_s, headers
            parse_response(rsp)
        end

        # http://docs.aliyun.com/#/pub/sls/api/apilist&ListTopics
        def list_topics(logstorename, opts={})
            default_opts = {
                :type => "topic",
                :line => 100,
                :toke => ""
            }
            opts = default_opts.update opts
            headers = compact_headers(nil, nil)
            headers["Authorization"] = signature("GET", logstorename, headers, nil, opts)

            u = Addressable::URI.parse("http://#{@host}/logstores/#{logstorename}")
            headers["Referer"] = u.to_s
            u.query_values = opts
            rsp = RestClient.get u.to_s, headers
            parse_response(rsp)
        end

        # http://docs.aliyun.com/#/pub/sls/api/apilist&GetHistograms
        def get_histograms(logstorename, opts={})
            default_opts = {
                :type => "histogram",
                :from => Time.now.to_i - 60*5,#默认是五分钟前
                :to => Time.now.to_i,
                :topic => "",
                :query => "",
            }
            opts = default_opts.update opts
            headers = compact_headers(nil, nil)
            headers["Authorization"] = signature("GET", logstorename, headers, nil, opts)

            u = Addressable::URI.parse("http://#{@host}/logstores/#{logstorename}")
            headers["Referer"] = u.to_s
            u.query_values = opts
            rsp = RestClient.get u.to_s, headers
            parse_response(rsp)
        end

        private

        def string_to_sign(verb, logstorename, headers, content, query={})
            if content
                string_to_sign_with_content(verb, logstorename, headers, query)
            else
                string_to_sign_without_content(verb, logstorename, headers, query)
            end
        end

        def string_to_sign_with_content(verb, logstorename, headers, query={})
            <<-DOC
#{verb}
#{headers['Content-MD5']}
#{headers['Content-Type']}
#{headers['Date']}
#{canonicalized_sls_headers(headers)}
#{canonicalized_resource(logstorename, query)}
DOC
        end

        def string_to_sign_without_content(verb, logstorename, headers, query={})
            <<-DOC
#{verb}


#{headers['Date']}
#{canonicalized_sls_headers(headers)}
#{canonicalized_resource(logstorename, query)}
DOC
        end

# “CanonicalizedSLSHeaders”的构造方式如下：
# 1. 将所有以“x-sls-”为前缀的HTTP请求头的名字转换成小写字母；
# 2. 将上一步得到的所有SLS自定义请求头按照字典序进行升序排序；
# 3. 删除请求头和内容之间分隔符两端出现的任何空格；
# 4. 将所有的头和内容用\n分隔符组合成最后的CanonicalizedSLSHeader;
        def canonicalized_sls_headers(headers)
            h = {}
            headers.each { |k, v|  
                if k =~ /x-sls-.*/
                    h[k.downcase] = v
                end
            }
            h.keys.sort.map { |e|  
                h[e]
                "#{e}:#{h[e].gsub(/^\s+/,'')}"
            }.join($/)
        end

# “CanonicalizedResource”的构造方式如下：
# 1. 将CanonicalizedResource设置为空字符串（""）；
# 2. 放入要访问的SLS资源："/logstores/logstorename"（无logstorename则不填）；
# 3. 如请求包含查询字符串（QUERY_STRING），则在CanonicalizedResource字符串尾部添加“？”和查询字符串。
        def canonicalized_resource(logstorename, query={})
            u = logstorename ? Addressable::URI.parse("/logstores/#{logstorename}") : Addressable::URI.parse("/logstores")
            if query.size != 0
                # 不能对请求的URL参数做URLEncode编码
                q_str = query.keys.sort.map { |e|  
                    "#{e}=#{query[e]}"
                }.join('&')
                "#{u}?#{q_str}"
            else
                u.to_s
            end
        end

# 目前，SLS API只支持一种数字签名算法，即默认签名算法"hmac-sha1"。其整个签名公式如下：
# Signature = base64(hmac-sha1(UTF8-Encoding-Of(SignString)，AccessKeySecret))
        def sign(verb, logstorename, headers, content, query)
            Base64.encode64((HMAC::SHA1.new(@access_key_secret) << string_to_sign(verb, logstorename, headers, content, query).chomp).digest).strip
        end

        def signature(verb, logstorename, headers, content, query)
            "SLS #{@aliyun_access_key}:#{sign(verb, logstorename, headers, content, query)}"
        end

        # content是LogGroup
        def compact_headers(content, compressed)
            headers = @headers.dup
            # headers["x-sls-date"] = 
            headers["Date"] = DateTime.now.httpdate
            headers["x-sls-bodyrawsize"] = "0"

            if content and compressed
                body = content.encode.to_s
                headers["Content-Length"] = compressed.bytesize.to_s
                # 日志内容包含的日志必须小于3MB和4096条。
                raise AliyunSls::PostBodyTooLarge, "content length is larger than 3MB" if headers["Content-Length"].to_i > 3*1024**2*8
                raise AliyunSls::PostBodyTooLarge, "content size is more than 4096" if content.logs.size > 4096
                # MD5必须为大写字符串
                headers["Content-MD5"] = Digest::MD5.hexdigest(compressed).upcase
                headers["Content-Type"] = "application/x-protobuf"
                headers["x-sls-bodyrawsize"] = body.bytesize.to_s
                headers["x-sls-compresstype"] = "deflate"
            end
            headers
        end

        def parse_response(rsp)
            # 如果返回结果报错，则解析报错内容打印到日志中
            if rsp.code.to_s =~ /[4|5]\d\d/
                msg = "status #{rsp.code} body #{rsp}"
                if $logger and $logger.respond_to?(:error)
                    $logger.error msg
                else
                    puts msg
                end
            end
            rsp
        end
    end
end
