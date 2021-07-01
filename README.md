**English** | [中文](https://p3terx.com/archives/cloudflare-warp-configuration-script.html)

# Cloudflare WARP configuration script

Quickly configure and use Cloudflare WARP on your Linux Server, which works with the latest major Linux distributions.

## Features

- Automatically install CloudFlare WARP Official Linux Client
- Quickly enable WARP Proxy Mode, access WARP network with SOCKS5
- Automatically install WireGuard related components
- Configuration WARP IPv4 Network interface (with WireGuard)
- Configuration WARP IPv6 Network interface (with WireGuard)
- Configuration WARP Dual Stack Network interface (with WireGuard)
- ...

## Usage

```bash
bash <(curl -fsSL git.io/warp.sh) [SUBCOMMAND]
```

### Subcommands

```
install         Install Cloudflare WARP Official Linux Client
uninstall       uninstall Cloudflare WARP Official Linux Client
proxy           Enable WARP Client Proxy Mode (default SOCKS5 port: 40000)
unproxy         Disable WARP Client Proxy Mode
wg4             Configuration WARP IPv4 Network interface (with WireGuard)
wg6             Configuration WARP IPv6 Network interface (with WireGuard)
wgd             Configuration WARP Dual Stack Network interface (with WireGuard)
rewg            Restart WARP WireGuard service
unwg            Disable WARP WireGuard service
status          Prints status information
version         Prints version information
help            Prints this message or the help of the given subcommand(s)
menu            Chinese special features menu
```

## Credits

- [Cloudflare WARP](https://1.1.1.1/)
- [WireGuard](https://www.wireguard.com/)
- [ViRb3/wgcf](https://github.com/ViRb3/wgcf)

## License

[MIT](https://github.com/P3TERX/warp.sh/blob/main/LICENSE) © **[P3TERX](https://p3terx.com/)**
