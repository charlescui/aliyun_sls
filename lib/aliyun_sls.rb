require File.join(File.dirname(__FILE__), 'aliyun_sls', 'version.rb')
require File.join(File.dirname(__FILE__), 'aliyun_sls', 'protobuf.rb')
require File.join(File.dirname(__FILE__), 'aliyun_sls', 'connection.rb')

module AliyunSls
    class PostBodyInvalid < RuntimeError; end
    class SLSInvalidTimestamp < RuntimeError; end
    class SLSInvalidEncoding < RuntimeError; end
    class SLSInvalidKey < RuntimeError; end
    class PostBodyTooLarge < RuntimeError; end
    class PostBodyUncompressError < RuntimeError; end
    class SLSLogStoreNotExist < RuntimeError; end
end
