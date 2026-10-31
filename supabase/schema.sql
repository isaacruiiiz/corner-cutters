-- Corner Cutters · esquema de Supabase
-- Ejecutar en el SQL Editor del proyecto. Requiere activar "Anonymous sign-ins"
-- en Authentication → Providers (la app entra en modo anónimo y luego se puede vincular un email).

-- Partida en la nube (una por usuario).
create table if not exists public.partidas (
  user_id uuid primary key references auth.users(id) on delete cascade,
  datos text not null,
  patrimonio double precision not null default 0,
  reputacion int not null default 0,
  ciudad text,
  actualizado timestamptz not null default now()
);

alter table public.partidas enable row level security;

drop policy if exists "partidas: leer la propia" on public.partidas;
create policy "partidas: leer la propia" on public.partidas
  for select using (auth.uid() = user_id);
drop policy if exists "partidas: escribir la propia" on public.partidas;
create policy "partidas: escribir la propia" on public.partidas
  for insert with check (auth.uid() = user_id);
drop policy if exists "partidas: actualizar la propia" on public.partidas;
create policy "partidas: actualizar la propia" on public.partidas
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "partidas: borrar la propia" on public.partidas;
create policy "partidas: borrar la propia" on public.partidas
  for delete using (auth.uid() = user_id);

-- Ranking público (alias, patrimonio, reputación).
create table if not exists public.ranking (
  user_id uuid primary key references auth.users(id) on delete cascade,
  alias text not null default 'Promotor anónimo' check (char_length(alias) between 2 and 24),
  patrimonio double precision not null default 0,
  reputacion int not null default 0,
  ciudad text,
  actualizado timestamptz not null default now()
);

alter table public.ranking enable row level security;

drop policy if exists "ranking: lectura pública" on public.ranking;
create policy "ranking: lectura pública" on public.ranking
  for select using (true);
drop policy if exists "ranking: escribir la propia" on public.ranking;
create policy "ranking: escribir la propia" on public.ranking
  for insert with check (auth.uid() = user_id);
drop policy if exists "ranking: actualizar la propia" on public.ranking;
create policy "ranking: actualizar la propia" on public.ranking
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists ranking_orden on public.ranking (reputacion desc, patrimonio desc);

-- Titulares del mercado editables desde el panel (opcional).
create table if not exists public.titulares (
  id bigint generated always as identity primary key,
  texto text not null,
  activo boolean not null default true,
  creado timestamptz not null default now()
);

alter table public.titulares enable row level security;
drop policy if exists "titulares: lectura pública" on public.titulares;
create policy "titulares: lectura pública" on public.titulares
  for select using (activo);

insert into public.titulares (texto) values
  ('Los precios suben. Los expertos, que lo vieron venir, también'),
  ('Analistas confirman que esta vez es diferente'),
  ('El mercado se ha corregido. Como siempre, por sorpresa')
on conflict do nothing;
