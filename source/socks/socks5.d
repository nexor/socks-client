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

enum isSocksInfo(T) =
    (is(T == Socks5Info));

struct Socks5Info
{
    AuthMethod[] authMethods = [ AuthMethod.NOAUTH ];

    string username;
    string password;
    string host;
    ushort port;
}
