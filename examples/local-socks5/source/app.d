import vibe.core.net;
import vibe.core.log;
import socks.client.d;
import std.stdio;

string proxyHost = "127.0.0.1";
ushort proxyPort = 1080;

// connect to dlang.org through local socks5 proxy
int main(string[] args)
{
    parseArgs(args);

    Socks5Options socks5Options = {
        host: proxyHost,
        port: proxyPort,
    };

    TCPConnection conn = connectTCPSocks(socks5Options, "dlang.org", 80);

    string request = "GET / HTTP/1.1\r\n" ~
        "Host: dlang.org\r\n" ~
        "User-Agent: vibe-client/0.0.0\r\n" ~
        "Accept: */*\r\n\r\n";

    logWarn("Writing request");
    conn.write(request);

    ubyte[8192] response;
    ubyte[] chunk = response[0..conn.leastSize];

    logWarn("Reading response");
    conn.read(chunk);
    writefln("Data from server (%d bytes):\n----\n%s\n----", chunk.length, cast(char[])chunk);

    return 0;
}

void parseArgs(string[] args)
{
    import std.conv : to;

    if (args.length == 3) {
        proxyHost = args[1];
        proxyPort = args[2].to!ushort;
    }
}
