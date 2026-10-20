# Despliegue en Render (plan gratuito)

El repositorio incluye un Blueprint, [`render.yaml`](../render.yaml), que crea tres recursos gratuitos:

| Recurso | Qué es |
|---|---|
| `seo-platform` (web, `free`) | Puma con **Sidekiq embebido** (`SIDEKIQ_EMBEDDED=true`). El plan gratuito no tiene workers. |
| `seo-platform-db` (Postgres, `free`) | Base de datos. |
| `seo-platform-kv` (Key Value, `free`) | Redis para Sidekiq, Action Cable y el límite de velocidad por host. |

## Pasos

1. **Sube el repositorio a GitHub** (o GitLab). Render despliega desde un repositorio remoto. Hoy el repo no tiene remoto:

   ```bash
   git remote add origin git@github.com:TU_USUARIO/seo-platform.git
   ```

   ```bash
   git push -u origin main
   ```

   Puede ser privado; Render pedirá acceso a él. `config/master.key` está en `.gitignore` y **no** se sube.
2. En Render: **New → Blueprint**, elige el repositorio y la rama `main`. Render leerá `render.yaml` y pedirá tres valores secretos:
   - `RAILS_MASTER_KEY`: el contenido de `config/master.key` (sin saltos de línea).
   - `ADMIN_EMAIL` y `ADMIN_PASSWORD`: tu usuario, con una contraseña de al menos 12 caracteres. En cada arranque `bin/rails users:ensure` lo crea, o le actualiza la contraseña si la cambias aquí. Lo hacemos así porque el plan gratuito no tiene Shell.
3. Pulsa **Apply**. El build ejecuta `bundle install` y `assets:precompile`. El arranque ejecuta `db:prepare`, `users:ensure` y Puma.
4. Abre `https://seo-platform.onrender.com` (o el nombre que asigne Render) e inicia sesión.

Las variables `RENDER_EXTERNAL_URL`, `DATABASE_URL` y `REDIS_URL` las pone Render. El User-Agent del bot enlaza a `/bot`, una página pública que explica qué hace y cómo bloquearlo.

## Límites del plan gratuito (según la documentación de Render, octubre de 2026)

- **La web se duerme tras 15 minutos sin tráfico entrante** y tarda alrededor de 1 minuto en despertar. Mientras duerme, Sidekiq también se detiene: un crawl largo se pausa de hecho y continúa al volver a abrir la app, porque los jobs siguen en Key Value y los claims abandonados se recuperan. Para crawls de 200 páginas a 0,5 req/s (unos 7 minutos) basta con tener la página del crawl abierta.
- **Postgres gratis caduca a los 30 días de crearlo** (más 14 días de gracia), no tiene copias de seguridad y es 1 GB. Sirve para probar; para datos que quieras conservar, pasa a un plan de pago.
- **Key Value gratis no persiste**: si se reinicia, se pierden los jobs en cola. Un crawl en marcha puede quedarse en «Rastreando»; relánzalo.
- **No hay Shell ni one-off jobs.** Por eso el usuario se crea con `users:ensure` y las migraciones corren al arrancar.
- **750 horas de instancia al mes** por workspace (las horas dormida no cuentan).
- **512 MB de RAM y 0,1 CPU**: Puma (3 hilos) + Sidekiq (3 hilos) caben para crawls pequeños y medianos; crawls de miles de páginas irán lentos.

## Seguridad en producción

- La protección SSRF está en la aplicación (`SafeHttp`), así que funciona igual en Render. Las capas de infraestructura del diseño (bloquear la salida a redes privadas, IMDSv2, Smokescreen) no existen aquí; solo importarían si abrieras la app a otros usuarios.
- `force_ssl` está activo; `/up` queda fuera de la redirección para el health check.
- El registro está deshabilitado: solo existe el usuario de `ADMIN_EMAIL`.

## Pasar a un plan de pago

Basta con cambiar `plan:` en `render.yaml`. Con un plan de pago se puede además:
- separar Sidekiq en un servicio `type: worker` con `bundle exec sidekiq -C config/sidekiq.yml` y quitar `SIDEKIQ_EMBEDDED`;
- usar `preDeployCommand: bin/rails db:migrate` en lugar de migrar al arrancar;
- usar el Shell para `bin/rails users:create`.
