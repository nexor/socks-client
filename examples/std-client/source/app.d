import std.typecons;
import socks.client.d;
import std.socket;
import std.stdio;

string proxyHost = "127.0.0.1";
ushort proxyPort = 1080;

int main(string[] args)
{
    Socks5Options socks5Options = {
        host: "10.93.17.1",
        port: 1080,
        resolveHost: false
    };

    auto address = new InternetAddress("dlang.org", 80);

    TcpSocket conn = connectTCPSocks(socks5Options, address);

    string request = "GET / HTTP/1.1\r\n" ~
        "Host: ya.ru\r\n" ~
        "User-Agent: std-client/0.0.0\r\n" ~
        "Accept: */*\r\n\r\n";

    writefln("%s", "Writing request");
    conn.send(request);

    ubyte[8192] response;

    writefln("%s", "Reading response:");
    long bytes = conn.receive(response);
    writefln("----\n%s----\n", cast(char[])response[0..bytes]);

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
