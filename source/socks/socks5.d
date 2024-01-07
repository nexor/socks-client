module socks.socks5;

import std.socket : AddressFamily;

enum Socks5Version = 0x05;

enum AuthMethod: ubyte
{
    NOAUTH = 0x00,
    AUTH = 0x02,
    NOTAVAILABLE = 0xFF
}

enum AuthStatus: ubyte
{
    YES = 0x00,
    NO = 0x01
}

enum RequestCmd: ubyte
{
    CONNECT = 0x01,
    BIND = 0x02,
    UDPASSOCIATE = 0x03,
}

enum AddressType: ubyte
{
    IPV4 = 0x01,
    DOMAIN = 0x03,
    IPV6 = 0x04,
}

enum ReplyCode: ubyte
{
    SUCCEEDED = 0x00,
    FAILURE = 0x01,
    NOTALLOWED = 0x02,
    NETWORK_UNREACHABLE = 0x03,
    HOST_UNREACHABLE = 0x04,
    CONNECTION_REFUSED = 0x05,
    TTL_EXPIRED = 0x06,
    CMD_NOTSUPPORTED = 0x07,
    ADDR_NOTSUPPORTED = 0x08,

    UNKNOWN = 0xff,
}

enum isSocksOptions(T) =
    (is(T == Socks5Options));

struct Socks5Options
{
    AuthMethod[] authMethods = [ AuthMethod.NOAUTH ];

    string host;
    ushort port;

    string username;
    string password;

    bool resolveHost = true;
}

alias SocksTCPConnector = bool delegate(in string host, in ushort port);
alias SocksDataReader = void delegate(ubyte[] data);
alias SocksDataWriter = void delegate(in ubyte[]);
alias SocksHostnameResolver = string function(in string hostname);

struct Socks5
{
    protected:
        SocksTCPConnector connector;
        SocksDataReader reader;
        SocksDataWriter writer;
        SocksHostnameResolver resolver;

        ReplyCode _replyCode = ReplyCode.UNKNOWN;

    public:
        @nogc
        this(SocksDataReader reader, SocksDataWriter writer, SocksTCPConnector connector = null, SocksHostnameResolver resolver = null)
        {
            this.connector = connector;
            this.reader = reader;
            this.writer = writer;
            this.resolver = resolver;
        }

        bool connect(in Socks5Options options, string host, ushort port)
        {
            if (connector !is null) {
                if (!connector(options.host, options.port)) {
                    _replyCode = ReplyCode.NETWORK_UNREACHABLE;

                    return false;
                }
            }

            AuthMethod chosenMethod = handshake(options);

            ReplyCode _replyCode = request(host, port, options.resolveHost);

            return _replyCode == ReplyCode.SUCCEEDED;
        }

        @property
        ReplyCode replyCode()
        {
            return _replyCode;
        }

    protected:
        AuthMethod handshake(in Socks5Options options)
        {
            ubyte[] data = [Socks5Version, cast(ubyte)options.authMethods.length];
            writer(data);
            writer(cast(ubyte[])options.authMethods);

            ubyte[2] answer;
            reader(answer[]);

            assert(answer[0] == Socks5Version,
                "Error in reply from server. Protocol version must be 0x05 (see RFC 1928, chapter 3).");

            return cast(AuthMethod)answer[1];
        }

        ReplyCode request(in string host, ushort port, bool resolveHostname)
        {
            Socks5RequestPacket packet;

            ubyte[] data = [
                Socks5Version,      // SOCKS version
                RequestCmd.CONNECT, // request command
                0x00,               // rsv
                AddressType.IPV4    // address type
            ];
            ubyte[] hostData;

            IpAddress address;

            if (resolveHostname && resolver !is null) {
                address = IpAddress(resolver(host));
            } else { // no neeed to resolve address
                address = IpAddress(host);
            }

            if (address.isIp4) {
                packet.setIp(address, port);
            } else if (address.isIp6) {
                packet.setIp(address, port);
            } else {
                packet.setDomain(host, port);
            }

            writer(packet[]);

            ubyte[10] answer; // response packet size

            reader(answer[]);

            assert(answer[0] == Socks5Version,
                "Error in reply from server: protocol version must be 0x05 (see RFC 1928, chapter 6).");

            return cast(ReplyCode)answer[1];
        }
}

