module socks.client.std;

public import socks.socks5;

import std.socket : TcpSocket, Address, InternetAddress;
import std.conv : to;

TcpSocket connectTCPSocks(Socks5Options socksOptions, TcpSocket tcpSocket, Address address)
{
    SocksTCPConnector connector = (in string host, in ushort port)
    {
        import std.typecons : scoped;

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

TcpSocket connectTCPSocks(Socks5Options socksOptions, Address address)
{
    auto socket = new TcpSocket;

    return connectTCPSocks(socksOptions, socket, address);
}
