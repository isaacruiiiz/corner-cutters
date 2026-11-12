-- Corner Cutters · blindaje antes del lanzamiento, telemetría y épocas en la nube
-- Ejecutar en el SQL Editor DESPUÉS de schema.sql y cuentas.sql. Se puede volver a ejecutar sin romper nada.
--
-- Qué cambia:
--   1. Partidas: tope de tamaño y progreso de épocas (medallas) en la nube.
--   2. Partidas de época: una ranura por época y usuario.
--   3. Ranking: ya no se escribe directamente desde el móvil. Lo escribe guardar_partida(),
--      con topes, alias filtrado y un mínimo de segundos entre subidas.
--   4. Admin: el correo del dueño solo da admin si está confirmado.
--   5. Compras anotadas: acotadas (no se puede llenar la tabla).
--   6. Telemetría propia: eventos de uso y errores, visibles en el panel admin.

-- =====================================================================
-- 1. Partidas
-- =====================================================================
alter table public.partidas add column if not exists epocas jsonb;

alter table public.partidas drop constraint if exists partidas_tamano;
alter table public.partidas add constraint partidas_tamano
  check (octet_length(datos) <= 2000000) not valid;
alter table public.partidas drop constraint if exists partidas_epocas_tamano;
alter table public.partidas add constraint partidas_epocas_tamano
  check (epocas is null or pg_column_size(epocas) <= 8000) not valid;

-- =====================================================================
-- 2. Partidas de época (pack de épocas): una ranura por época
-- =====================================================================
create table if not exists public.partidas_epoca (
  user_id uuid not null references auth.users(id) on delete cascade,
  epoca text not null check (epoca in ('1888', '1929', '1980', '2005', '2020', '2050')),
  datos text not null check (octet_length(datos) <= 2000000),
  actualizado timestamptz not null default now(),
  primary key (user_id, epoca)
);
alter table public.partidas_epoca enable row level security;

drop policy if exists "partidas_epoca: leer la propia" on public.partidas_epoca;
create policy "partidas_epoca: leer la propia" on public.partidas_epoca
  for select using (auth.uid() = user_id);
drop policy if exists "partidas_epoca: escribir la propia" on public.partidas_epoca;
create policy "partidas_epoca: escribir la propia" on public.partidas_epoca
  for insert with check (auth.uid() = user_id);
drop policy if exists "partidas_epoca: actualizar la propia" on public.partidas_epoca;
create policy "partidas_epoca: actualizar la propia" on public.partidas_epoca
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "partidas_epoca: borrar la propia" on public.partidas_epoca;
create policy "partidas_epoca: borrar la propia" on public.partidas_epoca
  for delete using (auth.uid() = user_id);

-- =====================================================================
-- 3. Ranking
-- =====================================================================
-- Palabras que no pueden salir en un alias. Se comparan sin acentos, sin espacios y con las
-- cifras cambiadas por letras (p. ej. «1d10ta» = «idiota»). Para añadir más:
--   insert into public.alias_vetados (patron) values
  -- suplantación
  ('admin'), ('moderador'), ('moderator'), ('soporte'), ('support'), ('oficial'), ('official'), ('cornercutters'),
  -- español y catalán
  ('puta'), ('puto'), ('zorra'), ('mierda'), ('cabron'), ('gilipollas'), ('subnormal'), ('maricon'),
  ('bollera'), ('coño'), ('follar'), ('violador'), ('violacion'), ('nazi'), ('hitler'), ('negrata'),
  ('sudaca'), ('panchito'), ('retrasado'), ('mongolo'), ('pedofilo'), ('pederasta'), ('hijoputa'),
  ('hijodeputa'), ('joputa'), ('malparit'),
  -- inglés
  ('fuck'), ('shit'), ('bitch'), ('cunt'), ('nigger'), ('nigga'), ('faggot'), ('retard'), ('whore'),
  ('slut'), ('rapist'), ('pussy'), ('asshole'), ('tranny'),
  -- alemán
  ('arschloch'), ('fotze'), ('schwuchtel'), ('wichser'), ('scheisse'), ('neger')
on conflict do nothing;

create or replace function public.alias_limpio(a text)
returns text
language plpgsql stable security definer
set search_path = public
as $$
declare
  s text;
  n text;
