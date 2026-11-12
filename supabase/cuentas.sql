-- Corner Cutters · cuentas, roles, DLC regalado y compras
-- Ejecutar en el SQL Editor DESPUÉS de schema.sql. Se puede volver a ejecutar sin romper nada.
--
-- Tres tipos de usuario:
--   usuario  · con anuncios (opcionales y algún intersticial)
--   pro      · sin anuncios
--   admin    · sin anuncios, todo desbloqueado y acceso al panel
-- Cualquiera puede comprar el pack de épocas en la tienda. Además, el admin puede
-- regalarlo (dlc_epocas = true). Las compras de la tienda las valida Google Play / App Store
-- en el propio móvil; aquí solo se anotan para verlas en el panel.

-- ---------------------------------------------------------------- perfiles
create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  rol text not null default 'usuario' check (rol in ('usuario', 'pro', 'admin')),
  dlc_epocas boolean not null default false,
  dlc_regalado_por uuid references auth.users(id) on delete set null,
  dlc_regalado_en timestamptz,
  nota text,
  creado timestamptz not null default now(),
  visto timestamptz not null default now()
);

create index if not exists perfiles_email on public.perfiles (lower(email));
alter table public.perfiles enable row level security;

-- ¿Quien llama es admin? (security definer para poder leer perfiles sin recursión de RLS)
create or replace function public.es_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.perfiles where id = auth.uid() and rol = 'admin');
$$;

drop policy if exists "perfiles: leer el propio o admin" on public.perfiles;
create policy "perfiles: leer el propio o admin" on public.perfiles
  for select using (auth.uid() = id or public.es_admin());
-- Sin políticas de escritura: los cambios van por las funciones de abajo.

-- Correo del dueño del juego: su cuenta es admin desde que existe.
create or replace function public.correo_admin()
returns text language sql immutable as $$ select 'isaacruiiiz04@gmail.com'::text $$;

-- Alta y cambio de correo en auth.users → perfil.
-- El correo del dueño solo da admin si está confirmado (nadie puede registrarlo sin acceso al buzón).
create or replace function public.sync_perfil()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  duenyo boolean := new.email_confirmed_at is not null
                    and lower(coalesce(new.email, '')) = public.correo_admin();
begin
  insert into public.perfiles (id, email, rol)
  values (new.id, new.email, case when duenyo then 'admin' else 'usuario' end)
  on conflict (id) do update
    set email = excluded.email,
        rol = case when duenyo then 'admin' else public.perfiles.rol end;
  return new;
end;
$$;

drop trigger if exists perfiles_alta on auth.users;
create trigger perfiles_alta after insert or update of email, email_confirmed_at on auth.users
  for each row execute function public.sync_perfil();

-- Usuarios que ya existían.
insert into public.perfiles (id, email, rol)
select u.id, u.email,
       case when u.email_confirmed_at is not null and lower(coalesce(u.email, '')) = public.correo_admin() then 'admin' else 'usuario' end
from auth.users u
on conflict (id) do update set email = excluded.email,
  rol = case when excluded.rol = 'admin' then 'admin' else public.perfiles.rol end;

-- ---------------------------------------------------------------- compras (solo registro)
create table if not exists public.compras (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  producto text not null check (producto in ('cc_epocas', 'cc_pro')),
  plataforma text,
  compra_id text,
  creado timestamptz not null default now(),
  unique (user_id, producto, compra_id)
);
alter table public.compras enable row level security;

drop policy if exists "compras: leer las propias o admin" on public.compras;
create policy "compras: leer las propias o admin" on public.compras
  for select using (auth.uid() = user_id or public.es_admin());
drop policy if exists "compras: anotar las propias" on public.compras;
create policy "compras: anotar las propias" on public.compras
  for insert with check (auth.uid() = user_id);

-- ---------------------------------------------------------------- la app
-- Perfil propio (lo crea si falta, p. ej. cuentas anónimas antiguas) y marca la última visita.
create or replace function public.mi_perfil()
returns json
language plpgsql security definer
set search_path = public
as $$
declare r public.perfiles;
begin
  if auth.uid() is null then return null; end if;
  insert into public.perfiles (id, email) select id, email from auth.users where id = auth.uid()
  on conflict (id) do nothing;
  update public.perfiles set visto = now() where id = auth.uid() returning * into r;
  return json_build_object('rol', r.rol, 'dlc_epocas', r.dlc_epocas, 'email', r.email);
end;
$$;

