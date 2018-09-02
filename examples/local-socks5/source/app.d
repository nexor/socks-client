import vibe.core.net;
import vibe.core.log;
import vibe.core.core;
import std.typecons;
import socks.client.vibe;
import std.stdio;

int main(string[] args)
{
    Socks5Options socks5Options = {
        host: "127.0.0.1",
        port: 1080,
    };

    TCPConnection conn = connectTCPSocks(socks5Options, "localhost", 80);

    string request = "GET / HTTP/1.1\r\n" ~
        "Host: ya.ru\r\n" ~
        "User-Agent: vibe-client/0.0.0\r\n" ~
        "Accept: */*\r\n\r\n";

    logWarn("Writing request");
    conn.write(request);

    ubyte[8192] response;
    ubyte[] chunk = response[0..conn.leastSize];

    logWarn("Reading response");
    conn.read(chunk);
    writefln("%s", cast(char[])chunk);

    return 0;
}
