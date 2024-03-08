Nearly everything that has to do with web services requires DNS entries. For example, if you want a web server to provide Host based routing to multiple _virtual_ hosts on the same IP, you need DNS entries. If you want to enable server side or client side TLS in web services, you'll most certainly want host names (although not strictly required). Plus, many advanced web features (e.g. progressive web applications) are required to only exist in an HTTPS context by the web browser. In summary, following a baseline OS install, having a DNS server setup is a must.

There are a few different DNS servers worth considering for a small-scale network. CoreDNS, bind, and dnsmasq to name a few. For my purposes, dnsmasq remains the best choice because of its built in DHCP and TFTP functionality. Combining DHCP, TFTP, and DNS affords you the ability to setup PXE boot on your network, enabling auto-provisioning of systems as they are connected and boot from the network. That said, for now we'll only focus on DNS in our "initial" environment.

For our initial environment, we're going to cheat a bit with the configuration of dnsmask. For starters, we'll configure the dns entries directly within our `docker-compose.yml` file for dnsmasq. This is possible because Docker mandates control over the `/etc/hosts` file via `--add-host` arguments and dnsmasq includes `/etc/hosts` in its resolver. Secondly, we're going to use the host network stack with starting up dnsmask. There is a lot of complexity with hosting a service for nodes on an external network from one docker container to another that aren't within the same docker network. We can eliminate alot of that complexity by hosting our DNS server in the host network stack and then adding a `--dns=` argument to all of our subsequent services.

Before we create our dnsmask container, there are 2 pre-requisites in a Debian/Ubuntu environment:

- Set the nameserver in `/etc/resolv.conf` to something external (e.g. 9.9.9.9).
- Disable systemd-resolved DNS cache running on 127.0.0.1:53.
  `sudo su -c "systemctl stop systemd-resolved && systemctl disable systemd-resolved"`

Replace any /etc/resolve with our new nameserver. (You'll need to do this on all network devices.)
`sudo su -c 'rm /etc/resolv.conf && echo -e "nameserver 127.0.0.1\nsearch lab\n" > /etc/resolv.conf'`

Our initial dnsmasq docker-compose.yml file:

```
version: "3"

services:
  dnsmasq_svc:
    image: git.lab/lab/dnsmasq:initial
    build:
      context: .
      dockerfile_inline: |
        FROM alpine:3.19
        RUN apk add -U dnsmasq
    container_name: dnsmasq_svc
    restart: unless-stopped
    network_mode: host
    dns:
    - 9.9.9.9
    - 1.1.1.1
    dns_search: lab
    extra_hosts:
    - dockerhost:host-gateway
    - git.lab:192.168.1.73
    - words.lab:192.168.1.73
    - dns.lab:192.168.1.73
    - www.lab:192.168.1.73
    entrypoint: ["/usr/sbin/dnsmasq", "--no-daemon"]
```

Now if we fire up the dnsmasq environment with: `docker compose up -d`.

If you want to change the records, update docker-compose.yml and run:
`docker compose down && docker compose up -d`

Caution: `docker compose restart` will not work. It does not read yaml updates.

Containers that use their own _custom_ network use the embedded Docker DNS on their own 127.0.0.11 interface. You may be able to override this with various `dns` settings. Most often its more simple to use the default network for containers, which will default to using the host's `/etc/resolv.conf` settings. Therefore, if all of our containers use the default bridge network and our host's `/etc/resolv.conf` points to ourselve on our external network, thereby calling dnsmasq ... all containers will automatically use the dnsmasq settings.