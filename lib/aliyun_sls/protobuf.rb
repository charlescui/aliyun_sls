require 'beefcake'

module AliyunSls
    module Protobuf

# message Log
# {
#     required uint32 time = 1; // UNIX Time Format
#     message Content
#     {
#         required string key = 1;
#         required string value = 2;
#     }
#     repeated Content contents= 2;
# }

# message LogGroup
# {
#     repeated Log logs= 1;
#     optional string reserved =2; // 内部字段，不需要填写
#     optional string topic = 3;
#     optional string source = 4;
# }

        class Log
            include Beefcake::Message

            required :time, :uint32, 1

            class Content
                include Beefcake::Message

                required :key, :string, 1
                required :value, :string, 2
            end

            repeated :contents, Content, 2
        end

        class LogGroup
            include Beefcake::Message

            repeated :logs, Log, 1
            optional :reserved, :string, 2
            optional :topic, :string, 3
            optional :source, :string, 4
        end
        
    end
end