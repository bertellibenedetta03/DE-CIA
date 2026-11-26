-- =====================================================================
-- DE CIA · Coincidenze
-- 005 · Tabelle del prototipo dell'app (viaggiatore, capotreno, regia)
--
-- Aggiunge 3 tabelle nuove, tutte con il prefisso "app_".
-- Non tocca le tabelle della ricerca né la tabella "messaggi".
--
--   app_viaggio    lo stato del viaggio di prova (ritardo deciso dalla Regia)
--   app_richieste  le richieste "Avvisa il capotreno" e il loro stato
--   app_push       i telefoni che hanno attivato le notifiche
--
-- RLS attiva e nessuna regola pubblica: solo la funzione del sito
-- (con la chiave segreta, su Vercel) può leggere e scrivere.
--
-- Si può eseguire anche più volte: non cancella niente.
-- =====================================================================

create table if not exists public.app_viaggio (
  id                     text primary key,
  ritardo_min            integer not null default 0 check (ritardo_min between 0 and 180),
  minuti_attraversamento integer not null default 4 check (minuti_attraversamento between 0 and 30),
  minuti_timeout         integer not null default 3 check (minuti_timeout between 1 and 60),
  aggiornato_il          timestamptz not null default now()
);

comment on table public.app_viaggio is
  'Prototipo app: stato del viaggio di prova Bevilacqua → Monselice → Ferrara. Il ritardo lo decide la Regia.';

insert into public.app_viaggio (id) values ('bevilacqua-monselice-ferrara')
on conflict (id) do nothing;

create table if not exists public.app_richieste (
  id              bigint generated always as identity primary key,
  viaggio_id      text not null default 'bevilacqua-monselice-ferrara'
                  references public.app_viaggio (id) on delete cascade,
  viaggiatore_id  text not null check (char_length(viaggiatore_id) between 8 and 64),
  nome            text check (char_length(nome) <= 60),
  stato           text not null default 'inviata'
                  check (stato in ('inviata', 'vista', 'stiamo_chiedendo', 'confermata',
                                   'rifiutata', 'non_serve_piu', 'nessuna_risposta', 'annullata')),
  creata_il       timestamptz not null default now(),
  aggiornata_il   timestamptz not null default now()
);

comment on table public.app_richieste is
  'Prototipo app: richieste di coincidenza dal viaggiatore al capotreno, con il loro stato.';

create index if not exists app_richieste_viaggio_idx on public.app_richieste (viaggio_id, creata_il desc);
create index if not exists app_richieste_viaggiatore_idx on public.app_richieste (viaggiatore_id);

create table if not exists public.app_push (
  endpoint        text primary key,
  p256dh          text not null,
  auth            text not null,
  ruolo           text not null check (ruolo in ('viaggiatore', 'capotreno')),
  viaggiatore_id  text,
  creato_il       timestamptz not null default now()
);

comment on table public.app_push is
  'Prototipo app: telefoni che hanno attivato le notifiche (indirizzo tecnico del browser, nessun dato personale).';

alter table public.app_viaggio   enable row level security;
alter table public.app_richieste enable row level security;
alter table public.app_push      enable row level security;

grant usage on schema public to service_role;
grant select, insert, update, delete on public.app_viaggio, public.app_richieste, public.app_push to service_role;
grant usage, select on all sequences in schema public to service_role;
