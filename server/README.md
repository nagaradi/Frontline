# Frontline headless multiplayer server

This runs the existing Godot project in headless mode and automatically opens the ENet host on UDP port 7777. It is an early multiplayer prototype, not a production matchmaking service.

## Build and run with Docker

From the repository root:

```sh
docker build -f server/Dockerfile -t frontline-server .
docker run --rm -p 7777:7777/udp -e FRONTLINE_PORT=7777 frontline-server
```

The server log should include `FRONTLINE_SERVER_READY port=7777 protocol=UDP`.

## Make it reachable over the internet

A running process is not automatically public. Deploy this container to a server/VM that permits inbound **UDP** traffic, open UDP port 7777 in both the provider firewall and host firewall, and keep the process running. Share the server's public IPv4 address with players. On the game lobby, enter that address and port 7777, then tap **JOIN MATCH**.

A local computer or phone acting as host only works across the internet if its network permits inbound UDP and has a reachable public address; many mobile and home connections use carrier-grade NAT and cannot accept inbound connections. Do not publish private credentials or API tokens in the repository.

## Current limitations

- This is a first networking pass, not a managed global service.
- No account system, matchmaking, persistence, anti-cheat, authoritative combat validation, or production DDoS protection.
- Android build and on-device multiplayer testing must pass before claiming it is ready to play.
- A cloud provider account and a reachable UDP endpoint are still required; this repository change cannot provision paid infrastructure or create provider credentials.
