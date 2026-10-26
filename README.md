# Herramientas · Grupo ECIPSA

Hall con ingreso único. Publicado en https://mmmsa221.github.io/

- `index.html`: login, recuperación y cambio de contraseña, y las tarjetas de las herramientas (lista `HERRAMIENTAS`).
- `sesion.js`: sesión compartida. Cada herramienta lo incluye y llama a `ECI.exigir('<herramienta>')`.

Usuarios y permisos: tabla `public.accesos` del Supabase de Herramientas (ver `sql/004_logins.sql` en el repo AnalisisCabida).
