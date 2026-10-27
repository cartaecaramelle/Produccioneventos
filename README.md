# Producción de Eventos (prueba de concepto)

App web (HTML + Tailwind + JS) con Supabase. Se instala como app en móvil, tablet y PC (PWA).

## Puesta en marcha
1. **Supabase**: crea un proyecto y, en Authentication > Users, los usuarios `admin@produccion.local` y `cocina@produccion.local` (marca *Auto Confirm User*). Desactiva los registros nuevos en Providers > Email.
2. **SQL Editor**: ejecuta `sql/01_setup.sql`. Opcional: `sql/02_datos_demo.sql` carga 4 eventos y recetas reales de tus Excel.
3. **index.html**: pega `SUPABASE_URL` y `SUPABASE_ANON_KEY` (Project Settings > API) en las dos constantes del inicio.
4. **GitHub**: sube todo el contenido de esta carpeta a un repositorio y activa Settings > Pages (rama `main`, carpeta `/root`).
5. Abre el enlace y entra con `admin` o `cocina`. Para instalarla: «Añadir a pantalla de inicio» (móvil) o el icono de instalar en la barra del navegador (PC).

## Límites de la prueba de concepto
- Necesita internet; el modo sin conexión no está implementado.
- Usuario único compartido para cocina (no se sabe quién marca cada estado).
- Seguridad = políticas RLS de `01_setup.sql`. Nunca pongas la clave `service_role` en el HTML.
- Pendiente: Coffees, mermas, temperaturas, conversiones, pedidos, carros de fritura/panes y escalado de recetas.