begin
  s := regexp_replace(coalesce(a, ''), '[[:cntrl:]]', '', 'g');
  s := btrim(regexp_replace(s, '\s+', ' ', 'g'));
  s := left(s, 24);
  if char_length(s) < 2 then return 'Promotor anónimo'; end if;
  n := lower(s);
  n := translate(n, 'áàäâéèëêíìïîóòöôúùüû0134578@$', 'aaaaeeeeiiiioooouuuuoieastbas');
  n := regexp_replace(n, '[^a-zñç]', '', 'g');
  if exists (select 1 from public.alias_vetados v where n like '%' || v.patron || '%') then
    return 'Promotor anónimo';
  end if;
  return s;
end;
$$;

-- Guarda la partida y publica la fila del ranking. Única forma de escribir en el ranking.
--   · Como mucho una subida cada 5 segundos.
--   · Los invitados (sin correo) salen siempre como «Promotor anónimo».
--   · Cifras imposibles (NaN, infinito, fuera de rango) se recortan.
create or replace function public.guardar_partida(
  p_datos text,
  p_alias text,
  p_patrimonio double precision,
  p_reputacion int,
  p_ciudad text,
  p_epocas jsonb default null
)
returns json
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  invitado boolean;
  ultima timestamptz;
  v_alias text;
  v_pat double precision;
  v_rep int;
  v_ciudad text;
begin
  if uid is null then raise exception 'Sin sesión'; end if;
  if p_datos is null or octet_length(p_datos) > 2000000 then raise exception 'Partida demasiado grande'; end if;
  if p_epocas is not null and pg_column_size(p_epocas) > 8000 then p_epocas := null; end if;

  select actualizado into ultima from public.partidas where user_id = uid;
  if ultima is not null and ultima > now() - interval '5 seconds' then
    return json_build_object('ok', false, 'motivo', 'espera');
  end if;

  select coalesce(u.is_anonymous, false) or u.email is null into invitado from auth.users u where u.id = uid;
  invitado := coalesce(invitado, true);

  v_pat := p_patrimonio;
  if v_pat is null or v_pat = 'NaN'::double precision or v_pat in ('Infinity'::double precision, '-Infinity'::double precision) then
    v_pat := 0;
  end if;
  v_pat := greatest(-1e12, least(1e15, v_pat));
  v_rep := greatest(0, least(100000000, coalesce(p_reputacion, 0)));
  v_ciudad := left(btrim(regexp_replace(coalesce(p_ciudad, ''), '[[:cntrl:]]', '', 'g')), 40);
  v_alias := case when invitado then 'Promotor anónimo' else public.alias_limpio(p_alias) end;

  insert into public.partidas (user_id, datos, patrimonio, reputacion, ciudad, epocas, actualizado)
  values (uid, p_datos, v_pat, v_rep, v_ciudad, p_epocas, now())
  on conflict (user_id) do update
    set datos = excluded.datos, patrimonio = excluded.patrimonio, reputacion = excluded.reputacion,
        ciudad = excluded.ciudad, epocas = coalesce(excluded.epocas, public.partidas.epocas), actualizado = now();

  insert into public.ranking (user_id, alias, patrimonio, reputacion, ciudad, actualizado)
  values (uid, v_alias, v_pat, v_rep, v_ciudad, now())
  on conflict (user_id) do update
    set alias = excluded.alias, patrimonio = excluded.patrimonio, reputacion = excluded.reputacion,
        ciudad = excluded.ciudad, actualizado = now();

  return json_build_object('ok', true, 'alias', v_alias, 'invitado', invitado);
end;
$$;

revoke all on function public.guardar_partida(text, text, double precision, int, text, jsonb) from public, anon;
grant execute on function public.guardar_partida(text, text, double precision, int, text, jsonb) to authenticated;
revoke all on function public.alias_limpio(text) from public, anon;
grant execute on function public.alias_limpio(text) to authenticated;

-- El móvil ya no escribe el ranking directamente (solo lo lee).
drop policy if exists "ranking: escribir la propia" on public.ranking;
drop policy if exists "ranking: actualizar la propia" on public.ranking;

-- Alias que ya estuvieran en el ranking: se pasan por el filtro.
update public.ranking r set alias = public.alias_limpio(r.alias) where r.alias <> public.alias_limpio(r.alias);
update public.ranking r set alias = 'Promotor anónimo'
  from auth.users u
 where u.id = r.user_id and (coalesce(u.is_anonymous, false) or u.email is null) and r.alias <> 'Promotor anónimo';

-- =====================================================================
-- 4. Admin: el correo del dueño solo cuenta si está confirmado
-- =====================================================================
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
revoke all on function public.sync_perfil() from public, anon, authenticated;

