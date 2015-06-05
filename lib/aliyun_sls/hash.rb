class Hash
    def to_query
        self.inject([]){|s, a| s << "#{a[0]}=#{a[1]}"}.join('&')
    end
end