-- ---------------------------------------------------------------- panel admin
create or replace function public.admin_resumen()
returns json
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  return json_build_object(
    'usuarios', (select count(*) from public.perfiles),
    'con_correo', (select count(*) from public.perfiles where email is not null),
    'pro', (select count(*) from public.perfiles where rol = 'pro'),
    'admin', (select count(*) from public.perfiles where rol = 'admin'),
    'dlc_regalado', (select count(*) from public.perfiles where dlc_epocas),
    'compras_epocas', (select count(distinct user_id) from public.compras where producto = 'cc_epocas'),
    'compras_pro', (select count(distinct user_id) from public.compras where producto = 'cc_pro'),
    'activos_7d', (select count(*) from public.perfiles where visto > now() - interval '7 days'),
    'nuevos_7d', (select count(*) from public.perfiles where creado > now() - interval '7 days')
  );
end;
$$;

create or replace function public.admin_usuarios(buscar text default '', solo_correo boolean default false, limite int default 50, desde int default 0)
returns table (
  id uuid, email text, rol text, dlc_epocas boolean, dlc_regalado_en timestamptz, nota text,
  creado timestamptz, visto timestamptz, alias text, patrimonio double precision, reputacion int,
  compro_epocas boolean, compro_pro boolean
)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  return query
  select p.id, p.email, p.rol, p.dlc_epocas, p.dlc_regalado_en, p.nota, p.creado, p.visto,
         r.alias, r.patrimonio, r.reputacion,
         exists (select 1 from public.compras c where c.user_id = p.id and c.producto = 'cc_epocas'),
         exists (select 1 from public.compras c where c.user_id = p.id and c.producto = 'cc_pro')
  from public.perfiles p
  left join public.ranking r on r.user_id = p.id
  where (not solo_correo or p.email is not null)
    and (coalesce(buscar, '') = ''
         or p.email ilike '%' || buscar || '%'
         or r.alias ilike '%' || buscar || '%'
         or p.id::text ilike buscar || '%')
  order by (p.rol = 'admin') desc, p.visto desc
  limit greatest(1, least(limite, 200)) offset greatest(0, desde);
end;
$$;

create or replace function public.admin_set_rol(usuario uuid, nuevo_rol text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  if nuevo_rol not in ('usuario', 'pro', 'admin') then raise exception 'Rol no válido'; end if;
  if usuario = auth.uid() and nuevo_rol <> 'admin' then raise exception 'No puedes quitarte el admin a ti mismo'; end if;
  update public.perfiles set rol = nuevo_rol where id = usuario;
end;
$$;

create or replace function public.admin_regalar_dlc(usuario uuid, regalar boolean)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  update public.perfiles
     set dlc_epocas = regalar,
         dlc_regalado_por = case when regalar then auth.uid() else null end,
         dlc_regalado_en = case when regalar then now() else null end
   where id = usuario;
end;
$$;

create or replace function public.admin_nota(usuario uuid, texto text)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  update public.perfiles set nota = nullif(left(texto, 500), '') where id = usuario;
end;
$$;

create or replace function public.admin_compras(limite int default 50)
returns table (id bigint, user_id uuid, email text, producto text, plataforma text, compra_id text, creado timestamptz)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  return query
  select c.id, c.user_id, p.email, c.producto, c.plataforma, c.compra_id, c.creado
  from public.compras c left join public.perfiles p on p.id = c.user_id
  order by c.creado desc limit greatest(1, least(limite, 200));
end;
$$;

-- Titulares: el admin los gestiona desde el panel.
drop policy if exists "titulares: admin todo" on public.titulares;
create policy "titulares: admin todo" on public.titulares
  for all using (public.es_admin()) with check (public.es_admin());

-- Solo usuarios con sesión pueden llamar a las funciones (y dentro se comprueba el rol).
revoke all on function public.mi_perfil() from public, anon;
revoke all on function public.admin_resumen() from public, anon;
revoke all on function public.admin_usuarios(text, boolean, int, int) from public, anon;
revoke all on function public.admin_set_rol(uuid, text) from public, anon;
revoke all on function public.admin_regalar_dlc(uuid, boolean) from public, anon;
revoke all on function public.admin_nota(uuid, text) from public, anon;
revoke all on function public.admin_compras(int) from public, anon;
revoke all on function public.sync_perfil() from public, anon, authenticated;
grant execute on function public.mi_perfil() to authenticated;
grant execute on function public.admin_resumen() to authenticated;
grant execute on function public.admin_usuarios(text, boolean, int, int) to authenticated;
grant execute on function public.admin_set_rol(uuid, text) to authenticated;
grant execute on function public.admin_regalar_dlc(uuid, boolean) to authenticated;
grant execute on function public.admin_nota(uuid, text) to authenticated;
grant execute on function public.admin_compras(int) to authenticated;

-- =====================================================================
-- Borrar cuenta (lo exige Google Play). El jugador borra su propia cuenta:
-- partida, ranking, perfil y compras anotadas se van en cascada.
-- =====================================================================
create or replace function public.borrar_mi_cuenta()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Sin sesión';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.borrar_mi_cuenta() from public, anon;
grant execute on function public.borrar_mi_cuenta() to authenticated;
