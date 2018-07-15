module socks.client.vibe;

public import socks.socks5;
import core.time;
import vibe.core.net;
import vibe.core.log;

@safe
TCPConnection connectTCPSocks(S)(S socksSettings, string host, ushort port, string bind_interface = null,
    ushort bind_port = 0, Duration timeout = Duration.max)
    if (isSocksInfo!S)
{
    import std.socket : AddressFamily;

    auto conn = connectTCP(socksSettings.host, socksSettings.port, bind_interface, bind_port, timeout);

    AuthMethod chosenMethod = socksHandshake(conn, socksSettings);

    logDebug("Chosen method: %s", chosenMethod);

    NetworkAddress address = resolveHost(host, AddressFamily.UNSPEC, false); // only IP is allowed

    ReplyCode reply = socksRequest(conn, socksSettings, address.sockAddrInet4.sin_addr.s_addr, port);

    if (reply == ReplyCode.SUCCEEDED) {
        logDebug("Connected to proxy");
    } else {
        logError("Error connecting to proxy: %d", reply);
    }

    return conn;
}

AuthMethod socksHandshake(S)(ref TCPConnection conn, ref S socksSettings)
{
    logDebug("Connection handshake");

    ubyte[] data = [0x05, cast(ubyte)socksSettings.authMethods.length];
    conn.write(data);
    conn.write(cast(ubyte[])socksSettings.authMethods);

    ubyte[2] answer;
    conn.read(answer);

    assert(answer[0] == 0x05);

    return cast(AuthMethod)answer[1];
}

union IpBuffer
{
    int ip;
    ubyte[ip.sizeof] buffer;
}

@safe
ReplyCode socksRequest(S)(ref TCPConnection conn, ref S socksSettings, int ip, ushort port)
{
    import std.bitmanip;

    logDebug("Connection request");

    ubyte[] data = [
        0x05,               // SOCKS version
        RequestCmd.CONNECT, // request command
        0x00,               // rsv
        AddressType.IPV4    // address type
    ];

    conn.write(data);
    IpBuffer ipBuf = {ip:ip};

    conn.write(ipBuf.buffer);
    conn.write(port.nativeToBigEndian());

    ubyte[10] answer; // response packet size

    conn.read(answer);

    assert(answer[0] == 0x05);

    return cast(ReplyCode)answer[1];
}