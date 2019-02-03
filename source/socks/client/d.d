module socks.client.d;

version(SocksClientDriverStd)
{
    public import socks.client.std;
}
version(SocksClientDriverVibed)
{
    public import socks.client.vibe;
}