-- =====================================================================
-- 5. Compras anotadas: acotadas
-- =====================================================================
alter table public.compras drop constraint if exists compras_plataforma;
alter table public.compras add constraint compras_plataforma
  check (plataforma is null or plataforma in ('android', 'ios', 'macos')) not valid;
alter table public.compras drop constraint if exists compras_id_largo;
alter table public.compras add constraint compras_id_largo
  check (compra_id is null or char_length(compra_id) <= 200) not valid;

create or replace function public.compras_tope()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  -- Dos productos no consumibles: con 12 filas por usuario sobra (restauraciones incluidas).
  if (select count(*) from public.compras where user_id = new.user_id) >= 12 then
    return null;
  end if;
  return new;
end;
$$;
drop trigger if exists compras_tope on public.compras;
create trigger compras_tope before insert on public.compras
  for each row execute function public.compras_tope();
revoke all on function public.compras_tope() from public, anon, authenticated;

-- =====================================================================
-- 6. Telemetría propia (eventos de uso y errores)
-- =====================================================================
-- Sin políticas: solo se escribe con las funciones de abajo y solo lee el admin.
create table if not exists public.eventos (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade,
  nombre text not null,
  datos jsonb,
  version text,
  plataforma text,
  idioma text,
  creado timestamptz not null default now()
);
create index if not exists eventos_nombre_creado on public.eventos (nombre, creado desc);
create index if not exists eventos_usuario on public.eventos (user_id, creado);
alter table public.eventos enable row level security;

-- Errores agrupados (sin usuario): cuántas veces y en qué versión.
create table if not exists public.errores (
  id bigint generated always as identity primary key,
  huella text not null,
  version text not null default '',
  plataforma text,
  mensaje text not null,
  pila text,
  veces int not null default 1,
  primero timestamptz not null default now(),
  ultimo timestamptz not null default now(),
  unique (huella, version)
);
alter table public.errores enable row level security;

-- Cuota diaria por usuario (para que nadie llene las tablas).
create table if not exists public.telemetria_cuota (
  user_id uuid not null references auth.users(id) on delete cascade,
  dia date not null default current_date,
  eventos int not null default 0,
  errores int not null default 0,
  primary key (user_id, dia)
);
alter table public.telemetria_cuota enable row level security;

-- Lote de eventos: [{"n": "nombre", "t": milisegundos, "d": {…}}, …]. Devuelve cuántos ha guardado.
create or replace function public.registrar_eventos(
  lote jsonb,
  p_version text default null,
  p_plataforma text default null,
  p_idioma text default null
)
returns int
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  usados int;
  libres int;
  n int;
begin
  if uid is null or lote is null or jsonb_typeof(lote) <> 'array' then return 0; end if;
  insert into public.telemetria_cuota (user_id, dia) values (uid, current_date) on conflict do nothing;
  select c.eventos into usados from public.telemetria_cuota c where c.user_id = uid and c.dia = current_date;
  libres := greatest(0, 300 - coalesce(usados, 0));
  if libres = 0 then return 0; end if;

  with x as (
    select t.e
    from jsonb_array_elements(lote) with ordinality as t(e, i)
    where jsonb_typeof(t.e) = 'object'
      and (t.e ->> 'n') ~ '^[a-z0-9_]{2,40}$'
      and pg_column_size(t.e) < 1200
    order by t.i
    limit least(libres, 60)
  ), ins as (
    insert into public.eventos (user_id, nombre, datos, version, plataforma, idioma, creado)
    select uid,
           x.e ->> 'n',
           case when jsonb_typeof(x.e -> 'd') = 'object' then x.e -> 'd' end,
           left(p_version, 20), left(p_plataforma, 12), left(p_idioma, 5),
           least(now(), greatest(now() - interval '3 days',
             case when (x.e ->> 't') ~ '^\d{10,14}$' then to_timestamp((x.e ->> 't')::bigint / 1000.0) else now() end))
    from x
    returning 1
  )
  select count(*) into n from ins;

  update public.telemetria_cuota c set eventos = c.eventos + n where c.user_id = uid and c.dia = current_date;
  return n;
end;
$$;

-- Un error de la app. Se agrupa por mensaje + primera línea de la pila + versión.
create or replace function public.registrar_error(
  p_mensaje text,
  p_pila text default null,
  p_version text default null,
  p_plataforma text default null
)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  usados int;
  v_msg text := left(btrim(coalesce(p_mensaje, '')), 500);
  v_pila text := left(coalesce(p_pila, ''), 4000);
