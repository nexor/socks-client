module socks.socks5;

import vibe.core.core;
import vibe.core.log;
import vibe.core.net;

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
    ADDR_NOTSUPPORTED = 0x08
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

import vibe.core.net;
import std.socket : AddressFamily;

struct Socks5
{
    protected:
        SocksTCPConnector connector;
        SocksDataReader reader;
        SocksDataWriter writer;

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
                assert(0, "Can't connect to a proxy server");
            }

            AuthMethod chosenMethod = handshake(options);

            logDebug("Chosen method: %s", chosenMethod);

            ReplyCode reply = request(host, port, options.resolveHost);

            if (reply == ReplyCode.SUCCEEDED) {
                logDebug("Connected to proxy");

                return true;
            } else {
                logError("Error connecting to proxy: %d", reply);

                return false;
            }
        }

    protected:
        AuthMethod handshake(in Socks5Options options)
        {
            logDebug("Connection handshake");

            ubyte[] data = [0x05, cast(ubyte)options.authMethods.length];
            writer(data);
            writer(cast(ubyte[])options.authMethods);

            ubyte[2] answer;
            reader(answer[]);

            assert(answer[0] == 0x05);

            return cast(AuthMethod)answer[1];
        }

        ReplyCode request(in string host, ushort port, bool resolveHostname)
        {
            import std.bitmanip;

            ubyte[] data = [
                0x05,               // SOCKS version
                RequestCmd.CONNECT, // request command
                0x00,               // rsv
                AddressType.IPV4    // address type
            ];
            ubyte[] hostData;

            if (resolveHostname) {
                NetworkAddress address = resolveHost(host, AddressFamily.UNSPEC, resolveHostname);

                logDebug("Resolved host: %s", address.sockAddrInet4.sin_addr.s_addr);

                union IpBuffer
                {
                    int ip;
                    ubyte[ip.sizeof] buffer;
                }

                logDebug("Connection request");

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

            assert(answer[0] == 0x05);

            return cast(ReplyCode)answer[1];
        }
}
