module socks.client.vibe;

public import socks.socks5;
import core.time;
import vibe.core.net;
import vibe.core.log;

TCPConnection connectTCPSocks(S)(S socksOptions, string host, ushort port, string bind_interface = null,
    ushort bind_port = 0, Duration timeout = Duration.max)
    if (isSocksOptions!S)
{
    TCPConnection conn;

    SocksTCPConnector connector = (in string host, in ushort port)
    {
        conn = connectTCP(socksOptions.host, socksOptions.port, bind_interface, bind_port, timeout);

        return true;
    };
    SocksDataReader reader = (ubyte[] data) { conn.read(data); };
    SocksDataWriter writer = (in ubyte[] data) { conn.write(data); };

    auto socks5 = Socks5(connector, reader, writer);

    socks5.connect(socksOptions, host, port);

    logWarn("Connected");

    return conn;
}