protected:
    struct Socks5RequestPacket
    {
        private:
        @safe:
            struct PacketData
            {
                ubyte socksVersion = Socks5Version;        // SOCKS version
                ubyte requestCommand = RequestCmd.CONNECT; // request command
                ubyte rsv = 0x00;                          // rsv
                ubyte addressType;                         // address type
                char[1 + ubyte.max + ushort.sizeof] hostData;
            }

            union
            {
                PacketData packetData;
                ubyte[PacketData.sizeof] buffer;
            }
            ushort hostDataLength;

        public:
            void setDomain(string domain, ushort port)
            in
            {
                assert(domain.length <= ubyte.max);
            }
            do
            {
                packetData.addressType = AddressType.DOMAIN;

                hostDataLength = 1 + cast(ubyte)domain.length + ushort.sizeof;
                packetData.hostData[0] = cast(ubyte)(hostDataLength - 1 - ushort.sizeof);
                packetData.hostData[1..hostDataLength-2] = domain;

                setPort(port);
            }

            void setIp(IpAddress ipAddress, ushort port)
            in
            {
                assert(ipAddress.isIp4 || ipAddress.isIp6);
            }
            do
            {
                import std.bitmanip : nativeToBigEndian;

                if (ipAddress.isIp4) {
                    packetData.addressType = AddressType.IPV4;
                    hostDataLength = uint.sizeof + ushort.sizeof;
                    packetData.hostData[0..uint.sizeof] = cast(char[])ipAddress.ip4.nativeToBigEndian;
                }
                if (ipAddress.isIp6) {
                    packetData.addressType = AddressType.IPV6;
                    hostDataLength = 16 + ushort.sizeof;
                    packetData.hostData[0..16] = cast(char[])ipAddress.ip6; // TODO byte order?
                }

                setPort(port);
            }

            ubyte[] opSlice() return
            {
                return buffer[0 .. 4 + hostDataLength];
            }

        protected:
            void setPort(ushort port)
            {
                import std.bitmanip : nativeToBigEndian;

                packetData.hostData[hostDataLength-2..hostDataLength] = cast(char[])port.nativeToBigEndian();
            }
    }

    /**
     * IP4 or IP6 address representation
     */
    struct IpAddress
    {
        import std.socket : InternetAddress, Internet6Address, SocketException;

        @safe:

        this(string ipString)
        {
            _ip4address = InternetAddress.parse(ipString);
            if (_ip4address != InternetAddress.ADDR_NONE) {
                addressFamily = AddressFamily.INET;

                return;
            }

            try {
                ip6 = Internet6Address.parse(ipString);

                return;
            } catch (SocketException se) {

            }

            addressFamily = AddressFamily.UNSPEC;
        }

        AddressFamily addressFamily;
        union
        {
            uint      _ip4address;
            ubyte[16] _ip6address;
        }

        @property
        void ip4(uint value)
        {
            addressFamily = AddressFamily.INET;
            _ip4address = value;
        }

        @property @safe
        uint ip4()
        {
            return _ip4address;
        }

        @property
        bool isIp4()
        {
            return addressFamily == AddressFamily.INET;
        }

        @property
        void ip6(ubyte[16] value)
        {
            addressFamily = AddressFamily.INET6;
            _ip6address = value;
        }

        @property @safe
        ubyte[16] ip6()
        {
            return _ip6address;
        }

        @property
        bool isIp6()
        {
            return addressFamily == AddressFamily.INET6;
        }
    }

    unittest
    {
        auto ip = IpAddress("127.0.0.1");
        assert(ip.isIp4);
        assert(ip.ip4 == 2130706433);

        import std.bigint;
        ip = IpAddress("2001:0db8:85a3:0000:0000:8a2e:0370:7334");
        assert(ip.isIp6);

        auto ipInt = BigInt(0);
        foreach (i; 0..ip.ip6.length) {
            ipInt += BigInt(ip.ip6[i]) << 8*(15-i);
        }

        assert(ipInt == BigInt("42540766452641154071740215577757643572"));
    }
