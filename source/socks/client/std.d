module socks.client.std;

version(SocksClientDriverStd):

pragma(msg, "Using std driver for socks-client");

public import socks.socks5;

import std.socket;
import std.conv : to;


TcpSocket connectTCPSocks(S)(S socksOptions, Address address)
    if (isSocksOptions!S)
{
    auto socket = new TcpSocket;

    return connectTCPSocks(socksOptions, socket, address);
}

TcpSocket connectTCPSocks(S)(S socksOptions, Socket socket, Address address)
    if (isSocksOptions!S)
{
    TcpSocket tcpSocket = cast(TcpSocket)socket;

    SocksTCPConnector connector = (in string host, in ushort port)
    {
        import std.typecons;

        auto socksAddress = scoped!InternetAddress(host, port);
        tcpSocket.connect(socksAddress);

        return true;
    };
    SocksDataReader reader = (ubyte[] data) {
        ulong count = 0;
        while(count < data.length) {
            count += tcpSocket.receive(data[count..$]);
        }
    };
    SocksDataWriter writer = (in ubyte[] data) {
        tcpSocket.send(data);
    };

    auto socks5 = Socks5(reader, writer, connector);

    socks5.connect(socksOptions, address.toAddrString(), address.toPortString().to!ushort);

    return tcpSocket;
}