begin
  if uid is null or v_msg = '' then return; end if;
  insert into public.telemetria_cuota (user_id, dia) values (uid, current_date) on conflict do nothing;
  select c.errores into usados from public.telemetria_cuota c where c.user_id = uid and c.dia = current_date;
  if coalesce(usados, 0) >= 20 then return; end if;
  update public.telemetria_cuota c set errores = c.errores + 1 where c.user_id = uid and c.dia = current_date;

  insert into public.errores (huella, version, plataforma, mensaje, pila)
  values (md5(left(v_msg, 200) || '|' || split_part(v_pila, E'\n', 1)), left(coalesce(p_version, ''), 20),
          left(p_plataforma, 12), v_msg, nullif(v_pila, ''))
  on conflict (huella, version) do update
    set veces = public.errores.veces + 1, ultimo = now();
end;
$$;

-- ---------------------------------------------------------------- panel admin
-- Embudo: cuántos jugadores distintos han llegado a cada paso en los últimos N días.
create or replace function public.admin_embudo(dias int default 14)
returns table (nombre text, usuarios bigint, veces bigint)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  return query
  select e.nombre, count(distinct e.user_id), count(*)
  from public.eventos e
  where e.creado > now() - make_interval(days => greatest(1, least(dias, 120)))
  group by e.nombre
  order by count(distinct e.user_id) desc, e.nombre;
end;
$$;

-- Retención: de los que abrieron el juego por primera vez cada día, cuántos volvieron al día siguiente y a la semana.
create or replace function public.admin_retencion(dias int default 14)
returns table (dia date, nuevos bigint, d1 bigint, d7 bigint)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  return query
  with aperturas as (
    select distinct e.user_id, (e.creado at time zone 'utc')::date as d
    from public.eventos e
    where e.nombre = 'abrir' and e.user_id is not null
  ), primera as (
    select a.user_id, min(a.d) as d0 from aperturas a group by a.user_id
  )
  select p.d0,
         count(*),
         count(*) filter (where exists (select 1 from aperturas a where a.user_id = p.user_id and a.d = p.d0 + 1)),
         count(*) filter (where exists (select 1 from aperturas a where a.user_id = p.user_id and a.d = p.d0 + 7))
  from primera p
  where p.d0 > current_date - greatest(1, least(dias, 120))
  group by p.d0
  order by p.d0 desc;
end;
$$;

create or replace function public.admin_errores(limite int default 50)
returns table (id bigint, mensaje text, pila text, version text, plataforma text, veces int, primero timestamptz, ultimo timestamptz)
language plpgsql stable security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  return query
  select e.id, e.mensaje, e.pila, e.version, e.plataforma, e.veces, e.primero, e.ultimo
  from public.errores e
  order by e.ultimo desc
  limit greatest(1, least(limite, 200));
end;
$$;

-- Limpieza: eventos de más de 120 días, errores sin repetirse en 90 y cuotas viejas. La llama el panel al abrirse.
create or replace function public.admin_limpiar_telemetria()
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  delete from public.eventos where creado < now() - interval '120 days';
  delete from public.errores where ultimo < now() - interval '90 days';
  delete from public.telemetria_cuota where dia < current_date - 7;
end;
$$;

-- Un error ya resuelto se puede quitar de la lista.
create or replace function public.admin_borrar_error(error_id bigint)
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  if not public.es_admin() then raise exception 'Solo para administradores'; end if;
  delete from public.errores where id = error_id;
end;
$$;

revoke all on function public.registrar_eventos(jsonb, text, text, text) from public, anon;
revoke all on function public.registrar_error(text, text, text, text) from public, anon;
revoke all on function public.admin_embudo(int) from public, anon;
revoke all on function public.admin_retencion(int) from public, anon;
revoke all on function public.admin_errores(int) from public, anon;
revoke all on function public.admin_limpiar_telemetria() from public, anon;
revoke all on function public.admin_borrar_error(bigint) from public, anon;
grant execute on function public.registrar_eventos(jsonb, text, text, text) to authenticated;
grant execute on function public.registrar_error(text, text, text, text) to authenticated;
grant execute on function public.admin_embudo(int) to authenticated;
grant execute on function public.admin_retencion(int) to authenticated;
grant execute on function public.admin_errores(int) to authenticated;
grant execute on function public.admin_limpiar_telemetria() to authenticated;
grant execute on function public.admin_borrar_error(bigint) to authenticated;
