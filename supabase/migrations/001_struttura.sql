-- =====================================================================
-- DE CIA · Coincidenze
-- 001 · Struttura del database (tabelle)
--
-- Contiene: progetto e team, documenti originali, fonti, actors map
-- (cluster, attori, flussi), catena decisionale, schema dell'intervista,
-- user journey (studente, capotreno, capostazione), punti di rottura,
-- tre scoperte, domande aperte e tutte le altre note dei file.
--
-- Tutte le tabelle hanno la sicurezza a livello di riga (RLS) attiva e
-- nessuna regola pubblica: i dati si vedono solo dal pannello Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PROGETTO
-- ---------------------------------------------------------------------
create table progetto_info (
  chiave       text primary key,
  valore       text not null,
  categoria    text,              -- progetto, team, materiale, strumenti, preferenze
  fonte        text,              -- da dove viene l'informazione
  aggiornato_il date default current_date
);
comment on table progetto_info is 'Informazioni generali del progetto (dalla memoria del progetto).';

create table team (
  nome          text primary key,
  ruolo         text,
  disponibilita text,
  note          text
);
comment on table team is 'Persone del gruppo DE CIA.';

-- ---------------------------------------------------------------------
-- DOCUMENTI ORIGINALI E FONTI
-- ---------------------------------------------------------------------
create table documenti (
  codice            text primary key,
  titolo            text not null,
  nome_file         text not null,
  tipo_file         text not null,            -- pdf, png, md
  dimensione_kb     integer,
  cartella          text,                     -- cartella di origine
  descrizione       text,
  versione          text,
  data_riferimento  text,
  fonti_dichiarate  text,                     -- fonti scritte nel documento stesso
  percorso_storage  text,                     -- dove sta il file in Supabase Storage (bucket "ricerca")
  testo_estratto    text,                     -- testo integrale estratto dal file
  trascrizione      text,                     -- trascrizione delle parti che nel file sono solo immagine
  note_estrazione   text
);
comment on table documenti is 'Ogni file di ricerca, con il testo integrale e il percorso del file originale nello Storage.';

create table fonti (
  codice      text primary key,
  titolo      text not null,
  tipo        text,          -- intervista, racconto diretto, lista del gruppo, riferimento, inferenza
  data        text,
  descrizione text,
  limiti      text
);
comment on table fonti is 'Le fonti della ricerca e i loro limiti.';

create table riferimenti_intervista (
  codice     text primary key,     -- R1..R13 = risposte, D# = domande senza risposta
  tipo       text not null,        -- risposta, domanda_senza_risposta
  tema       text not null,
  contenuto  text,
  citato_in  text
);
comment on table riferimenti_intervista is 'Le risposte (R) e le domande (D) dell''intervista al capostazione, come citate nei file.';

-- ---------------------------------------------------------------------
-- ACTORS MAP
-- ---------------------------------------------------------------------
create table cluster_attori (
  codice      text primary key,
  nome        text not null,
  colore      text,
  ordine      integer,
  descrizione text
);

create table attori (
  codice          text primary key,
  nome            text not null,
  cluster         text not null references cluster_attori(codice),
  stato           text not null check (stato in ('lista_partenza','confermato_intervista','da_verificare')),
  aspetto_mappa   text,          -- come appare il cerchio nella mappa
  perche_in_mappa text,          -- per i cerchi bianchi: perché è stato aggiunto
  come_verificarlo text,         -- per i cerchi bianchi: come confermarlo o eliminarlo
  valutazione     text,          -- solido, debole, candidato alla rimozione...
  note            text
);
comment on table attori is 'I 40 attori della actors map v2, con cluster e stato (lista di partenza, confermato dall''intervista, da verificare).';

create table tipi_flusso (
  codice      text primary key,
  nome        text not null,
  stile       text,
  descrizione text
);

create table flussi (
  id           bigint generated always as identity primary key,
  tipo         text not null references tipi_flusso(codice),
  da_attore    text references attori(codice),
  da_gruppo    text,              -- quando il flusso parte da un cluster intero
  a_attore     text references attori(codice),
  a_gruppo     text,
  descrizione  text not null,
  origine      text not null check (origine in ('intervista','inferenza')),
  anomalo      boolean default false,   -- dice "qui non funziona" invece di "qui passa qualcosa"
  numero_catena integer,               -- 1..5 se fa parte della catena della coincidenza
  note         text
);
comment on table flussi is 'I flussi della actors map documentati nei file (catena 1-5, flussi dall''intervista, flussi anomali).';

-- ---------------------------------------------------------------------
-- CATENA DECISIONALE E SCHEMA DELL'INTERVISTA
-- ---------------------------------------------------------------------
create table catena_passaggi (
  numero      integer primary key,
  attore      text not null,
  attore_codice text references attori(codice),
  dettaglio   text,
  azione      text not null,
  canale      text,
  condizione  text,
  riferimento text
);
comment on table catena_passaggi is 'I cinque passaggi della catena della coincidenza.';

create table schema_nodi (
  codice       text primary key,
  sezione      text not null,       -- flusso principale, quando la coincidenza salta
  corsia       text,                -- Viaggiatore, Capotreno, Capostazione, Dirigente Centrale, Responsabile impresa
  forma        text not null,       -- azione, decisione, evento, esito, non_documentato
  numero_catena integer,
  testo        text not null,
  riferimento  text,
  documentato  boolean default true
);
comment on table schema_nodi is 'Nodi dello "Schema decisionale: la coincidenza vista dal capostazione".';

create table schema_archi (
  id        bigint generated always as identity primary key,
  da_nodo   text not null references schema_nodi(codice),
  a_nodo    text not null references schema_nodi(codice),
  etichetta text,
  documentato boolean default true
);

