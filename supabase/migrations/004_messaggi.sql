-- =====================================================================
-- DE CIA · Coincidenze
-- 004 · Messaggi dal modulo contatti del sito
--
-- Ogni volta che qualcuno compila il modulo "Racconta la tua
-- coincidenza" sul sito, il messaggio viene salvato qui e il team
-- riceve un'email (tramite Resend).
--
-- RLS attiva e nessuna regola pubblica: solo la funzione del sito
-- (con la chiave segreta, su Vercel) può scrivere, e solo voi dal
-- pannello Supabase potete leggere.
--
-- Si può eseguire anche più volte: non cancella niente.
-- =====================================================================

create table if not exists public.messaggi (
  id             bigint generated always as identity primary key,
  creato_il      timestamptz not null default now(),
  nome           text,
  email          text,
  tipo           text not null default 'testimonianza'
                 check (tipo in ('testimonianza', 'domanda', 'altro')),
  tratta         text,
  messaggio      text not null check (char_length(messaggio) between 1 and 5000),
  consenso       boolean not null default false,
  email_inviata  boolean not null default false,
  letto          boolean not null default false,
  note_team      text
);

comment on table public.messaggi is
  'Messaggi e testimonianze lasciati dai visitatori nel modulo contatti del sito.';

alter table public.messaggi enable row level security;

create index if not exists messaggi_creato_il_idx on public.messaggi (creato_il desc);

-- La funzione del sito usa la chiave segreta (ruolo service_role):
-- nei progetti Supabase recenti il permesso va dato esplicitamente.
grant usage on schema public to service_role;
grant select, insert, update on public.messaggi to service_role;
grant usage, select on all sequences in schema public to service_role;
