module socks.socks5;

import vibe.core.net : resolveHost, NetworkAddress;
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

struct Socks5
{
    protected:
        SocksTCPConnector connector;
        SocksDataReader reader;
        SocksDataWriter writer;

        ReplyCode _replyCode = ReplyCode.UNKNOWN;

    public:
        this(SocksTCPConnector connector, SocksDataReader reader, SocksDataWriter writer)
        {
            this.connector = connector;
            this.reader = reader;
            this.writer = writer;
        }

        bool connect(in Socks5Options options, string host, ushort port)
        {
            if (!connector(options.host, options.port)) {
                _replyCode = ReplyCode.NETWORK_UNREACHABLE;

                return false;
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
            import std.bitmanip;

            ubyte[] data = [
                Socks5Version,      // SOCKS version
                RequestCmd.CONNECT, // request command
                0x00,               // rsv
                AddressType.IPV4    // address type
            ];
            ubyte[] hostData;

            if (resolveHostname) {
                NetworkAddress address = resolveHost(host, AddressFamily.UNSPEC, resolveHostname);

                union IpBuffer
                {
                    int ip;
                    ubyte[ip.sizeof] buffer;
                }

                IpBuffer ipBuf = {ip:address.sockAddrInet4.sin_addr.s_addr};
                hostData = ipBuf.buffer;
            } else {
                data[3] = AddressType.DOMAIN;
                hostData = cast(ubyte[])host;
            }


            writer(data);
            writer(hostData);
            writer(port.nativeToBigEndian());

            ubyte[10] answer; // response packet size

            reader(answer[]);

            assert(answer[0] == Socks5Version,
                "Error in reply from server: protocol version must be 0x05 (see RFC 1928, chapter 6).");

            return cast(ReplyCode)answer[1];
        }
}
