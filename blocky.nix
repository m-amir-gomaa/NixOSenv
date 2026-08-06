{ config, pkgs, lib, ... }:

let
  blockyPort = 5300;
in
{
  # ── Blocky: DNS-level porn/adult content blocker ───────────────────
  # Uses OISD full + StevenBlack porn blocklists. Auto-updates daily.
  services.blocky = {
    enable = true;

    settings = {
      upstreams = {
        groups.default = [
          "https://dns.google/dns-query"
          "https://cloudflare-dns.com/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        strategy = "parallel_best";
        timeout = "3s";
      };

      ports.dns = blockyPort;

      blocking = {
        # denylists.porn = [
        #   "https://big.oisd.nl/"
        #   "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
        # ];
        # Extra dedicated adult blocklists
        # denylists.porn_extra = [
        #   "https://raw.githubusercontent.com/AdAway/adaway.github.io/master/hosts.txt"
        #   "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
        # ];

        # clientGroupsBlock.default = [ "porn" "porn_extra" ];

        # Return 0.0.0.0 for blocked domains (fast fail, no timeout)
        blockType = "zeroIP";
        blockTTL = "1h";
      };

      caching = {
        minTime = "5m";
        maxTime = "30m";
        maxItemsCount = 10000;
        prefetching = true;
        prefetchExpires = "2h";
        prefetchThreshold = 10;
      };

      # Force IPv4 — no IPv6 connectivity (ISP blocks it)
      connectIPVersion = "v4";

      log.level = "warn";
      log.format = "text";

      # Used to resolve blocklist URLs before upstream DNS is available
      bootstrapDns = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  # Point systemd-resolved → blocky
  services.resolved.settings.Resolve = lib.mkForce {
    DNS = "127.0.0.1:${toString blockyPort}";
    FallbackDNS = "";
    DNSOverTLS = "no";
    DNSSEC = "false";
    Domains = "~.";
  };
}