create table chi_decide_cosa (
  id        bigint generated always as identity primary key,
  attore    text not null,
  ordine    integer,
  etichetta text not null,     -- DECIDE, NON DECIDE, STRUMENTO, SOGLIA...
  testo     text not null
);
comment on table chi_decide_cosa is 'I riquadri "Chi decide cosa" dello schema dell''intervista.';

-- ---------------------------------------------------------------------
-- USER JOURNEY
-- ---------------------------------------------------------------------
create table journey (
  codice      text primary key,
  titolo      text not null,
  persona     text,
  scenario    text,
  fonte       text,
  nota_bozza  text,
  come_leggere text
);

create table journey_bisogni (
  id       bigint generated always as identity primary key,
  journey  text not null references journey(codice),
  ordine   integer,
  testo    text not null,
  ipotesi  boolean default false
);

create table journey_fasi (
  id          bigint generated always as identity primary key,
  journey     text not null references journey(codice),
  numero      integer not null,
  macro_fase  text not null,          -- Pre-servizio, Servizio, Post-servizio
  titolo      text not null,
  quando_dove text,
  fase_critica boolean default false,
  comportamento_inizio text,
  comportamento_fine   text,
  canali      text[],
  emozione_soddisfatto integer,       -- 0-100, letto dalle barre (le barre sono stime dichiarate nel file)
  emozione_incerto     integer,
  emozione_frustrato   integer,
  unique (journey, numero)
);

create table journey_elementi (
  id        bigint generated always as identity primary key,
  journey   text not null,
  fase      integer not null,
  riga      text not null check (riga in ('azione','touchpoint','attore','domanda','criticita','opportunita')),
  ordine    integer,
  testo     text not null,
  ipotesi   boolean default false,   -- testo arancione / "?" nel file
  attore_con_fonte boolean,          -- solo per riga = attore: pallino pieno (true) o vuoto (false)
  foreign key (journey, fase) references journey_fasi(journey, numero)
);
comment on table journey_elementi is 'Ogni riga delle user journey: azioni, touchpoint, attori, domande, criticità, opportunità.';

-- ---------------------------------------------------------------------
-- DOVE SI ROMPE IL VIAGGIO
-- ---------------------------------------------------------------------
create table mattina_segmenti (
  ordine   integer primary key,
  nome     text not null,
  orario   text,
  durata   text
);

create table punti_rottura (
  numero        integer primary key,
  titolo        text not null,
  margine       text,
  costo_se_salta text,
  dettaglio_se_salta text,
  qui_interveniamo boolean default false
);

create table chi_sa_cosa (
  ordine        integer primary key,
  momento       text not null,
  sa_viaggiatore text,
  sa_servizio   text
);
comment on table chi_sa_cosa is 'Che cosa sa il viaggiatore e che cosa sa già il servizio, momento per momento.';

-- ---------------------------------------------------------------------
-- TRE SCOPERTE E STATO DEL LAVORO
-- ---------------------------------------------------------------------
create table scoperte (
  numero          integer primary key,
  titolo          text not null,
  sottotitolo     text,
  cosa_succede    text,
  perche_conta    text,
  dove_si_interviene text,
  frase_chiave    text,
  note            text
);

create table stato_avanzamento (
  id     bigint generated always as identity primary key,
  stato  text not null check (stato in ('fatto','in_verifica','prossimo_passo')),
  voce   text not null,
  documento text
);

-- ---------------------------------------------------------------------
-- DOMANDE APERTE E CONTENUTI VARI
-- ---------------------------------------------------------------------
create table domande_aperte (
  id           bigint generated always as identity primary key,
  documento    text references documenti(codice),
  gruppo       text,          -- es. "Da chiedere a un capotreno", "Le domande da risolvere"
  domanda      text not null,
  stato        text default 'aperta'
);

create table contenuti (
  id         bigint generated always as identity primary key,
  documento  text references documenti(codice),
  sezione    text not null,     -- titolo della sezione nel file
  ordine     integer,
  tipo       text,              -- punto_critico, punto_interessante, vincolo, citazione, nota, legenda, scelta_metodologica, traccia...
  titolo     text,
  testo      text not null,
  riferimento text,             -- es. R1, R5
  ipotesi    boolean default false
);
comment on table contenuti is 'Tutti gli altri testi dei file, sezione per sezione: punti critici, punti interessanti, vincoli, citazioni, legende, note di metodo.';

-- ---------------------------------------------------------------------
-- SICUREZZA: RLS attiva ovunque, nessun accesso pubblico
-- ---------------------------------------------------------------------
alter table public.progetto_info enable row level security;
alter table public.team enable row level security;
alter table public.documenti enable row level security;
alter table public.fonti enable row level security;
alter table public.riferimenti_intervista enable row level security;
alter table public.cluster_attori enable row level security;
alter table public.attori enable row level security;
alter table public.tipi_flusso enable row level security;
alter table public.flussi enable row level security;
alter table public.catena_passaggi enable row level security;
alter table public.schema_nodi enable row level security;
alter table public.schema_archi enable row level security;
alter table public.chi_decide_cosa enable row level security;
alter table public.journey enable row level security;
alter table public.journey_bisogni enable row level security;
alter table public.journey_fasi enable row level security;
alter table public.journey_elementi enable row level security;
alter table public.mattina_segmenti enable row level security;
alter table public.punti_rottura enable row level security;
alter table public.chi_sa_cosa enable row level security;
alter table public.scoperte enable row level security;
alter table public.stato_avanzamento enable row level security;
alter table public.domande_aperte enable row level security;
alter table public.contenuti enable row level security;
