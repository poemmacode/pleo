# ADR 0003 — Diseño de SafeHttp (Épica A)

Fecha: 2026-10-17 · Estado: aceptada

## Decisiones

1. **IP fijada con `Net::HTTP#ipaddr=`**. En Ruby 3.3 (net-http 0.4) el socket TCP se abre hacia `ipaddr`, mientras que la cabecera `Host`, el SNI y `post_connection_check` usan el hostname. Así se conecta a la IP que validamos sin perder la verificación TLS. Se evita una gema HTTP adicional.
2. **Resolución con `Resolv::DNS`** (A + AAAA), no `getaddrinfo`, para que `/etc/hosts` no participe. Se rechaza el host si **cualquiera** de sus registros está bloqueado.
3. **Formas IPv6 que llevan una IPv4 dentro** (mapeada, compatible, NAT64 `64:ff9b::/96`, 6to4 `2002::/16`) se evalúan por la IPv4 que contienen. Teredo (`2001::/32`) se bloquea entero.
4. **Hosts solo numéricos** (`2130706433`, `0x7f.1`, `0177.0.0.1`) se rechazan siempre, aunque nuestro resolver no los interprete como IP, porque otros componentes (navegador del renderer, librerías) sí lo hacen.
5. **Descompresión propia (`BodyReader`)**. El inflater de `Net::HTTP` no se puede interrumpir a mitad de cuerpo (falla al cerrar con `closed?` sobre el Inflater). Enviamos `Accept-Encoding` nosotros, lo que desactiva la decodificación automática, e inflamos en streaming. El límite de bytes se aplica al contenido **descomprimido** (protege frente a bombas gzip).
6. **Rate limit por host con GCRA en Redis** (script Lua y reloj de Redis): ráfaga de 1, de modo que con `rps = 2` las peticiones salen separadas ≥ 0,5 s sin importar cuántos workers haya. Los jobs usan `reserve` y se reencolan; las descargas puntuales usan `acquire`.
7. **`AdaptiveRate` es un objeto inmutable sin I/O**. La Épica B lo persiste en la fila del crawl (con `with_lock`) y actúa según la decisión (`:slow_down` / `:pause`).
8. **Lista blanca de IPs solo para tests**: `SafeHttp.config.allow_ips_for_tests!` lanza `SecurityError` fuera de `test`, y `IpPolicy` la ignora fuera de `test` aunque esté poblada. Ambos comportamientos tienen spec.

## Limitaciones conocidas

- El camino TLS se comprobó contra sitios reales (example.com, wikipedia.org), pero no hay spec automática con un servidor HTTPS local.
- Los nombres internos del despliegue (`postgres`, `redis`, `renderer`) se bloquean al no tener punto o por resolver a IPs privadas; si se despliega con nombres públicos, conviene añadirlos a `HostPolicy::BLOCKED_HOSTNAMES`.
- Las capas de infraestructura (IMDSv2 con hop limit 1, egress del security group, Smokescreen) siguen pendientes para el despliegue.
