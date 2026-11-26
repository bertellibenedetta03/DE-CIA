-- DE CIA · Coincidenze — FILE UNICO da incollare nell'editor SQL di Supabase.
-- Contiene, in ordine: migrations/001_struttura.sql, 002_dati.sql, 003_storage.sql.
-- Si esegue UNA volta sola. Se qualcosa va storto non viene salvato niente (transazione).

begin;

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


-- =====================================================================
-- DE CIA · Coincidenze
-- 002 · Tutti i dati della ricerca e della memoria del progetto
-- File generato a partire dai PDF/PNG della cartella "DE CIA - COINCIDENZE"
-- e da MEMORIA_PROGETTO.md. Da eseguire dopo 001_struttura.sql.
-- =====================================================================

insert into progetto_info (chiave, valore, categoria, fonte) values
  ('nome', 'DE CIA', 'progetto', 'memoria del progetto'),
  ('tema', 'Coincidenze: l''esperienza del viaggiatore in un viaggio in treno con coincidenza, dall''acquisto del biglietto all''arrivo a destinazione.', 'progetto', 'Actors map v2'),
  ('contesto_didattico', 'Lab Sintesi I', 'progetto', 'sito index.html'),
  ('lingua', 'Italiano', 'preferenze', 'memoria del progetto'),
  ('tempo_disponibile', 'Da 1 a 2 giorni a settimana', 'team', 'memoria del progetto'),
  ('obiettivo_coordinamento', 'Supportare il team nel decision making e nelle scelte di implementazione, spendendo il meno possibile per ottenere un risultato ottimale.', 'progetto', 'memoria del progetto'),
  ('caso_studio', 'Bevilacqua → Monselice → Ferrara, mattina feriale di uno studente pendolare (due treni e un bus).', 'progetto', 'User Journey'),
  ('linea_studiata', 'Linea Bologna–Padova; stazione di cambio Monselice.', 'progetto', 'intervista al capostazione'),
  ('punto_di_intervento', 'Nei 37 minuti del primo treno, e nella scelta dei binari a Monselice: far arrivare al viaggiatore, mentre è ancora a bordo, l''informazione che il servizio possiede già.', 'progetto', 'Dove si rompe il viaggio'),
  ('prossimo_passo', 'Progettare come le richieste di coincidenza arrivano al capotreno.', 'progetto', 'Tre scoperte'),
  ('materiale_ricerca', 'Cartella "DE CIA - COINCIDENZE" con i PDF della ricerca sui viaggi in treno con coincidenza.', 'materiale', 'memoria del progetto'),
  ('repository', 'https://github.com/bertellibenedetta03/DE-CIA (MEMORIA_PROGETTO.md con PR 1, sito statico index.html + style.css con PR 2, sul branch main).', 'strumenti', 'memoria del progetto'),
  ('sito_web', 'Pagina statica in italiano (index.html + style.css, senza build) pubblicata su Vercel, piano gratuito. Progetto Vercel "decia" nel team "coincidenze-decia": pubblica in automatico il branch main e crea un''anteprima per ogni pull request.', 'strumenti', 'memoria del progetto'),
  ('database', 'Supabase, piano gratuito, progetto "DE-CIA" in una regione europea. Struttura e dati nella cartella supabase/ del repository; file originali nel bucket privato "ricerca" dello Storage.', 'strumenti', 'questa migrazione'),
  ('regola_merge', 'Stefano è d''accordo che Claude unisca le modifiche su main dopo il suo ok.', 'preferenze', 'memoria del progetto'),
  ('stile_di_lavoro', 'Stefano non è tecnico: servono istruzioni semplici, passo passo, in italiano. Spendere il meno possibile.', 'preferenze', 'memoria del progetto'),
  ('data_memoria', 'Memoria del progetto aggiornata il 26 novembre 2026.', 'progetto', 'MEMORIA_PROGETTO.md');

insert into team (nome, ruolo, disponibilita, note) values
  ('Stefano', 'Membro del gruppo; coordina il progetto; è lo studente pendolare della user journey (racconto del 24 novembre 2026)', '1–2 giorni a settimana', 'Non tecnico: preferisce istruzioni semplici passo passo.'),
  ('Benedetta', 'Membro del gruppo; titolare del repository GitHub', '1–2 giorni a settimana', null),
  ('Beatrice', 'Membro del gruppo', '1–2 giorni a settimana', null);

insert into documenti (codice, titolo, nome_file, tipo_file, dimensione_kb, cartella, descrizione, versione, data_riferimento, fonti_dichiarate, percorso_storage, testo_estratto, trascrizione, note_estrazione) values
  ('actors_map', 'Actors map v2 – Viaggio in treno con coincidenza', 'Actors map v2 – Viaggio in treno con coincidenza.pdf', 'pdf', 3007, 'DE CIA - COINCIDENZE', 'Mappa dei 40 attori in sei cluster e dei 46 flussi attorno all''esperienza del viaggiatore, aggiornata con l''intervista al capostazione. Pannello laterale: il punto di vista del capostazione, punti critici, punti interessanti, domande per il capotreno, cosa non entra nella mappa.', 'v2', 'novembre 2026', 'Lista del gruppo, riferimento Mercafir, intervista ad Andrea, capostazione di Ferrara (linea Bologna–Padova, novembre 2026).', 'ricerca/actors-map.pdf', 'Actors map

Il punto di vista del capostazione

Esperienza del viaggiatore in un viaggio in treno con
coincidenza, dall’acquisto del biglietto all’arrivo a

Intervista ad Andrea, capostazione di Ferrara. È una testimonianza situata, non la descrizione ufficiale del sistema: va letta come una fonte,
da confrontare con le altre.



destinazione

v2 – aggiornata con l’intervista a un capostazione (linea Bologna–
Padova, novembre 2026)

Come funziona davvero la coincidenza

1. Il viaggiatore chiede al capotreno di non perdere il treno successivo.

2. Il capotreno telefona al capostazione della stazione di cambio.

3. Se si tratta di pochi minuti, il capostazione decide da solo e trattiene il treno.

4. Se l’attesa è più lunga serve il benestare del Dirigente Centrale di Bologna.

5. Il Dirigente Centrale si interfaccia con il responsabile dell’impresa ferroviaria e comunica il da farsi.



Pendolare abituale

Normalmente si cerca di agevolare il viaggiatore.

Punti critici

Viaggiatore occasionale /
turista

Altri passeggeri in
stazione e a bordo

La coincidenza non è un diritto. Il vecchio Regolamento Circolazione Treni normava coincidenze e comporti; da anni non sono più normati.
Quello che resta è una prassi di cortesia.



VIAGGIATORI

Serve che qualcuno chieda. Se il viaggiatore non sa di poter chiedere, o non lo fa, la catena non parte nemmeno.


Il servizio dipende dalla relazione. Si va incontro al passeggero finché si vedono educazione e rispetto: la stessa situazione può avere esiti
diversi.



La decisione passa dal telefono. Cinque passaggi e nessuno strumento digitale condiviso, per decidere su pochi minuti.


Viaggiatore con esigenze
speciali (PMR, passeggini,
bagagli, bici)

Viaggiatore dell’ultimo
minuto

Trasporto locale (bus,
metro)

RFI e sala operativa dell’impresa non si parlano. Due organizzazioni che “viaggiano su binari paralleli”, con tentativi di integrazione falliti da
anni. È il punto più duro dell’intervista ed è anche quello su cui l’intervistato si ferma.



Capotreno treno in arrivo

Il rimborso che non c’è. Chi non conosce le regole va in biglietteria a chiedere un rimborso che non otterrà.


Esercizi commerciali

Bus sostitutivi

di stazione

Capotreno treno in
coincidenza

Polfer / sicurezza

Se la coincidenza salta non c’è un piano. I bus sostitutivi esistono solo per le soppressioni, e con cadenza oraria conviene comunque
aspettare il treno dopo.

Punti interessanti
CONTESTO E SERVIZI

PERSONALE DI
CONTATTO

ESTERNI

Taxi, sharing, parcheggi
di scambio

Circuiti di
pagamento

Due livelli di potere distinti. Il capostazione comanda dentro la sua stazione e sceglie i binari senza dover spiegare nulla; il Dirigente Centrale
comanda sulla linea e può ordinare di trattenere un treno.


Assistenza clienti e
informazioni in stazione

Personale di biglietteria

Una soglia implicita. “Pochi minuti” separa la decisione locale da quella centrale, ma non è un numero scritto da nessuna parte.


Le fasce pendolari pesano. Anche senza norma, in certe fasce orarie i treni pendolari hanno un’importanza maggiore.


Il linguaggio come barriera, riconosciuta dall’interno. Gli annunci usavano un gergo che il 95% dei viaggiatori non capiva; oggi è in parte
corretto.



Rivenditori terzi di
biglietti

Fattori esterni (meteo,
guasti, scioperi)

Sala Blu / assistenza
PMR

Pendolari e occasionali reagiscono in modo opposto: i primi “la prendono con filosofia”, i secondi vanno allo sportello.



Macchinisti

Una proposta dal campo. Tabelloni di binario con i prossimi 3 o 4 treni, come in Germania: lavora sull’ansia, non sul ritardo.

Da chiedere a un capotreno
La sua versione probabilmente conferma la catena, ma copre la parte che il capostazione non vede.


Come capisce che un passeggero ha una coincidenza a rischio: glielo chiedono o se ne accorge?

Quanti glielo chiedono in una corsa tipo, e chi sono?

Con quale strumento telefona e a chi, quando non conosce il capostazione della stazione di cambio?

Cosa dice al passeggero mentre aspetta la risposta?

Cosa succede quando la risposta è no?

Quanto spesso non chiede nemmeno, e perché?



ESPERIENZA DEL
VIAGGIATORE

viaggio in treno con
coincidenza

Domande rimaste aperte anche con il capostazione: quali strumenti software usa davvero (nell’intervista compare solo il telefono); qual è il
ritardo oltre il quale la coincidenza è persa; cosa succede sull’ultima corsa della giornata.
Capostazione della
stazione di cambio

Impresa ferroviaria

Gestore dell’infrastruttura
(RFI)

Sindacati

Associazioni
consumatori e
comitati pendolari

App di viaggio e canali
digitali

Comuni

Stazione di cambio
(sottopassi, ascensori,
binari)

Manutenzione e
logistica di stazione

Tabelloni e annunci in
stazione

CANALI E STRUMENTI
Biglietto / titolo di
viaggio

LEGENDA
Attore presente nella lista di partenza
Da verificare: ipotesi, o attore che l’intervista non conferma
Attore confermato o emerso dall’intervista

La dimensione del cerchio è un’ipotesi di peso nell’esperienza, da rivedere.

Telefono di servizio

FLUSSI
Flusso economico
Biglietterie self-service

Flusso di servizio
Flusso di persone
Flusso di informazioni

Le frecce numerate da 1 a 5 ricostruiscono la catena della coincidenza descritta
nell’intervista.

Responsabile
dell’impresa ferroviaria

Manutenzione treni
e depositi

Palmare / tablet del
capotreno

Sala operativa
dell’impresa ferroviaria

Una actors map rappresenta soggetti e relazioni, non regole. Questi elementi restano qui a lato:


L’assenza di norma su coincidenze e comporti.

L’orario come primo vincolo di ogni decisione.

La soglia dei “pochi minuti”.

La priorità delle fasce pendolari.

La gerarchia tra stazione e linea.


Il palmare del capotreno resta in mappa come ipotesi da verificare: nell’intervista non viene mai nominato, al suo posto compare il telefono.

GESTIONE OPERATIVA
Regione / Ministero
(ente committente)

Autorità di
regolazione dei
trasporti

Dirigente Centrale di linea
(DCO)

Pulizie

ORGANIZZAZIONI E
ISTITUZIONI

Cosa non entra nella mappa', null, 'Testo estratto automaticamente dal PDF; l''aspetto dei cerchi (colore, bianco, bordo spesso) è registrato nella tabella attori.'),
  ('dove_si_rompe', 'Dove si rompe il viaggio', 'Dove si rompe il viaggio.pdf', 'pdf', 1572, 'DE CIA - COINCIDENZE', 'La mattina di uno studente pendolare minuto per minuto, i tre punti di rottura, chi sa che cosa e quando, dove intervenire e la traccia da dire al professore.', null, '24 novembre 2026', 'Orari e comportamenti: racconto diretto del viaggiatore, 24 novembre 2026. Funzionamento del servizio: intervista a un capostazione, linea Bologna–Padova.', 'ricerca/dove-si-rompe.pdf', 'Dove si rompe il viaggio
La mattina di uno studente pendolare, minuto per minuto. Il viaggio si rompe in tre punti: due costano un’ora ciascuno, e ogni rottura dipende da un’informazione che il servizio possiede già e che al viaggiatore non arriva.
I numeri segnano l’ordine in cui raccontare lo schema. La traccia è in fondo.

1

LA MATTINA REALE

Sveglia e partenza

Auto e stazione

5.50 – 6.30

Il cambio

7.21 – 7.30

Primo treno

6.30 – 6.44

6.44 – 7.21 · 37 min

Secondo treno

Bus urbano

7.30 – 8.16 · 46 min

8.21 – 8.35

Attesa del bus

8.16 – 8.21

2

I TRE PUNTI DI ROTTURA

UI CHE INTERVENIAMO

È Q

Perdi la coincidenza a Monselice

MARGINE

MARGINE

Nessun margine. Il treno passa e basta.

9

SE SALTA

SE SALTA

SE SALTA

utta la giornata slitta di un’ora.

Il treno per Bologna passa ogni ora, alle 27 o alle 30: il successivo è alle 8.27.

Il bus successivo passa verso le 8.36.

+ 1 ora

Perdi il bus delle 8.21
MARGINE

minuti, meno il tempo per andare dal binario 6 al binario 1.

5 minuti. Bastano 2 o 3 minuti di ritardo del secondo treno.

+ 1 ora

T

4

3

Perdi il treno delle 6.44

+ 15 minuti

I SA CHE COSA, E QUANDO

CH

e cosa sa

il viaggiatore

6.30 · al parcheggio

6.44 – 7.21 · a bordo

7.21 · a Monselice

8.16 · a Ferrara

rario stimato ed effettivo sull’app.

Il ritardo di adesso, scritto sullo schermo.

Il binario, e se il treno è ancora fermo lì.

S

Ch

O

e cosa sa già

il servizio

La posizione reale del treno e la previsione di arrivo a Monselice.

Ch

S

e quel ritardo verrà recuperato prima di Monselice.

D

a quale binario arriva e da quale riparte, e se conviene trattenerlo.

La riga azzurra è informazione che esiste già dentro il servizio. Le frecce rosse sono il salto che il viaggiatore deve fare da solo, ogni mattina.

DOVE VOGLIO INTERVENIRE

5

Nei 37 minuti del primo treno, e nella scelta dei binari a Monselice
assegnazione del binario

37 minuti in cui la decisione è ancora possibile

In questa finestra il servizio sa già tutto quello che serve: il ritardo previsto all’arrivo, chi deve fare un cambio, da che binario far arrivare il treno. Il viaggiatore no. Il progetto lavora qui: non per far arrivare i treni in orario, ma per far arrivare al viaggiatore, mentre è ancora a bordo, l’informazione che il servizio possiede già.

E COSA DIRE AL PROFESSORE

CH

inque passaggi, nell’ordine dei numeri sullo schema

C

S

artiamo da un viaggio vero, non da un caso di studio: due treni e un bus, due ore e tre quarti, tutte le mattine.

1

P

2

Il viaggio si rompe in tre punti, e due costano un’ora ciascuno, perché i regionali sono cadenzati ogni ora.

3

Il punto su cui lavoriamo è il secondo: nove minuti a Monselice, che però si consumano andando dal binario 6 al binario 1.

4

La causa non è il ritardo in sé: è che l’informazione per decidere esiste già nel servizio e non arriva al viaggiatore.

5

Q

uindi interveniamo nei 37 minuti a bordo, dove la decisione è ancora possibile: è lì che va raccolta la richiesta di chi deve fare la coincidenza.

e chiede che cosa manca: la versione del capotreno e il tempo reale di attraversamento a Monselice.

Orari e comportamenti: racconto diretto del viaggiatore, 24 novembre 2026. Funzionamento del servizio: intervista a un capostazione, linea Bologna–Padova.

e il bus è già passato.

L’orario reale di arrivo rispetto al bus delle 8.21.', null, 'Il testo estratto automaticamente ha alcune lettere iniziali staccate (capilettera grafici): il contenuto pulito è nelle tabelle mattina_segmenti, punti_rottura, chi_sa_cosa e contenuti.'),
  ('catena_decisionale', 'La catena decisionale', 'La catena decisionale.pdf', 'pdf', 1344, 'DE CIA - COINCIDENZE', 'Chi decide se un treno aspetta chi sta arrivando in ritardo: i cinque passaggi, le due leve del capostazione, che cosa pesa sulla decisione, i quattro punti critici.', null, 'novembre 2026', 'Intervista ad Andrea, capostazione sulla linea Bologna–Padova. Tutto lo schema viene da una sola intervista, dal lato del gestore dell''infrastruttura.', 'ricerca/catena-decisionale.pdf', 'La catena decisionale
Chi decide se un treno aspetta chi sta arrivando in ritardo. Ricostruita dall’intervista ad Andrea, capostazione sulla linea Bologna–Padova. Le coincidenze non sono più normate dal Regolamento Circolazione Treni: quello che resta è questa prassi.

I pallini rossi segnano i punti critici, elencati in basso a destra.

Decide il capostazione
COME SALE LA RICHIESTA

se si parl
di poc

1
1

2

Viaggiatore

2

Chiede di non perdere la coincidenza.

Capotreno

Pochi minuti: viene incontro al viaggiatore senza chiedere a nessuno.

i minuti

3
3

Del treno in arrivo, a bordo.

h

a


Capostazione

ESITO

Della stazione di coincidenza.


Il treno aspetta,


Valuta la fattibilità.

oppure non aspetta

a voce, a bordo

telefonata

oppure è il capotreno

a chiedere chi deve cambiare

Dirigente Centrale

4

e


se serve trattener
pi

ù

Del treno da trattenere


Gestisce la circolazione in linea.

(Trenitalia).

?N ’

h

C

—
— ò

—
—N
—
—

Dentro la propria stazione pu
Pu

ò

ricevere un treno su un binario senza dare spiegazioni al Dirigente Centrale.


trattenere un treno di pochi minuti di sua iniziativa

.



Sono le due leve che decidono una coincidenza e stanno nelle stesse mani.

O

O

q

4

’è.

uesto passaggio non c

I

gni treno ha un’ora di arrivo e una di partenza: è il primo vincolo.


QU

ATTRO

1

N

elle fasce pendolari i treni hanno un’importanza maggiore.


La relazione. Si va incontro al viaggiatore

“

fintantoch

é

4

.”

Andrea, capostazione

—

linea Bologna–Padova, novembre

2026

Tutto lo schema viene da una sola intervista, dal lato del gestore dell’infrastruttura. La stessa catena vista dal capotreno e dal viaggiatore non è ancora stata verificata.

La catena parte solo se qualcuno parla.

N

essuna richiesta, nessuna catena.

”

3

ormalmente si cerca di agevolare il viaggiatore

TI CRITICI

vediamo educazione e rispetto .

2

“N

PUN

essuna norma. Il Regolamento Circolazione Treni normava coincidenze e comporti, da anni non più.


Le fasce.

ggi vengono usate separatamente: il binario si assegna senza sapere chi deve cambiare.

ell intervista

ordinare di trattenere un treno fino al suo nulla osta: per il capostazione c’è obbligo di ottemperare.

e cosa pesa sulla decisione

L’orario.

comunica il da farsi

a lungo

ò

Le due leve del capostazione

Responsabile impresa

Sede di Bologna.


Il Dirigente Centrale pu

E la risposta torna al viaggiatore

5

“

h

Cerc

hé

iamo di andare loro incontro fintantoc

.”

vediamo educazione e rispetto

Tutto passa dal telefono, fra due persone che devono trovarsi in quel momento.

Le due leve del capostazione stanno nelle stesse mani ma vengono usate separatamente.

La risposta non torna indietro: nessun passaggio riporta l’esito a chi ha chiesto.', null, 'Il testo estratto automaticamente è in ordine sparso: il contenuto pulito è nelle tabelle catena_passaggi e contenuti.'),
  ('schema_intervista_pdf', 'Schema tratto dall''intervista (PDF)', 'Schema tratto dall''intervista.pdf', 'pdf', 486, 'DE CIA - COINCIDENZE', 'Schema decisionale: la coincidenza vista dal capostazione. Diagramma a corsie ricostruito dalle risposte dell''intervista (R1–R13). Stesso contenuto del PNG.', null, 'novembre 2026', 'Risposte dell''intervista al capostazione R1–R13; PDF del gruppo; Tre scoperte.', 'ricerca/schema-intervista-pdf.pdf', '', 'SCHEMA DECISIONALE: LA COINCIDENZA VISTA DAL CAPOSTAZIONE
Ricostruito dalle risposte dell''intervista (R1–R13, numerate come le domande). Ogni passaggio riporta la risposta da cui viene. In arancione ciò che l''intervista non dice.

VINCOLO · R5 — L''orario è il primo vincolo: per i treni viaggiatori il rispetto dell''orario è fondamentale.
VINCOLO · R1 · R6 — Nessuna norma: coincidenze e comporti non sono più normati (ex RCT). Esistono solo fasce pendolari con più importanza.
VINCOLO · R12 — La relazione conta: si va incontro al viaggiatore finché ci sono educazione e rispetto.
VINCOLO · R1 — Si cerca normalmente di agevolare il viaggiatore.

COME LEGGERE LO SCHEMA
Rettangolo = azione · Rombo = decisione · Pillola = evento · Cerchio numerato = passo della catena (1 viaggiatore, 2 capotreno, 3 capostazione, 4 Dirigente Centrale, 5 impresa) · Bordo arancione tratteggiato = non documentato o da chiarire · Bordo rosso = criticità · Etichetta R# = risposta dell''intervista

CORSIA: VIAGGIATORE
- [evento] Ha una coincidenza a rischio (es. dall''arrivo di Ravenna all''ultimo treno per Padova) — R1
- [1] Chiede al capotreno di non perdere il treno — PDF del gruppo · catena 1 → va a "Riceve la richiesta" (capotreno)
- [non documentato] Se non chiede, o non sa di poterlo fare, la catena non parte — non nell''intervista · PDF del gruppo
- [non documentato] Esito al viaggiatore: nessun passaggio lo riporta — assente nell''intervista (freccia tratteggiata dall''ESITO, etichetta "non documentato")
CHI DECIDE COSA — DECIDE: Se chiedere. Non decide se il treno aspetta. SE NON CHIEDE: La catena non parte: nessuno la avvia al posto suo (PDF del gruppo, catena 1). DOPO: Pendolare: la prende con filosofia. Non informato: va in biglietteria e chiede un rimborso inutilmente (R8).

CORSIA: CAPOTRENO (TRENO IN ARRIVO)
- Riceve la richiesta (o la chiede lui a bordo) — R1 · Tre scoperte → 
- [2] Telefona al capostazione della stazione di cambio — R1 → va a "Riceve la telefonata" (capostazione)
CHI DECIDE COSA — DECIDE: Se segnalare al capostazione un passeggero con la coincidenza a rischio (R1). NON DECIDE: La trattenuta del treno in coincidenza: la decide il capostazione o, oltre i pochi minuti, il Dirigente Centrale (R1). STRUMENTO: Telefono (R1). Nessun altro strumento nominato.

CORSIA: CAPOSTAZIONE (STAZIONE DI CAMBIO)
- Assegna il binario al treno in arrivo, senza spiegazioni al Dirigente Centrale — R5 · leva autonoma
- Ottempera all''ordine: trattiene il treno fino al nulla osta — R5 · obbligo (riceve la freccia "ordine di trattenere" dal Dirigente Centrale)
- [3] Riceve la telefonata e valuta la fattibilità — R1 →
- [decisione] Quanti minuti per trattenere il treno? — R1 · R7
   · "pochi minuti" → [3] Decide da solo: trattiene il treno — R1 · pochi minuti → ESITO
   · "più a lungo: comunica l''esigenza e spiega il problema" → [4] Benestare del Dirigente Centrale?
- Riceve il da farsi dal Dirigente Centrale — R1 → Esegue: trattiene o non trattiene il treno — R1 · R5 → ESITO
- [esito] ESITO: il treno aspetta oppure no — R1 · normalmente si agevola
CHI DECIDE COSA — DECIDE DA SOLO: Trattenere un treno per pochi minuti (R1). Ricevere un treno su un binario senza spiegazioni al Dirigente Centrale (R5). NON DECIDE: Trattenute più lunghe: serve il benestare del Dirigente Centrale (R1). Deve ottemperare se il Dirigente Centrale ordina di trattenere (R5). SOGLIA: ''Pochi minuti'' non è un numero: nessuna norma (R1, R6, R7) e conta anche la relazione (R12). STRUMENTO: Telefono (R1).

CORSIA: DIRIGENTE CENTRALE (SEDE DI BOLOGNA)
- Gestisce i treni in linea e può ordinare di trattenere un treno fino al suo nulla osta — R5 → "ordine di trattenere" → Ottempera all''ordine (capostazione)
- [4, decisione] Benestare del Dirigente Centrale? — R1 → "sì / no" →
- Si interfaccia con il Responsabile dell''impresa (Trenitalia) del treno da trattenere — R1 → Responsabile impresa
- [5] Comunica il da farsi al capostazione — R1 → Riceve il da farsi (capostazione)
CHI DECIDE COSA — DECIDE: La circolazione dei treni in linea Bologna–Padova (R5). Dà o nega il benestare alle trattenute lunghe (R1). Può ordinare di trattenere un treno fino al suo nulla osta (R5). SI CONSULTA CON: Il Responsabile dell''impresa ferroviaria (Trenitalia) del treno da trattenere, poi comunica il da farsi al capostazione (R1). NON SI COORDINA: RFI e Sala Operativa TPER viaggiano su binari paralleli, con tentativi falliti da anni (R11).

CORSIA: RESPONSABILE IMPRESA FERROVIARIA (TRENITALIA)
- [non documentato] RFI e Sala Operativa TPER viaggiano su binari paralleli: integrazione tentata da anni, pessimi risultati — R11
- [5, da chiarire] Indica come muoversi sul treno da trattenere: non è chiaro se decide o dà un parere — R1 · da chiarire → Comunica il da farsi (Dirigente Centrale)
CHI DECIDE COSA — RUOLO: Il Dirigente Centrale si interfaccia con lui sul treno da trattenere e poi comunica il da farsi (R1). DA CHIARIRE: Se decide o dà solo un parere: nell''intervista non è chiaro. NOTA: L''intervista nomina Trenitalia per il treno da trattenere e la Sala Operativa TPER per il coordinamento: verificare quale impresa serve la linea.

QUANDO LA COINCIDENZA SALTA
Percorsi dopo la coincidenza persa: soppressione del treno, attesa del successivo, reazione del viaggiatore (R8, R10).
- [evento] Coincidenza persa — R8 · R10 → [decisione] Treno soppresso? — R10
   · sì → Autobus sostitutivi: tempi di attesa altissimi — R10
   · no → Cadenza oraria: conviene attendere 1 ora e salire sul treno successivo — R10
- entrambi → [decisione] Chi è il viaggiatore? — R8
   · pendolare → Pendolare abituale: la prende con filosofia — R8
   · non al corrente → [criticità] Non è al corrente del regolamento: va in biglietteria a chiedere il rimborso, inutilmente — R8

INFORMAZIONE E PROPOSTA DAL CAMPO
Annunci (R9): un tempo in gergo ferroviario, anche sui treni: il 95% dei viaggiatori non capiva. Da qualche anno si usa un italiano più corretto.
Ansia scaricata sul personale (R12): accade spesso; si va incontro ai viaggiatori finché ci sono educazione e rispetto.
Proposta (R13): tabelloni di binario con i prossimi 3 o 4 treni in arrivo, come in Germania, per tranquillizzare i viaggiatori.
Comunicazione con la sala operativa (R11): migliorarla è un tentativo di anni con pessimi risultati.

CHE COSA L''INTERVISTA NON DICE
Strumenti (D3): nelle risposte compare solo il telefono, nessun software.
Fattori del ''No'' (D5): non cita binario unico, precedenze o fine turno; indica orario, Dirigente Centrale e ''mille situazioni singolari''.
Ultima corsa (D6): non confronta ultima corsa e punta; dice solo che le fasce pendolari pesano di più.
Ritardo massimo (D7): rimanda alla R1: nessun numero, solo ''pochi minuti'' contro ''tempo maggiore''.
Riprotezione (D10): solo bus per le soppressioni e attesa del treno dopo; nessun taxi o voucher.
Ritorno al viaggiatore: nessun passaggio riporta l''esito a chi ha chiesto.', 'Il PDF contiene solo un''immagine, senza testo: la trascrizione integrale è stata fatta leggendo l''immagine. Il contenuto strutturato è in schema_nodi, schema_archi, chi_decide_cosa, riferimenti_intervista.'),
  ('schema_intervista_png', 'Schema tratto dall''intervista (PNG)', 'Schema tratto dall''intervista.png', 'png', 2649, 'DE CIA - COINCIDENZE', 'Versione immagine (7051 × 4295 px) dello schema decisionale: la coincidenza vista dal capostazione. Identica al PDF.', null, 'novembre 2026', 'Risposte dell''intervista al capostazione R1–R13.', 'ricerca/schema-intervista-png.png', '', 'SCHEMA DECISIONALE: LA COINCIDENZA VISTA DAL CAPOSTAZIONE
Ricostruito dalle risposte dell''intervista (R1–R13, numerate come le domande). Ogni passaggio riporta la risposta da cui viene. In arancione ciò che l''intervista non dice.

VINCOLO · R5 — L''orario è il primo vincolo: per i treni viaggiatori il rispetto dell''orario è fondamentale.
VINCOLO · R1 · R6 — Nessuna norma: coincidenze e comporti non sono più normati (ex RCT). Esistono solo fasce pendolari con più importanza.
VINCOLO · R12 — La relazione conta: si va incontro al viaggiatore finché ci sono educazione e rispetto.
VINCOLO · R1 — Si cerca normalmente di agevolare il viaggiatore.

COME LEGGERE LO SCHEMA
Rettangolo = azione · Rombo = decisione · Pillola = evento · Cerchio numerato = passo della catena (1 viaggiatore, 2 capotreno, 3 capostazione, 4 Dirigente Centrale, 5 impresa) · Bordo arancione tratteggiato = non documentato o da chiarire · Bordo rosso = criticità · Etichetta R# = risposta dell''intervista

CORSIA: VIAGGIATORE
- [evento] Ha una coincidenza a rischio (es. dall''arrivo di Ravenna all''ultimo treno per Padova) — R1
- [1] Chiede al capotreno di non perdere il treno — PDF del gruppo · catena 1 → va a "Riceve la richiesta" (capotreno)
- [non documentato] Se non chiede, o non sa di poterlo fare, la catena non parte — non nell''intervista · PDF del gruppo
- [non documentato] Esito al viaggiatore: nessun passaggio lo riporta — assente nell''intervista (freccia tratteggiata dall''ESITO, etichetta "non documentato")
CHI DECIDE COSA — DECIDE: Se chiedere. Non decide se il treno aspetta. SE NON CHIEDE: La catena non parte: nessuno la avvia al posto suo (PDF del gruppo, catena 1). DOPO: Pendolare: la prende con filosofia. Non informato: va in biglietteria e chiede un rimborso inutilmente (R8).

CORSIA: CAPOTRENO (TRENO IN ARRIVO)
- Riceve la richiesta (o la chiede lui a bordo) — R1 · Tre scoperte → 
- [2] Telefona al capostazione della stazione di cambio — R1 → va a "Riceve la telefonata" (capostazione)
CHI DECIDE COSA — DECIDE: Se segnalare al capostazione un passeggero con la coincidenza a rischio (R1). NON DECIDE: La trattenuta del treno in coincidenza: la decide il capostazione o, oltre i pochi minuti, il Dirigente Centrale (R1). STRUMENTO: Telefono (R1). Nessun altro strumento nominato.

CORSIA: CAPOSTAZIONE (STAZIONE DI CAMBIO)
- Assegna il binario al treno in arrivo, senza spiegazioni al Dirigente Centrale — R5 · leva autonoma
- Ottempera all''ordine: trattiene il treno fino al nulla osta — R5 · obbligo (riceve la freccia "ordine di trattenere" dal Dirigente Centrale)
- [3] Riceve la telefonata e valuta la fattibilità — R1 →
- [decisione] Quanti minuti per trattenere il treno? — R1 · R7
   · "pochi minuti" → [3] Decide da solo: trattiene il treno — R1 · pochi minuti → ESITO
   · "più a lungo: comunica l''esigenza e spiega il problema" → [4] Benestare del Dirigente Centrale?
- Riceve il da farsi dal Dirigente Centrale — R1 → Esegue: trattiene o non trattiene il treno — R1 · R5 → ESITO
- [esito] ESITO: il treno aspetta oppure no — R1 · normalmente si agevola
CHI DECIDE COSA — DECIDE DA SOLO: Trattenere un treno per pochi minuti (R1). Ricevere un treno su un binario senza spiegazioni al Dirigente Centrale (R5). NON DECIDE: Trattenute più lunghe: serve il benestare del Dirigente Centrale (R1). Deve ottemperare se il Dirigente Centrale ordina di trattenere (R5). SOGLIA: ''Pochi minuti'' non è un numero: nessuna norma (R1, R6, R7) e conta anche la relazione (R12). STRUMENTO: Telefono (R1).

CORSIA: DIRIGENTE CENTRALE (SEDE DI BOLOGNA)
- Gestisce i treni in linea e può ordinare di trattenere un treno fino al suo nulla osta — R5 → "ordine di trattenere" → Ottempera all''ordine (capostazione)
- [4, decisione] Benestare del Dirigente Centrale? — R1 → "sì / no" →
- Si interfaccia con il Responsabile dell''impresa (Trenitalia) del treno da trattenere — R1 → Responsabile impresa
- [5] Comunica il da farsi al capostazione — R1 → Riceve il da farsi (capostazione)
CHI DECIDE COSA — DECIDE: La circolazione dei treni in linea Bologna–Padova (R5). Dà o nega il benestare alle trattenute lunghe (R1). Può ordinare di trattenere un treno fino al suo nulla osta (R5). SI CONSULTA CON: Il Responsabile dell''impresa ferroviaria (Trenitalia) del treno da trattenere, poi comunica il da farsi al capostazione (R1). NON SI COORDINA: RFI e Sala Operativa TPER viaggiano su binari paralleli, con tentativi falliti da anni (R11).

CORSIA: RESPONSABILE IMPRESA FERROVIARIA (TRENITALIA)
- [non documentato] RFI e Sala Operativa TPER viaggiano su binari paralleli: integrazione tentata da anni, pessimi risultati — R11
- [5, da chiarire] Indica come muoversi sul treno da trattenere: non è chiaro se decide o dà un parere — R1 · da chiarire → Comunica il da farsi (Dirigente Centrale)
CHI DECIDE COSA — RUOLO: Il Dirigente Centrale si interfaccia con lui sul treno da trattenere e poi comunica il da farsi (R1). DA CHIARIRE: Se decide o dà solo un parere: nell''intervista non è chiaro. NOTA: L''intervista nomina Trenitalia per il treno da trattenere e la Sala Operativa TPER per il coordinamento: verificare quale impresa serve la linea.

QUANDO LA COINCIDENZA SALTA
Percorsi dopo la coincidenza persa: soppressione del treno, attesa del successivo, reazione del viaggiatore (R8, R10).
- [evento] Coincidenza persa — R8 · R10 → [decisione] Treno soppresso? — R10
   · sì → Autobus sostitutivi: tempi di attesa altissimi — R10
   · no → Cadenza oraria: conviene attendere 1 ora e salire sul treno successivo — R10
- entrambi → [decisione] Chi è il viaggiatore? — R8
   · pendolare → Pendolare abituale: la prende con filosofia — R8
   · non al corrente → [criticità] Non è al corrente del regolamento: va in biglietteria a chiedere il rimborso, inutilmente — R8

INFORMAZIONE E PROPOSTA DAL CAMPO
Annunci (R9): un tempo in gergo ferroviario, anche sui treni: il 95% dei viaggiatori non capiva. Da qualche anno si usa un italiano più corretto.
Ansia scaricata sul personale (R12): accade spesso; si va incontro ai viaggiatori finché ci sono educazione e rispetto.
Proposta (R13): tabelloni di binario con i prossimi 3 o 4 treni in arrivo, come in Germania, per tranquillizzare i viaggiatori.
Comunicazione con la sala operativa (R11): migliorarla è un tentativo di anni con pessimi risultati.

CHE COSA L''INTERVISTA NON DICE
Strumenti (D3): nelle risposte compare solo il telefono, nessun software.
Fattori del ''No'' (D5): non cita binario unico, precedenze o fine turno; indica orario, Dirigente Centrale e ''mille situazioni singolari''.
Ultima corsa (D6): non confronta ultima corsa e punta; dice solo che le fasce pendolari pesano di più.
Ritardo massimo (D7): rimanda alla R1: nessun numero, solo ''pochi minuti'' contro ''tempo maggiore''.
Riprotezione (D10): solo bus per le soppressioni e attesa del treno dopo; nessun taxi o voucher.
Ritorno al viaggiatore: nessun passaggio riporta l''esito a chi ha chiesto.', 'Immagine: trascrizione fatta leggendo l''immagine, identica a quella del PDF.'),
  ('spiegazione', 'Spiegazione di Claude', 'Spiegazione di Claude.pdf', 'pdf', 4463, 'DE CIA - COINCIDENZE', 'Spiegazione della actors map: le tre fonti e come si leggono dal bordo, i dieci cerchi bianchi uno per uno, i flussi (cosa viene dall''intervista e cosa è inferenza), le scelte senza fonte, che cosa la mappa non dice.', 'Versione 2', 'novembre 2026', 'Mappa e spiegazione costruite con Claude a partire dalla lista del gruppo, dal riferimento Mercafir e dall''intervista al capostazione.', 'ricerca/spiegazione.pdf', 'Spiegazione della actors map

Come è stata costruita, che cosa è documentato e che cosa è ipotesi. Scritto per il gruppo: serve a decidere cosa tenere, cosa verificare e cosa togliere.

1. Le tre fonti, e come si leggono dal bordo
Cerchio colorato, bordo sottile

Viene dalla lista grezza del gruppo. Ho solo fuso i doppioni fra le due liste e
riorganizzato tutto in sei cluster.

Cerchio bianco

Ipotesi. Nessuna fonte la conferma: l’ho aggiunta io per coprire i buchi del perimetro,
oppure è un attore della lista che l’intervista non conferma.

Bordo spesso

Confermato o emerso dall’intervista al capostazione sulla linea Bologna–Padova. È
l’unica parte della mappa con una fonte diretta.

Perché il bianco vuol dire “da verificare”

Il bianco raccoglie due casi diversi: le ipotesi che ho aggiunto io per coprire i buchi del perimetro, e gli attori che erano nella vostra lista ma che l’intervista non conferma — per ora solo il palmare del capotreno, mai nominato dal capostazione. In entrambi i casi la regola è la stessa: se
non c’è una fonte, resta da verificare.

2. I dieci cerchi bianchi, uno per uno

Per ciascuno: perché sta nella mappa e che cosa servirebbe per confermarlo o eliminarlo. Sono il primo punto su cui decidere, perché nessuno di questi ha una fonte.
VIAGGIATORI

CANALI E STRUMENTI

’esperienza del cambio dipende anche da chi occupa lo stesso spazio: folla nel sottopasso, coda alle scale mobili, posti già occupati
sul secondo treno. Nelle liste comparivano i profili dell’utente, mai gli altri come contesto.

Il perimetro parte dall’acquisto, ma la lista aveva solo sportello e app. La macchinetta è un canale con regole proprie: coda, contanti,
interfaccia, e nessuno a cui chiedere.

1. Altri passeggeri in stazione e a bordo
L

Come verificarlo
O

sservazione diretta in stazione nell’ora di punta. Se il trasbordo non è mai ostacolato dagli altri, si elimina.

2. Biglietterie self-service
Come verificarlo

Chiedere all’impresa che quota di biglietti regionali passa da lì, oppure contarlo sul campo in mezz’ora di osservazione.

CANALI E STRUMENTI
3. Stazione di cambio come luogo

CANALI E STRUMENTI

Come verificarlo

Come verificarlo

Sottopassi, ascensori, segnaletica e distanza fra i binari decidono quanti minuti servono davvero per il cambio. Nella lista c’erano gli
addetti alla manutenzione, non lo spazio in sé.
isurare il tempo di trasbordo reale fra i due binari più distanti: è anche il dato che serve alla journey. Se il gruppo decide che la
mappa contiene solo soggetti, questo esce.
M

4. Palmare / tablet del capotreno

Caso diverso dagli altri: era nella lista del gruppo. L’ho reso bianco perché il capostazione descrive tutta la catena al telefono e non lo
nomina mai. Non è escluso che esista, è escluso che sia il canale della coincidenza.
È già una delle domande preparate per il capotreno. La sua risposta decide se torna colorato o sparisce.
ORGANIZZAZIONI

6. Associazioni consumatori e comitati pendolari

ORGANIZZAZIONI
5. Autorità di regolazione dei trasporti

Nella lista compariva come categoria generica, “autorità di regolazione e istituzioni”. L’ho resa un attore esplicito perché i diritti del
passeggero in caso di coincidenza persa sono materia sua.
Come verificarlo

Verificare se ART abbia davvero competenza su questo o se la materia sia soltanto europea e contrattuale. È una verifica
documentale, non un’intervista.

Dopo il disservizio la lista si fermava. Qualcuno però raccoglie i reclami e li porta al committente: senza questo attore il reclamo del

viaggiatore finisce nel vuoto.
Come verificarlo

Cercare se esistono comitati attivi sulla linea studiata. Se esistono sono anche una fonte di ricerca, non solo un attore da disegnare.
CONTESTO E SERVIZI ESTERNI

8. Rivenditori terzi di biglietti

ORGANIZZAZIONI
7. Sindacati

Nella lista lo sciopero era classificato come “fattore esterno”, insieme al meteo. Ma dietro uno sciopero c’è un soggetto che decide,
mentre dietro la pioggia no.
Come verificarlo

Se il biglietto è comprato fuori dai canali dell’impresa, quando qualcosa va storto il viaggiatore non sa più a chi rivolgersi. Tocca
direttamente la coincidenza.
Come verificarlo

Chiedere all’impresa, o leggere le condizioni di vendita, che cosa cambia nella tutela quando il biglietto arriva da un rivenditore.

Nessuna verifica sul campo: è una correzione logica. Semmai si discute se lo sciopero rientri nel perimetro del progetto.
CONTESTO E SERVIZI ESTERNI
10. Esercizi commerciali di stazione

CONTESTO E SERVIZI ESTERNI

Quando la coincidenza salta, l’attesa si passa da qualche parte. Il bar è spesso l’unico servizio che il viaggiatore incontra in quel

9. Circuiti di pagamento

Completano la catena economica dell’acquisto: senza di loro il flusso del denaro si interrompe a metà.
Come verificarlo

Candidato alla rimozione. Esistono nel sistema ma non toccano l’esperienza della coincidenza: li ho tenuti per coerenza del flusso
economico, non perché contino.

momento.

Come verificarlo

Il più debole dei dieci. Tenerlo solo se la journey mostra che l’attesa è una fase con un peso suo.

In sintesi: i tre più solidi sono gli altri passeggeri, la stazione come luogo e i comitati pendolari. I due più deboli sono i circuiti di pagamento e gli esercizi commerciali: se la mappa va alleggerita, si parte da lì.

. I flussi che cosa ho valutato e che cosa no

3
:
Il modello è quello di Mercafir, che usa quattro flussi: economico, merce, persone, informazioni. Qui la merce non esiste, quindi l’ho sostituita con un flusso di servizio, cioè chi eroga qualcosa a chi. Ogni freccia ha un verso e un nome completo nel
pannello livelli di Figma: selezionandola si legge che cosa rappresenta.

Che cosa viene dall’intervista

Che cosa è inferenza mia

Sono le uniche frecce con una fonte diretta.
— la catena della coincidenza, frecce numerate da 1 a 5

— il coordinamento fra RFI e sala operativa che non funziona

— il rimborso chiesto in biglietteria e non accolto

— i bus sostitutivi solo in caso di soppressione

— gli annunci in gergo ferroviario

— il biglietto che non garantisce la coincidenza

icavate dalle descrizioni della vostra lista e da conoscenza generica del sistema ferroviario. Plausibili, non verificate.
— tutti e undici i flussi economici: pedaggio, corrispettivi, incassi dei rivenditori, accrediti

— i flussi di servizio di manutenzione e pulizie

— i tre flussi di persone

— i flussi istituzionali: ART, Regione, associazioni, sindacati, Comuni
R

Che cosa ho deciso di non disegnare, e perché

Nessuna freccia tocca il centro. Il centro è l’esperienza del viaggiatore, non un attore: collegarci tutto avrebbe prodotto un sole, nascondendo le relazioni laterali, che sono il punto della mappa.


I viaggiatori sono collegati come cluster, non profilo per profilo. Unica eccezione la Sala Blu, che punta al viaggiatore con esigenze speciali. Senza questa scelta ogni freccia si moltiplicava per cinque.


Niente flussi interni ovvi. Per esempio fra macchinista e capotreno dello stesso treno.


utte le frecce hanno lo stesso spessore, anche se non pesano uguale: non c’è nessun criterio di frequenza o di importanza.



T

Nessuna freccia rappresenta il tempo. Per la sequenza serve la user journey, non questa mappa.
Due frecce sono anomale, e il gruppo deve decidere

I sala operativa e viaggiatore → biglietteria per il rimborso dicono “qui non funziona”, mentre tutte le altre dicono “qui passa qualcosa”. È un’incoerenza voluta, per non perdere due risultati dell’intervista. Si può lasciarle così, marcarle in modo diverso, oppure spostarle nel
pannello laterale e tenere la mappa pulita.
RF ↔

4. Le tre scelte che non hanno nessuna fonte

Non vengono né dalla vostra lista né dall’intervista: le ho decise io costruendo la mappa. Sono le prime cose da mettere in discussione.

La dimensione dei cerchi

È un’ipotesi di peso nell’esperienza, fatta a occhio. O si dichiara un criterio — quanto
spesso il viaggiatore incontra quell’attore, oppure quanto quell’attore può far saltare la
coincidenza — o si uniformano tutti i cerchi.

I sei cluster

Ho scartato due alternative. Front-stage e back-stage è una logica da blueprint e
spezza gli attori che stanno in entrambi. La distanza dall’utente, cioè primari e
secondari, moltiplicava i doppioni. Ho adottato il ruolo nel sistema, come nel
riferimento Mercafir.

. Che cosa questa mappa non dice

5

Il tempo e la sequenza. Due attori collegati da una freccia possono non incontrarsi mai nello stesso momento.


L

a frequenza. Una relazione che scatta ogni giorno e una che scatta una volta l’anno hanno la stessa freccia.



L

a qualità della relazione, tranne nelle due frecce anomale qui sopra.



Il punto di vista dei viaggiatori. Non c’è nessuna intervista a un passeggero: i cinque profili sono dedotti, non osservati.


Il lato dell’impresa ferroviaria. L’unica testimonianza raccolta è di RFI, e descrive una linea sola.
Mappa e spiegazione costruite con Claude a partire dalla lista del gruppo, dal riferimento Mercafir e dall’intervista al capostazione. Versione 2, novembre 2026.

“Fattori esterni”

eteo, guasti e scioperi sono l’unico elemento della mappa che non è un soggetto:
sono eventi. Restano perché il gruppo voleva anche gli attori immateriali, ma sono il
candidato più ovvio a uscire se si vuole una mappa rigorosa.
M', null, 'Testo estratto automaticamente; alcune lettere iniziali risultano staccate. Il contenuto pulito è in attori (cerchi bianchi), flussi e contenuti.'),
  ('tre_scoperte', 'Tre scoperte dalla user journey', 'Tre scoperte.pdf', 'pdf', 2118, 'DE CIA - COINCIDENZE', 'Che cosa dice il viaggio reale di uno studente pendolare e dove il servizio può intervenire: a che punto siamo, tre scoperte, il prossimo passo di progetto.', null, 'novembre 2026', 'Racconto diretto del viaggiatore (24 novembre 2026) e intervista a un capostazione sulla linea Bologna–Padova. Una sola testimonianza per lato: la versione del capotreno manca ancora.', 'ricerca/tre-scoperte.pdf', 'Tre scoperte dalla user journey
Che cosa dice il viaggio reale di uno studente pendolare, e dove il servizio può intervenire. Ogni scoperta nasce dal confronto fra il racconto del viaggiatore e l’intervista al capostazione.
A CHE PUNTO SIAMO

Fatto

In verifica

Prossimo passo

Actors map del sistema, 40 attori e 46 flussi.

Un’intervista a un capostazione.

Una user journey completa del viaggiatore, con orari reali.

La versione del capotreno: la stessa catena vista da bordo.

Il tempo reale di attraversamento a Monselice.

Progettare come le richieste di coincidenza arrivano al capotreno.

1

L’informazione arriva troppo tardi
Quello che il viaggiatore vede non è quello che gli serve.
CHE COSA SUCCEDE

ritardo 8 min

Sullo schermo di bordo si legge il ritardo di adesso. Ma il treno spesso lo recupera, e il viaggiatore lo scopre solo quando arriva a Monselice.

qui decidi,

e qui guardi

qui si vede


se serviva

PERCHÉ CONTA

Per 37 minuti decide usando un numero destinato a cambiare. Il dato che gli servirebbe — il ritardo previsto all’arrivo — esiste già: lo conoscono il capotreno e il Dirigente
Centrale.
ritardo 2 min

Bevilacqua 6.44
DOVE SI INTERVIENE

Mostrare a bordo la previsione all’arrivo, non il ritardo corrente.

2

Monselice 7.21

Il numero che leggi a bordo non è il numero che deciderà la tua coincidenza.

La richiesta dipende dal caso

Davanti allo stesso ritardo succedono tre cose diverse.
CHE COSA SUCCEDE

Fermi tu il capotreno

A volte è il viaggiatore a fermare il capotreno. A volte è il capotreno a chiedere ad alta voce chi deve fare un cambio. A volte nessuno dice niente.

✓

la catena parte

Vedi il ritardo

a bordo

PERCHÉ CONTA

Il capostazione racconta che la catena parte dalla richiesta del passeggero. La journey mostra che a volte parte dal capotreno. Quindi la coincidenza non dipende dal bisogno:
dipende da chi c’è quel giorno.

È il capotreno a chiedere

✓

la catena parte

Non dici niente

✕

la catena non parte
DOVE SI INTERVIENE

Rendere sistematica la domanda che alcuni capotreni già fanno.

3

La catena parte solo se qualcuno parla. Chi parla cambia ogni giorno.

I nove minuti non sono nove minuti
Il margine sulla carta non è il margine reale.
Binario 1

CHE COSA SUCCEDE

Il treno arriva al binario 6. Il treno per Bologna parte dal binario 1. In mezzo c’è tutta la stazione da attraversare.

treno per Bologna, 7.30

Binario 2
Binario 3
Binario 4

PERCHÉ CONTA

Il margine utile è nove minuti meno l’attraversamento. E i binari li assegna il capostazione, la stessa figura che può decidere di trattenere il treno: due leve nelle stesse mani,
usate separatamente.

attraversamento della stazione

DOVE SI INTERVIENE

arrivo da Bevilacqua, 7.21

Il tempo di attraversamento non è ancora stato misurato: è il prossimo dato da raccogliere.

Avvicinare i binari quando si sa che c’è un cambio, prima ancora di trattenere il treno.

IL PROSSIMO PASSO DI PROGETTO

Come arriva al capotreno la richiesta di chi deve fare una coincidenza
La scoperta 2 dice che la catena parte solo se qualcuno parla, e che chi parla cambia ogni giorno. Il passo successivo è progettare il modo in cui quelle richieste vengono raccolte.
QUELLO CHE ESISTE GIÀ

LE DOMANDE DA RISOLVERE

— Alcuni capotreni chiedono ad alta voce chi deve fare un cambio: il servizio esiste già, in forma orale e non sistematica.

— Il canale a valle c’è ed è il telefono: capotreno → capostazione → Dirigente Centrale.

— La decisione è già definita: pochi minuti li concede il capostazione, di più serve il benestare della linea.

— Quando si dichiara: all’acquisto, alla salita, o solo quando il ritardo supera una soglia?

— Chi dichiara: il viaggiatore di sua iniziativa, o il servizio che già conosce l’itinerario di un abbonato?

— Con che canale: a voce, dall’app, dal posto a sedere?

— Che cosa riceve il capotreno: quante persone, o quali coincidenze?

— Che cosa torna indietro al viaggiatore: un sì, un no, o un “stiamo chiedendo”?

Fonti: racconto diretto del viaggiatore (24 novembre 2026) e intervista a un capostazione sulla linea Bologna–Padova. Una sola testimonianza per lato: la versione del capotreno manca ancora.

= margine reale

Binario 5
Binario 6

Attenzione: raccogliere le richieste non basta se la risposta non torna indietro. Oggi il viaggiatore non sa mai come è andata finché non scende dal treno.

9 min − attraversamento', null, 'Contenuto pulito in scoperte, stato_avanzamento, domande_aperte e contenuti.'),
  ('user_journey', 'User Journey', 'User Journey.pdf', 'pdf', 4231, 'DE CIA - COINCIDENZE', 'Tre user journey sullo stesso scenario: studente pendolare (Bevilacqua → Monselice → Ferrara), capotreno e capostazione. Righe: fasi, azioni, comportamenti, touchpoint, canali, attori, domande, emozioni, criticità, opportunità.', 'bozza', '24 novembre 2026', 'Racconto diretto di Stefano (24 novembre 2026); intervista al capostazione (risposte 1–13). Struttura ripresa dal modello Journey Map caricato dal gruppo.', 'ricerca/user-journey.pdf', 'User journey · Studente pendolare

Bisogni primari
— Essere in dipartimento all’inizio della lezione

— Non perdere la coincidenza di nove minuti a Monselice

Sapere in anticipo se il primo treno è in ritardo

Usare l’ora e mezza di viaggio per studiare o riposare

Bevilacqua → Monselice → Ferrara · mattina feriale · racconto diretto di Stefano, 24 novembre 2026
BOZZA: le righe in arancione sono ipotesi mie, da confermare o correggere.

Pre-servizio

Fasi

Azioni principali

Servizio

Post-servizio

1. Sveglia e partenza

2. Auto e arrivo in stazione

3. Primo treno

4. Il cambio

5.50 – 6.30

6.30 – 6.40 · Bevilacqua

6.44 – 7.21 · Bevilacqua → Monselice

7.21 – 7.30 · Monselice · 9 minuti

— Si sveglia alle 5.50

— Riceve a un orario fisso la notifica dell’app: dice se la tratta è in
orario

— Controlla sull’app dove si trova il treno, due o tre stazioni prima
della sua

— Si prepara ed esce di casa

— Ha un abbonamento trimestrale: non compra il biglietto ogni
giorno

— Guida 10 minuti fino a Bevilacqua

— Parcheggia e raggiunge la banchina

— Sull’app vede orario stimato ed effettivo di partenza e di arrivo: al
parcheggio sa già quando passa il treno

— Ricontrolla l’app sulla banchina, perché a Bevilacqua non c’è il
tabellone

— Sale sul regionale delle 6.44

— Viaggia 37 minuti

— Legge il ritardo sullo schermo di bordo

— Spesso il treno recupera il ritardo, ma lo scopre solo arrivando a
Monselice

— Con un ritardo grande: a volte ferma il capotreno che passa, a
volte lo sente chiedere lui chi deve fare il cambio, a volte sta zitto e
spera

? Usa il tempo per studiare, leggere o dormire

— Scende a Monselice alle 7.21, di solito al binario 6

— Il treno per Bologna parte dal binario 1: deve attraversare tutta la
stazione

— Raggiunge la banchina e sale entro le 7.30

— Con un ritardo grande decide se correre o rinunciare

5. Secondo treno

6. Ultimo miglio

— Viaggia 46 minuti fino a Ferrara

— Qui è più tranquillo: si rassegna all’ora in cui arriverà

— Anche il secondo treno ritarda spesso di due o tre minuti

? Riprende quello che stava facendo sul primo treno

— Esce dalla stazione di Ferrara

— Prende il bus delle 8.21

— Arriva al Dipartimento di Architettura

7.30 – 8.16 · Monselice → Ferrara

8.16 – 8.35 ca. · Ferrara · bus alle 8.21

Comportamenti

Si sveglia

Touchpoints

Guarda il telefono

· Sveglia del telefono

· Notifica automatica sullo stato della tratta

· App di viaggio

Canali

Attori coinvolti

Guida e parcheggia

· Auto e parcheggio

· Banchina di Bevilacqua, senza tabellone

· Annuncio sonoro di stazione

· App di viaggio

· Abbonamento trimestrale al treno

Digitale

Fisico

Digitale

App di viaggio

Impresa ferroviaria

Viaggia seduto

Sale sul treno

Controlla l’app

· Carrozza del regionale

· Schermi di bordo

· App di viaggio

· Capotreno del primo treno

? Annunci di bordo

Vocale

Fisico

Stazione di partenza

· Sottopasso di Monselice, dal binario 6 al binario 1

· Tabellone di stazione

· Annunci sonori

Vocale

Digitale

Cerca il tabellone

Dal binario 6 all’1

Fisico

Visivo

Capotreno treno 1
Macchinisti

Capostazione
Capotreno treno 2

Tabelloni e annunci

Stazione di cambio

Viaggia seduto

Calcola l’arrivo

· Carrozza del regionale

Vocale

Esce dalla stazione

Prende il bus

· Uscita della stazione di Ferrara

· Fermata e bus urbano

· Abbonamento mensile urbano

Digitale

Fisico

Fisico

Capotreno treno 2

Trasporto locale (bus)

Tabelloni e annunci

Altri passeggeri

Domande

Emozioni

I

?
“Devo uscire prima?”

“Ce la farò a prendere il treno?”
“ l treno è in orario ”


?

?

“Faccio in tempo a prendere il 6.44 ”


“Stiamo recuperando o no ”


“

“Trovo parc

“

“

heggio?”


“

Quando arrivo in stazione il treno arriverà o si blocca in qualche

stazione?”

“

Quanto ritardo abbiamo davvero?”


Chiedo al capotreno o sto zitto?”

Da che binario parte?”


Ce la faccio ad arrivare dal 6 all’1?”


A che ora arriverò davvero?”


“

?

“Se lo perdo, quando passa il prossimo ”

“

Riuscirò a prendere l’autobus?”

I
à passato?”

“Conviene andare a piedi?”
“ l bus è gi

Soddisfatto

Soddisfatto

Soddisfatto

Soddisfatto

Soddisfatto

Soddisfatto

Incerto

Incerto

Incerto

Incerto

Incerto

Incerto

Frustrato

Frustrato

Frustrato

Frustrato

Frustrato

Frustrato

Criticità

— Il viaggiatore si è costruito da solo un sistema di allerta: notifica a
orario fisso e controllo della posizione del treno

— La notifica dice se la tratta è in orario, non se la coincidenza di
Monselice è a rischio


— A Bevilacqua non c’è un tabellone: solo un annuncio sonoro,
quindi l’app resta l’unica fonte

— Se perde il 6.44 aspetta un’ora: arriva a destinazione un’ora dopo
e tutta la giornata slitta

— La frustrazione sale qui, quando arriva in stazione e scopre che il
ritardo è aumentato

— Il ritardo si vede sullo schermo, ma non si sa se verrà recuperato:
la risposta arriva solo all’arrivo

— La richiesta di tenere la coincidenza nasce qui, a bordo, non al
cambio

— Tre comportamenti davanti allo stesso problema: fermare il
capotreno, rispondere se chiede lui, oppure tacere

— Quando il capotreno chiede chi deve fare il cambio la catena
parte da sola, ma dipende dal singolo capotreno

— Nove minuti di margine, ma il binario di arrivo è il più lontano da
quello della coincidenza: dal 6 all’1

— Il margine reale non è di nove minuti: è nove minuti meno il tempo
di attraversare la stazione

— Chi assegna i binari è il capostazione, cioè la stessa figura che
potrebbe trattenere il treno

— Se la coincidenza salta si aspetta un’ora: il treno per Bologna
passa ogni ora, alle 27 o alle 30

— Bastano due o tre minuti di ritardo per fargli perdere l’autobus
delle 8.21

— La tranquillità qui è rassegnazione: ha smesso di provare a
recuperare

— Seconda coincidenza stretta: treno 8.16, bus 8.21, cinque minuti

— Due o tre minuti di ritardo del treno bastano a fargli perdere il bus

— Il bus successivo passa intorno alle 8.36: altri venti minuti di
attesa

Opportunità

— La notifica che riceve già potrebbe dire non solo “il treno è in
orario”, ma “con questo ritardo la coincidenza di Monselice è a
rischio”

— L’orario stimato c’è già: quello che manca è quanto sia affidabile,
perché il ritardo cambia fino a Monselice

— Avviso a bordo quando il ritardo mette a rischio la coincidenza,
prima dell’arrivo

— Il dato esiste già: lo conoscono il capotreno e il Dirigente
Centrale

— Rendere sistematica la domanda che alcuni capotreni fanno già:
“chi deve fare un cambio a Monselice?”

— Assegnare al treno in arrivo un binario vicino a quello della
coincidenza, quando si sa chi deve cambiare

— Rendere automatica la richiesta di attesa, invece che su iniziativa
del passeggero

— Tabelloni di binario con i prossimi tre o quattro treni (proposta del
capostazione)

— Dire subito che cosa succede se la coincidenza salta: quando
passa il prossimo treno e a che cosa si ha diritto

— Dire già a bordo se il bus delle 8.21 è ancora raggiungibile, e qual
è l’alternativa

— Collegare l’orario del bus urbano all’arrivo reale del treno

Come leggere questa bozza

Testo scuro: viene dal tuo racconto del 24 novembre. Orari, tratte e azioni sono tuoi.

? Testo arancione: ipotesi mia. Nessuna fonte la conferma, serve che tu la corregga o la cancelli.

I pallini colorati nella riga Attori rimandano ai sei cluster della actors map, stesso colore.

Le barre delle emozioni sono inventate da me per dare una forma alla curva: sono il primo dato da sostituire.

Struttura ripresa dal modello Journey Map che hai caricato. Righe aggiunte rispetto a quel modello: Attori coinvolti, per agganciare la journey alla actors map.', 'Trascrizione delle due journey che nel PDF sono immagini. ''? '' = testo arancione (ipotesi). Pallino pieno = attore con fonte; pallino vuoto = attore dedotto.

USER JOURNEY · CAPOTRENO
Bevilacqua → Monselice → Ferrara · cambio di 4 minuti a Monselice · stesso scenario della journey dello studente pendolare
BOZZA: le righe in arancione sono ipotesi, da confermare o correggere.
Bisogni primari:
— Conosce già il ritardo e potrebbe avvisare (il dato esiste)
— ? Sapere chi ha una coincidenza da prendere
— ? Poter chiedere l''attesa del treno 2 senza passare solo dal telefono

FASE 1. Presa servizio (Pre-servizio) — prima delle 6.44 · Bevilacqua
Comportamenti: Prende servizio → Controlla il treno
Canali: Fisico, Digitale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 55, incerto 30, frustrato 5 su 100
Azioni principali:
  ? Riceve il turno e controlla la composizione del treno
  ? Controlla gli avvisi di circolazione sulla linea
  ? Sale sul regionale a Bevilacqua
Touchpoints:
  ? Foglio turno
  ? Palmare / tablet
Attori coinvolti:
  — Impresa ferroviaria (pallino vuoto)
  — Sala operativa (pallino pieno)
Domande:
  ? “Ci sono ritardi sulla linea oggi?”
  ? “Il palmare funziona?”
Criticità:
  ? Le informazioni sulla linea arrivano frammentate
  ? Non è chiaro quali strumenti abbia davvero
Opportunità:
  ? Briefing con le coincidenze più a rischio del giorno

FASE 2. Viaggio sul treno 1 (Servizio) — 6.44 – 7.26 · Bevilacqua → Monselice
Comportamenti: Viaggia → Controlla l''orario
Canali: Fisico, Vocale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 65, incerto 25, frustrato 5 su 100
Azioni principali:
  — Viaggia 42 minuti fino a Monselice
  ? Fa gli annunci a bordo
  ? Controlla i biglietti e assiste i passeggeri
Touchpoints:
  — Carrozza del regionale
  ? Annunci di bordo
Attori coinvolti:
  — Capotreno 1 (pallino vuoto)
  — Macchinisti (pallino vuoto)
  — Altri passeggeri (pallino vuoto)
Domande:
  ? “Siamo in orario?”
  ? “Chi ha una coincidenza a Monselice?”
Criticità:
  — Il ritardo si accumula durante il viaggio e nessuno dice se mette a rischio la coincidenza
  ? Non sa chi ha una coincidenza da prendere
Opportunità:
  — Avviso a bordo quando il ritardo mette a rischio la coincidenza
  — Il dato esiste già: lo conosce il capotreno e il DCO

FASE 3. Ritardo e decisione (Servizio) — durante il viaggio · se il treno 1 è in ritardo
Comportamenti: Telefona → Aspetta la risposta
Canali: Vocale, Digitale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 15, incerto 55, frustrato 40 su 100
Azioni principali:
  — Il ritardo passa per telefono lungo la catena della coincidenza
  ? Chiede alla sala operativa se il treno 2 può aspettare
  ? Aspetta una risposta
Touchpoints:
  — Telefono di servizio
  ? Palmare / tablet
Attori coinvolti:
  — Sala operativa (pallino pieno)
  — RFI (pallino pieno)
  — Capostazione (pallino pieno)
Domande:
  ? “Il treno 2 ci aspetta?”
  ? “Chi decide e quando risponde?”
Criticità:
  — Il coordinamento tra RFI e sala operativa non funziona
  — La richiesta di attendere parte solo se il viaggiatore la fa al capotreno
Opportunità:
  — Rendere automatica la richiesta di attesa, invece che su iniziativa del passeggero

FASE 4. Il cambio a Monselice (Servizio) — 7.26 – 7.30 · 4 minuti [fase critica]
Comportamenti: Annuncia il binario → Risponde ai passeggeri
Canali: Fisico, Vocale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 5, incerto 45, frustrato 75 su 100
Azioni principali:
  — Arriva a Monselice alle 7.26
  ? Annuncia il binario del treno per Bologna
  ? Risponde ai passeggeri che hanno fretta
Touchpoints:
  — Banchina e sottopasso di Monselice
  — Annunci sonori
  ? Contatto diretto con i passeggeri
Attori coinvolti:
  — Capostazione (pallino pieno)
  — Capotreno 2 (pallino vuoto)
  — Stazione di cambio (pallino vuoto)
  — Altri passeggeri (pallino vuoto)
Domande:
  ? “Posso trattenere i passeggeri o chiedere l''attesa?”
  ? “Come spiego il binario senza gergo?”
Criticità:
  — Quattro minuti di margine: qualsiasi ritardo fa saltare la coincidenza
  — Gli annunci in gergo ferroviario non vengono capiti
  — Il biglietto non garantisce la coincidenza
  ? Non è chiaro cosa può promettere al viaggiatore
Opportunità:
  — Tabelloni di binario con i prossimi tre o quattro treni
  ? Frasi standard senza gergo per gli annunci

FASE 5. Dopo il cambio (Post-servizio) — se la coincidenza salta
Comportamenti: Indirizza → Segnala l''evento
Canali: Fisico, Digitale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 20, incerto 40, frustrato 45 su 100
Azioni principali:
  — Se la coincidenza salta non esiste un piano: si aspetta il treno dopo
  ? Rimanda i passeggeri alla biglietteria
  ? Segnala l''evento nel rapporto di servizio
Touchpoints:
  — Biglietteria
  ? Rapporto di servizio
Attori coinvolti:
  — Biglietteria (pallino pieno)
  — Capostazione (pallino pieno)
Domande:
  ? “Come finisce per chi ha perso la coincidenza?”
  ? “Il mio rapporto serve a qualcosa?”
Criticità:
  — Il rimborso chiesto in biglietteria non viene accolto
  — I bus sostitutivi sono previsti solo in caso di soppressione
  ? Nessun ritorno sul rapporto inviato
Opportunità:
  — Dire subito cosa succede se la coincidenza salta: quando passa il prossimo treno e a cosa si ha diritto

Come leggere questa bozza: vedi tabella journey, colonna come_leggere.

USER JOURNEY · CAPOSTAZIONE
Stazione di cambio sulla linea Bologna–Padova · scenario: cambio di 4 minuti a Monselice (7.26–7.30) · basata sull''intervista al capostazione
BOZZA: le righe in arancione sono ipotesi, da confermare o correggere.
Bisogni primari:
— Rispettare l''orario dei treni viaggiatori
— Venire incontro al viaggiatore, se i tempi lo permettono
— Avere il nulla osta del Dirigente Centrale prima di trattenere un treno
— ? Sapere in anticipo chi ha una coincidenza da prendere

FASE 1. Orario e fasce di punta (Pre-servizio) — prima della mattina · stazione di cambio
Comportamenti: Legge l''orario → Pesa le fasce di punta
Canali: Fisico, Vocale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 60, incerto 30, frustrato 5 su 100
Azioni principali:
  — Ha davanti l''orario: ogni treno ha un arrivo e una partenza
  — Sa che nelle fasce di punta i treni dei pendolari hanno più importanza
  ? Controlla gli avvisi di circolazione
Touchpoints:
  — Orario dei treni
  ? Telefono di servizio
Attori coinvolti:
  — Capostazione (pallino pieno)
  — Dirigente Centrale (Bologna) (pallino pieno)
  — Pendolari (pallino pieno)
Domande:
  ? “Il treno viaggiatori rispetta l''orario?”
  ? “Quali treni oggi contano di più?”
Criticità:
  — Le coincidenze e i comporti non sono più normati: il vecchio RCT li prevedeva, oggi non esistono
  ? Nessuna regola scritta a cui appoggiarsi quando arriva una richiesta
Opportunità:
  ? Una regola scritta sulle coincidenze nelle fasce di punta

FASE 2. Treno 1 in arrivo (Servizio) — 7.00 – 7.26 · gestione ordinaria
Comportamenti: Assegna il binario → Segue l''arrivo
Canali: Fisico, Vocale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 65, incerto 25, frustrato 5 su 100
Azioni principali:
  — Gestisce la circolazione dei treni dentro la propria stazione
  — Può ricevere un treno su un binario senza dare spiegazioni al Dirigente Centrale
  — Il Dirigente Centrale gestisce i treni in linea dalla sede di Bologna
Touchpoints:
  — Binari della stazione
  — Tabelloni sui binari (solo il prossimo treno)
  — Altoparlanti
Attori coinvolti:
  — Capostazione (pallino pieno)
  — Dirigente Centrale (Bologna) (pallino pieno)
  — Pendolari (pallino pieno)
Domande:
  ? “Il treno 1 arriva in orario?”
  ? “Su quale binario lo ricevo?”
Criticità:
  — Per i treni viaggiatori il rispetto dell''orario è fondamentale
  — Possono capitare mille situazioni singolari fuori dall''orario
  ? Un ritardo del treno 1 non gli arriva in anticipo
Opportunità:
  ? Avviso anticipato dal capotreno sui passeggeri con un cambio

FASE 3. La telefonata del capotreno (Servizio) — poco prima delle 7.26 · se il treno 1 è in ritardo
Comportamenti: Riceve la richiesta → Valuta la fattibilità
Canali: Vocale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 35, incerto 50, frustrato 15 su 100
Azioni principali:
  — Il capotreno telefona: un passeggero in arrivo (es. da Ravenna) non deve perdere l''ultimo treno per Padova
  — Valuta se la cosa è fattibile
  — Se si parla di pochi minuti, cerca di venire incontro al viaggiatore
Touchpoints:
  — Telefono di servizio
  — Orario del treno in coincidenza
Attori coinvolti:
  — Capotreno (pallino pieno)
  — Capostazione (pallino pieno)
  — Viaggiatore con coincidenza (pallino pieno)
Domande:
  ? “Quanti minuti servono per tenere fermo il treno?”
  ? “Decido io o devo chiamare Bologna?”
Criticità:
  — La richiesta arriva solo a telefono e solo se il capotreno la fa
  — Se il tempo di attesa è maggiore, non può decidere da solo
  ? Non sa quanti passeggeri sono coinvolti
Opportunità:
  — Rendere automatica la richiesta di attesa, invece che su iniziativa del passeggero
  ? Vedere quanti passeggeri hanno un cambio prima di decidere

FASE 4. Trattenere il treno? (Servizio) — 7.26 – 7.30 · 4 minuti [fase critica]
Comportamenti: Chiama il Dirigente → Aspetta il benestare
Canali: Vocale, Fisico
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 5, incerto 50, frustrato 65 su 100
Azioni principali:
  — Se serve più tempo, spiega il problema al Dirigente Centrale a Bologna e chiede il benestare
  — Il Dirigente Centrale si interfaccia con il Responsabile dell''impresa ferroviaria (Trenitalia) e comunica il da farsi
  — Se il Dirigente Centrale ordina di trattenere, ha l''obbligo di ottemperare
  — Normalmente si cerca di agevolare il viaggiatore
Touchpoints:
  — Telefono con il Dirigente Centrale
  — Nulla osta del Dirigente Centrale
  — Annunci sonori in stazione
Attori coinvolti:
  — Dirigente Centrale (Bologna) (pallino pieno)
  — Resp. impresa ferroviaria (Trenitalia) (pallino pieno)
  — Sala Operativa TPER (pallino pieno)
  — Capostazione (pallino pieno)
Domande:
  ? “Quanto posso trattenere senza danneggiare gli altri treni?”
  ? “Arriverà il benestare?”
  ? “Chi avvisa il capotreno del treno 2?”
Criticità:
  — Più di pochi minuti richiede la catena capostazione → Dirigente Centrale → impresa → capostazione
  — RFI e Sala Operativa TPER viaggiano su binari paralleli: ci provano da anni con pessimi risultati
  — Senza norma, tutto dipende dal benestare del momento
Opportunità:
  ? Un canale unico condiviso tra capostazione, Dirigente Centrale e impresa
  ? Un criterio scritto sui minuti di attesa accettabili

FASE 5. Dopo il cambio (Post-servizio) — viaggiatori e coincidenza saltata
Comportamenti: Parla ai viaggiatori → Indirizza all''attesa
Canali: Fisico, Vocale
Emozioni (stima dalle barre, tutta da verificare): soddisfatto 25, incerto 40, frustrato 40 su 100
Azioni principali:
  — Se il treno parte, i pendolari la prendono con filosofia
  — Chi non conosce il regolamento va in biglietteria a chiedere il rimborso, inutilmente
  — Con chi protesta cerca di andare incontro finché ci sono educazione e rispetto
  — Se un treno è soppresso, mette in piedi autobus sostitutivi
Touchpoints:
  — Biglietteria
  — Altoparlanti (oggi in italiano chiaro)
  — Tabelloni sui binari
Attori coinvolti:
  — Pendolari (pallino pieno)
  — Viaggiatori non informati (pallino pieno)
  — Biglietteria (pallino pieno)
  — Bus sostitutivi (pallino pieno)
Domande:
  ? “Quando passa il prossimo treno?”
  ? “Posso avere il rimborso?”
Criticità:
  — Il rimborso chiesto in biglietteria non viene accolto
  — Bus: tempi di attesa altissimi; con un treno all''ora conviene aspettare il successivo
  — Un tempo gli annunci erano in gergo ferroviario e il 95% non li capiva (oggi migliorati)
Opportunità:
  — Tabelloni con i prossimi 3 o 4 treni sul binario, come in Germania: tranquillizzerebbe i viaggiatori (proposta del capostazione)
  ? Dire subito cosa succede se la coincidenza salta e a cosa si ha diritto

Come leggere questa bozza: vedi tabella journey, colonna come_leggere.
', 'La journey dello studente è testo; le journey del capotreno e del capostazione nel PDF sono immagini, quindi sono state trascritte leggendo le immagini. Tutto è anche in journey, journey_fasi, journey_elementi.'),
  ('memoria_progetto', 'Memoria del progetto', 'MEMORIA_PROGETTO.md', 'md', 1, 'repository GitHub', 'Memoria del progetto DE CIA: team, tempo disponibile, obiettivo di coordinamento, elenco del materiale di ricerca.', null, '26 novembre 2026', 'Scritta con Claude.', 'ricerca/memoria-progetto.md', '# Memoria del progetto DE CIA

_Ultimo aggiornamento: 26 novembre 2026_

## Il progetto

- **Nome:** DE CIA
- **Team:** Stefano, Benedetta, Beatrice
- **Tempo disponibile:** da 1 a 2 giorni a settimana
- **Obiettivo di coordinamento:** supportare il team nel decision making e nelle scelte di implementazione, spendendo il meno possibile per ottenere un risultato ottimale.

## Materiale di ricerca

Cartella **"DE CIA - COINCIDENZE"**, con i PDF della ricerca sui viaggi in treno con coincidenza:

- Actors map (v2) del viaggio in treno con coincidenza
- User journey
- Schema tratto dall''intervista
- La catena decisionale
- Dove si rompe il viaggio
- Tre scoperte

## Strumenti

- **Sito:** pagina statica (index.html + style.css) pubblicata gratis su Vercel da main.
- **Database:** Supabase, piano gratuito, progetto "DE-CIA". Struttura, dati e guida nella cartella `supabase/` (vedi `supabase/GUIDA.md`); file originali nel bucket privato "ricerca".', null, null),
  ('anteprima_sito', 'Anteprima della pagina web', 'anteprima-pagina.png', 'png', 670, 'sito', 'Screenshot della prima pagina web del progetto (index.html) pubblicata su Vercel.', null, '26 novembre 2026', null, 'ricerca/anteprima-sito.png', '', null, 'Immagine di anteprima del sito; il testo del sito è nel repository (index.html).');

insert into fonti (codice, titolo, tipo, data, descrizione, limiti) values
  ('intervista_capostazione', 'Intervista ad Andrea, capostazione di Ferrara', 'intervista', 'novembre 2026', 'Intervista a un capostazione sulla linea Bologna–Padova (lato gestore dell''infrastruttura, RFI). Risposte numerate R1–R13.', 'È una testimonianza situata, non la descrizione ufficiale del sistema: va letta come una fonte, da confrontare con le altre. Una sola intervista, dal lato del gestore dell''infrastruttura; descrive una linea sola. Non nomina la stazione (Monselice viene dallo scenario condiviso).'),
  ('racconto_viaggiatore', 'Racconto diretto del viaggiatore (Stefano)', 'racconto diretto', '24 novembre 2026', 'Racconto della mattina reale di uno studente pendolare: Bevilacqua → Monselice → Ferrara. Orari, tratte e azioni.', 'Una sola testimonianza dal lato del viaggiatore. Non c''è nessuna intervista a un passeggero: i cinque profili di viaggiatore della mappa sono dedotti, non osservati.'),
  ('lista_gruppo', 'Lista grezza degli attori del gruppo (due liste)', 'lista del gruppo', null, 'Le due liste di attori preparate dal gruppo; i doppioni sono stati fusi e tutto riorganizzato in sei cluster. Citata anche come "PDF del gruppo" (catena 1).', null),
  ('mercafir', 'Riferimento Mercafir', 'riferimento', null, 'Modello di actors map con quattro flussi (economico, merce, persone, informazioni) e cluster per ruolo nel sistema.', null),
  ('modello_journey_map', 'Modello Journey Map caricato dal gruppo', 'riferimento', null, 'Struttura usata per le user journey. Riga aggiunta: Attori coinvolti, per agganciare la journey alla actors map.', null),
  ('inferenza_claude', 'Ipotesi e inferenze di Claude', 'inferenza', 'novembre 2026', 'Elementi aggiunti per coprire i buchi del perimetro o ricavati da conoscenza generica del sistema ferroviario (cerchi bianchi, flussi economici e istituzionali, testo arancione nelle journey, barre delle emozioni).', 'Plausibili, non verificate: restano da verificare finché non c''è una fonte.'),
  ('capotreno_mancante', 'Versione del capotreno', 'da raccogliere', null, 'La stessa catena vista da bordo. Probabilmente conferma la catena, ma copre la parte che il capostazione non vede.', 'Non ancora raccolta.');

insert into riferimenti_intervista (codice, tipo, tema, contenuto, citato_in) values
  ('R1', 'risposta', 'La catena della coincidenza', 'Il viaggiatore chiede al capotreno; il capotreno telefona al capostazione della stazione di cambio; per pochi minuti decide il capostazione; per un''attesa più lunga serve il benestare del Dirigente Centrale, che si interfaccia con il Responsabile dell''impresa e comunica il da farsi. Normalmente si cerca di agevolare il viaggiatore. Strumento: telefono. Esempio: dall''arrivo di Ravenna all''ultimo treno per Padova.', 'Schema tratto dall''intervista; La catena decisionale; Actors map'),
  ('R5', 'risposta', 'Orario, leve del capostazione e ordine del Dirigente Centrale', 'L''orario è il primo vincolo: per i treni viaggiatori il rispetto dell''orario è fondamentale. Il capostazione assegna il binario al treno in arrivo senza spiegazioni al Dirigente Centrale (leva autonoma). Il Dirigente Centrale gestisce i treni in linea e può ordinare di trattenere un treno fino al suo nulla osta: il capostazione ha l''obbligo di ottemperare.', 'Schema tratto dall''intervista'),
  ('R6', 'risposta', 'Nessuna norma', 'Coincidenze e comporti non sono più normati (ex Regolamento Circolazione Treni). Esistono solo fasce pendolari con più importanza.', 'Schema tratto dall''intervista'),
  ('R7', 'risposta', 'Quanti minuti per trattenere il treno', 'Nessun numero: "pochi minuti" contro "tempo maggiore".', 'Schema tratto dall''intervista'),
  ('R8', 'risposta', 'Reazione del viaggiatore dopo la coincidenza persa', 'Il pendolare abituale la prende con filosofia. Chi non è al corrente del regolamento va in biglietteria a chiedere un rimborso, inutilmente.', 'Schema tratto dall''intervista'),
  ('R9', 'risposta', 'Annunci', 'Un tempo erano in gergo ferroviario, anche sui treni: il 95% dei viaggiatori non capiva. Da qualche anno si usa un italiano più corretto.', 'Schema tratto dall''intervista'),
  ('R10', 'risposta', 'Quando la coincidenza salta', 'Se il treno è soppresso ci sono autobus sostitutivi con tempi di attesa altissimi; altrimenti, con cadenza oraria, conviene attendere un''ora e salire sul treno successivo.', 'Schema tratto dall''intervista'),
  ('R11', 'risposta', 'RFI e sala operativa', 'RFI e Sala Operativa TPER viaggiano su binari paralleli: integrazione tentata da anni, pessimi risultati. Migliorare la comunicazione con la sala operativa è un tentativo di anni con pessimi risultati.', 'Schema tratto dall''intervista'),
  ('R12', 'risposta', 'La relazione', 'La relazione conta: si va incontro al viaggiatore finché ci sono educazione e rispetto. L''ansia viene scaricata spesso sul personale.', 'Schema tratto dall''intervista'),
  ('R13', 'risposta', 'Proposta dal campo', 'Tabelloni di binario con i prossimi 3 o 4 treni in arrivo, come in Germania, per tranquillizzare i viaggiatori.', 'Schema tratto dall''intervista'),
  ('R2-R4', 'risposta', 'Non citate', 'Le risposte R2, R3 e R4 non sono citate esplicitamente in nessuno dei file.', null),
  ('D3', 'domanda_senza_risposta', 'Strumenti', 'Nelle risposte compare solo il telefono, nessun software.', 'Schema tratto dall''intervista'),
  ('D5', 'domanda_senza_risposta', 'Fattori del "No"', 'Non cita binario unico, precedenze o fine turno; indica orario, Dirigente Centrale e "mille situazioni singolari".', 'Schema tratto dall''intervista'),
  ('D6', 'domanda_senza_risposta', 'Ultima corsa', 'Non confronta ultima corsa e punta; dice solo che le fasce pendolari pesano di più.', 'Schema tratto dall''intervista'),
  ('D7', 'domanda_senza_risposta', 'Ritardo massimo', 'Rimanda alla R1: nessun numero, solo "pochi minuti" contro "tempo maggiore".', 'Schema tratto dall''intervista'),
  ('D10', 'domanda_senza_risposta', 'Riprotezione', 'Solo bus per le soppressioni e attesa del treno dopo; nessun taxi o voucher.', 'Schema tratto dall''intervista');

insert into cluster_attori (codice, nome, colore, ordine, descrizione) values
  ('viaggiatori', 'Viaggiatori', 'rosa', 1, 'I profili di viaggiatore. Collegati nella mappa come cluster, non profilo per profilo.'),
  ('personale_contatto', 'Personale di contatto', 'arancione', 2, 'Il personale che il viaggiatore incontra.'),
  ('gestione_operativa', 'Gestione operativa', 'viola', 3, 'Chi gestisce la circolazione e le decisioni operative.'),
  ('canali_strumenti', 'Canali e strumenti', 'giallo', 4, 'Canali, strumenti e luoghi attraverso cui passa l''esperienza.'),
  ('organizzazioni_istituzioni', 'Organizzazioni e istituzioni', 'azzurro', 5, 'Imprese, gestore dell''infrastruttura, enti e soggetti collettivi.'),
  ('contesto_servizi_esterni', 'Contesto e servizi esterni', 'verde acqua', 6, 'Servizi e fattori esterni al treno che toccano il viaggio.');

insert into attori (codice, nome, cluster, stato, aspetto_mappa, perche_in_mappa, come_verificarlo, valutazione, note) values
  ('pendolare_abituale', 'Pendolare abituale', 'viaggiatori', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Davanti alla coincidenza persa "la prende con filosofia" (R8).'),
  ('viaggiatore_occasionale', 'Viaggiatore occasionale / turista', 'viaggiatori', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Davanti alla coincidenza persa va allo sportello (R8).'),
  ('viaggiatore_ultimo_minuto', 'Viaggiatore dell''ultimo minuto', 'viaggiatori', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('viaggiatore_esigenze_speciali', 'Viaggiatore con esigenze speciali (PMR, passeggini, bagagli, bici)', 'viaggiatori', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, 'Unico profilo collegato singolarmente: la Sala Blu punta a lui.'),
  ('altri_passeggeri', 'Altri passeggeri in stazione e a bordo', 'viaggiatori', 'da_verificare', 'Cerchio bianco', 'L''esperienza del cambio dipende anche da chi occupa lo stesso spazio: folla nel sottopasso, coda alle scale mobili, posti già occupati sul secondo treno. Nelle liste comparivano i profili dell''utente, mai gli altri come contesto.', 'Osservazione diretta in stazione nell''ora di punta. Se il trasbordo non è mai ostacolato dagli altri, si elimina.', 'Tra i tre più solidi dei dieci cerchi bianchi.', null),
  ('capotreno_arrivo', 'Capotreno treno in arrivo', 'personale_contatto', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Riceve la richiesta del viaggiatore e telefona al capostazione (passaggio 2 della catena).'),
  ('capotreno_coincidenza', 'Capotreno treno in coincidenza', 'personale_contatto', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, null),
  ('personale_biglietteria', 'Personale di biglietteria', 'personale_contatto', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Qui arriva chi chiede un rimborso che non otterrà.'),
  ('polfer_sicurezza', 'Polfer / sicurezza', 'personale_contatto', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('assistenza_clienti', 'Assistenza clienti e informazioni in stazione', 'personale_contatto', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('sala_blu', 'Sala Blu / assistenza PMR', 'personale_contatto', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, 'Punta al viaggiatore con esigenze speciali.'),
  ('macchinisti', 'Macchinisti', 'personale_contatto', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('capostazione', 'Capostazione della stazione di cambio', 'gestione_operativa', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Comanda dentro la sua stazione e sceglie i binari senza dover spiegare nulla. Due leve: assegna il binario e può trattenere un treno di pochi minuti.'),
  ('dirigente_centrale', 'Dirigente Centrale di linea (DCO)', 'gestione_operativa', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Sede di Bologna. Comanda sulla linea e può ordinare di trattenere un treno fino al suo nulla osta.'),
  ('responsabile_impresa', 'Responsabile dell''impresa ferroviaria', 'gestione_operativa', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'L''intervista nomina Trenitalia per il treno da trattenere.'),
  ('sala_operativa_impresa', 'Sala operativa dell''impresa ferroviaria', 'gestione_operativa', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'L''intervista nomina la Sala Operativa TPER per il coordinamento con RFI.'),
  ('pulizie', 'Pulizie', 'gestione_operativa', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('manutenzione_treni', 'Manutenzione treni e depositi', 'gestione_operativa', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('manutenzione_stazione', 'Manutenzione e logistica di stazione', 'gestione_operativa', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('biglietto', 'Biglietto / titolo di viaggio', 'canali_strumenti', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Il biglietto non garantisce la coincidenza.'),
  ('app_viaggio', 'App di viaggio e canali digitali', 'canali_strumenti', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('tabelloni_annunci', 'Tabelloni e annunci in stazione', 'canali_strumenti', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Gli annunci usavano un gergo che il 95% dei viaggiatori non capiva; oggi è in parte corretto.'),
  ('telefono_servizio', 'Telefono di servizio', 'canali_strumenti', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'L''unico strumento nominato nell''intervista per la catena della coincidenza.'),
  ('stazione_cambio', 'Stazione di cambio (sottopassi, ascensori, binari)', 'canali_strumenti', 'da_verificare', 'Cerchio bianco', 'Sottopassi, ascensori, segnaletica e distanza fra i binari decidono quanti minuti servono davvero per il cambio. Nella lista c''erano gli addetti alla manutenzione, non lo spazio in sé.', 'Misurare il tempo di trasbordo reale fra i due binari più distanti: è anche il dato che serve alla journey. Se il gruppo decide che la mappa contiene solo soggetti, questo esce.', 'Tra i tre più solidi dei dieci cerchi bianchi.', null),
  ('biglietterie_self_service', 'Biglietterie self-service', 'canali_strumenti', 'da_verificare', 'Cerchio bianco', 'Il perimetro parte dall''acquisto, ma la lista aveva solo sportello e app. La macchinetta è un canale con regole proprie: coda, contanti, interfaccia, e nessuno a cui chiedere.', 'Chiedere all''impresa che quota di biglietti regionali passa da lì, oppure contarlo sul campo in mezz''ora di osservazione.', null, null),
  ('palmare_capotreno', 'Palmare / tablet del capotreno', 'canali_strumenti', 'da_verificare', 'Cerchio bianco', 'Caso diverso dagli altri: era nella lista del gruppo. È bianco perché il capostazione descrive tutta la catena al telefono e non lo nomina mai. Non è escluso che esista, è escluso che sia il canale della coincidenza.', 'È già una delle domande preparate per il capotreno. La sua risposta decide se torna colorato o sparisce.', null, 'Resta in mappa come ipotesi da verificare: nell''intervista non viene mai nominato, al suo posto compare il telefono.'),
  ('impresa_ferroviaria', 'Impresa ferroviaria', 'organizzazioni_istituzioni', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, null),
  ('rfi', 'Gestore dell''infrastruttura (RFI)', 'organizzazioni_istituzioni', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'L''unica testimonianza raccolta è di RFI. RFI e sala operativa dell''impresa non si parlano: "viaggiano su binari paralleli".'),
  ('regione_ministero', 'Regione / Ministero (ente committente)', 'organizzazioni_istituzioni', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('comuni', 'Comuni', 'organizzazioni_istituzioni', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('autorita_regolazione', 'Autorità di regolazione dei trasporti', 'organizzazioni_istituzioni', 'da_verificare', 'Cerchio bianco', 'Nella lista compariva come categoria generica, "autorità di regolazione e istituzioni". È stata resa un attore esplicito perché i diritti del passeggero in caso di coincidenza persa sono materia sua.', 'Verificare se ART abbia davvero competenza su questo o se la materia sia soltanto europea e contrattuale. È una verifica documentale, non un''intervista.', null, null),
  ('associazioni_comitati', 'Associazioni consumatori e comitati pendolari', 'organizzazioni_istituzioni', 'da_verificare', 'Cerchio bianco', 'Dopo il disservizio la lista si fermava. Qualcuno però raccoglie i reclami e li porta al committente: senza questo attore il reclamo del viaggiatore finisce nel vuoto.', 'Cercare se esistono comitati attivi sulla linea studiata. Se esistono sono anche una fonte di ricerca, non solo un attore da disegnare.', 'Tra i tre più solidi dei dieci cerchi bianchi.', null),
  ('sindacati', 'Sindacati', 'organizzazioni_istituzioni', 'da_verificare', 'Cerchio bianco', 'Nella lista lo sciopero era classificato come "fattore esterno", insieme al meteo. Ma dietro uno sciopero c''è un soggetto che decide, mentre dietro la pioggia no.', 'Nessuna verifica sul campo: è una correzione logica. Semmai si discute se lo sciopero rientri nel perimetro del progetto.', null, null),
  ('trasporto_locale', 'Trasporto locale (bus, metro)', 'contesto_servizi_esterni', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('bus_sostitutivi', 'Bus sostitutivi', 'contesto_servizi_esterni', 'confermato_intervista', 'Cerchio colorato, bordo spesso', null, null, null, 'Esistono solo per le soppressioni; con cadenza oraria conviene comunque aspettare il treno dopo.'),
  ('taxi_sharing', 'Taxi, sharing, parcheggi di scambio', 'contesto_servizi_esterni', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, null, null),
  ('fattori_esterni', 'Fattori esterni (meteo, guasti, scioperi)', 'contesto_servizi_esterni', 'lista_partenza', 'Cerchio colorato, bordo sottile', null, null, 'Candidato più ovvio a uscire se si vuole una mappa rigorosa.', 'Unico elemento della mappa che non è un soggetto: sono eventi. Restano perché il gruppo voleva anche gli attori immateriali.'),
  ('rivenditori_terzi', 'Rivenditori terzi di biglietti', 'contesto_servizi_esterni', 'da_verificare', 'Cerchio bianco', 'Se il biglietto è comprato fuori dai canali dell''impresa, quando qualcosa va storto il viaggiatore non sa più a chi rivolgersi. Tocca direttamente la coincidenza.', 'Chiedere all''impresa, o leggere le condizioni di vendita, che cosa cambia nella tutela quando il biglietto arriva da un rivenditore.', null, null),
  ('circuiti_pagamento', 'Circuiti di pagamento', 'contesto_servizi_esterni', 'da_verificare', 'Cerchio bianco', 'Completano la catena economica dell''acquisto: senza di loro il flusso del denaro si interrompe a metà.', 'Candidato alla rimozione. Esistono nel sistema ma non toccano l''esperienza della coincidenza: tenuti per coerenza del flusso economico, non perché contino.', 'Tra i due più deboli: se la mappa va alleggerita, si parte da qui.', null),
  ('esercizi_commerciali', 'Esercizi commerciali di stazione', 'contesto_servizi_esterni', 'da_verificare', 'Cerchio bianco', 'Quando la coincidenza salta, l''attesa si passa da qualche parte. Il bar è spesso l''unico servizio che il viaggiatore incontra in quel momento.', 'Tenerlo solo se la journey mostra che l''attesa è una fase con un peso suo.', 'Il più debole dei dieci; tra i due più deboli: se la mappa va alleggerita, si parte da qui.', null);

insert into tipi_flusso (codice, nome, stile, descrizione) values
  ('economico', 'Flusso economico', 'linea verde continua', 'Movimenti di denaro.'),
  ('servizio', 'Flusso di servizio', 'linea blu continua', 'Chi eroga qualcosa a chi. Sostituisce il flusso "merce" del modello Mercafir, che qui non esiste.'),
  ('persone', 'Flusso di persone', 'linea magenta continua', 'Spostamenti di persone.'),
  ('informazioni', 'Flusso di informazioni', 'linea marrone tratteggiata', 'Passaggi di informazioni.');

insert into flussi (tipo, da_attore, da_gruppo, a_attore, a_gruppo, descrizione, origine, anomalo, numero_catena, note) values
  ('informazioni', null, 'viaggiatori', 'capotreno_arrivo', null, 'Il viaggiatore chiede al capotreno di non perdere il treno successivo.', 'intervista', false, 1, null),
  ('informazioni', 'capotreno_arrivo', null, 'capostazione', null, 'Il capotreno telefona al capostazione della stazione di cambio.', 'intervista', false, 2, 'Canale: telefono di servizio.'),
  ('servizio', 'capostazione', null, 'capotreno_coincidenza', null, 'Se si tratta di pochi minuti, il capostazione decide da solo e trattiene il treno.', 'intervista', false, 3, null),
  ('informazioni', 'capostazione', null, 'dirigente_centrale', null, 'Se l''attesa è più lunga serve il benestare del Dirigente Centrale di Bologna.', 'intervista', false, 4, null),
  ('informazioni', 'dirigente_centrale', null, 'responsabile_impresa', null, 'Il Dirigente Centrale si interfaccia con il responsabile dell''impresa ferroviaria e comunica il da farsi.', 'intervista', false, 5, null),
  ('informazioni', 'rfi', null, 'sala_operativa_impresa', null, 'Il coordinamento fra RFI e sala operativa dell''impresa non funziona: "viaggiano su binari paralleli", tentativi di integrazione falliti da anni.', 'intervista', true, null, 'Freccia anomala (RFI ↔ sala operativa): dice "qui non funziona". Il gruppo deve decidere se lasciarla, marcarla diversamente o spostarla nel pannello laterale.'),
  ('persone', null, 'viaggiatori', 'personale_biglietteria', null, 'Il viaggiatore va in biglietteria a chiedere il rimborso, che non viene accolto.', 'intervista', true, null, 'Freccia anomala: dice "qui non funziona".'),
  ('servizio', 'bus_sostitutivi', null, null, 'viaggiatori', 'I bus sostitutivi esistono solo in caso di soppressione del treno.', 'intervista', false, null, null),
  ('informazioni', 'tabelloni_annunci', null, null, 'viaggiatori', 'Gli annunci in gergo ferroviario: il 95% dei viaggiatori non capiva; oggi è in parte corretto.', 'intervista', false, null, null),
  ('servizio', 'biglietto', null, null, 'viaggiatori', 'Il biglietto non garantisce la coincidenza.', 'intervista', false, null, null),
  ('servizio', 'sala_blu', null, 'viaggiatore_esigenze_speciali', null, 'La Sala Blu assiste il viaggiatore con esigenze speciali.', 'inferenza', false, null, 'Unica freccia diretta a un singolo profilo di viaggiatore.');

insert into catena_passaggi (numero, attore, attore_codice, dettaglio, azione, canale, condizione, riferimento) values
  (1, 'Viaggiatore', null, 'A bordo del treno in arrivo.', 'Chiede di non perdere la coincidenza.', 'A voce, a bordo (oppure è il capotreno a chiedere chi deve cambiare)', null, 'R1'),
  (2, 'Capotreno', 'capotreno_arrivo', 'Del treno in arrivo, a bordo.', 'Riceve la richiesta (o la chiede lui a bordo) e telefona al capostazione della stazione di cambio.', 'Telefonata', null, 'R1'),
  (3, 'Capostazione', 'capostazione', 'Della stazione di coincidenza.', 'Valuta la fattibilità. Se si parla di pochi minuti decide da solo: viene incontro al viaggiatore senza chiedere a nessuno e trattiene il treno.', 'Telefono', 'Se si parla di pochi minuti', 'R1, R7'),
  (4, 'Dirigente Centrale', 'dirigente_centrale', 'Sede di Bologna. Gestisce la circolazione in linea.', 'Se serve trattenere più a lungo, il capostazione comunica l''esigenza e spiega il problema; il Dirigente Centrale dà o nega il benestare.', 'Telefono', 'Se serve trattenere più a lungo', 'R1'),
  (5, 'Responsabile impresa', 'responsabile_impresa', 'Del treno da trattenere (Trenitalia).', 'Il Dirigente Centrale si interfaccia con lui; poi comunica il da farsi al capostazione, che esegue: trattiene o non trattiene il treno.', 'Telefono', null, 'R1, R5');

insert into schema_nodi (codice, sezione, corsia, forma, numero_catena, testo, riferimento, documentato) values
  ('v_rischio', 'Flusso principale', 'Viaggiatore', 'evento', null, 'Ha una coincidenza a rischio (es. dall''arrivo di Ravenna all''ultimo treno per Padova)', 'R1', true),
  ('v_chiede', 'Flusso principale', 'Viaggiatore', 'azione', 1, 'Chiede al capotreno di non perdere il treno', 'PDF del gruppo · catena 1', true),
  ('v_non_chiede', 'Flusso principale', 'Viaggiatore', 'non_documentato', null, 'Se non chiede, o non sa di poterlo fare, la catena non parte', 'non nell''intervista · PDF del gruppo', false),
  ('v_esito', 'Flusso principale', 'Viaggiatore', 'non_documentato', null, 'Esito al viaggiatore: nessun passaggio lo riporta', 'assente nell''intervista', false),
  ('ct_riceve', 'Flusso principale', 'Capotreno (treno in arrivo)', 'azione', null, 'Riceve la richiesta (o la chiede lui a bordo)', 'R1 · Tre scoperte', true),
  ('ct_telefona', 'Flusso principale', 'Capotreno (treno in arrivo)', 'azione', 2, 'Telefona al capostazione della stazione di cambio', 'R1', true),
  ('cs_binario', 'Flusso principale', 'Capostazione (stazione di cambio)', 'azione', null, 'Assegna il binario al treno in arrivo, senza spiegazioni al Dirigente Centrale', 'R5 · leva autonoma', true),
  ('cs_ottempera', 'Flusso principale', 'Capostazione (stazione di cambio)', 'azione', null, 'Ottempera all''ordine: trattiene il treno fino al nulla osta', 'R5 · obbligo', true),
  ('cs_valuta', 'Flusso principale', 'Capostazione (stazione di cambio)', 'azione', 3, 'Riceve la telefonata e valuta la fattibilità', 'R1', true),
  ('cs_quanti_minuti', 'Flusso principale', 'Capostazione (stazione di cambio)', 'decisione', null, 'Quanti minuti per trattenere il treno?', 'R1 · R7', true),
  ('cs_decide_solo', 'Flusso principale', 'Capostazione (stazione di cambio)', 'azione', 3, 'Decide da solo: trattiene il treno', 'R1 · pochi minuti', true),
  ('cs_riceve_dafarsi', 'Flusso principale', 'Capostazione (stazione di cambio)', 'azione', null, 'Riceve il da farsi dal Dirigente Centrale', 'R1', true),
  ('cs_esegue', 'Flusso principale', 'Capostazione (stazione di cambio)', 'azione', null, 'Esegue: trattiene o non trattiene il treno', 'R1 · R5', true),
  ('esito', 'Flusso principale', 'Capostazione (stazione di cambio)', 'esito', null, 'ESITO: il treno aspetta oppure no', 'R1 · normalmente si agevola', true),
  ('dc_gestisce', 'Flusso principale', 'Dirigente Centrale (sede di Bologna)', 'azione', null, 'Gestisce i treni in linea e può ordinare di trattenere un treno fino al suo nulla osta', 'R5', true),
  ('dc_benestare', 'Flusso principale', 'Dirigente Centrale (sede di Bologna)', 'decisione', 4, 'Benestare del Dirigente Centrale?', 'R1', true),
  ('dc_interfaccia', 'Flusso principale', 'Dirigente Centrale (sede di Bologna)', 'azione', null, 'Si interfaccia con il Responsabile dell''impresa (Trenitalia) del treno da trattenere', 'R1', true),
  ('dc_comunica', 'Flusso principale', 'Dirigente Centrale (sede di Bologna)', 'azione', 5, 'Comunica il da farsi al capostazione', 'R1', true),
  ('ri_rfi_tper', 'Flusso principale', 'Responsabile impresa ferroviaria (Trenitalia)', 'non_documentato', null, 'RFI e Sala Operativa TPER viaggiano su binari paralleli: integrazione tentata da anni, pessimi risultati', 'R11', false),
  ('ri_indica', 'Flusso principale', 'Responsabile impresa ferroviaria (Trenitalia)', 'non_documentato', 5, 'Indica come muoversi sul treno da trattenere: non è chiaro se decide o dà un parere', 'R1 · da chiarire', false),
  ('qs_persa', 'Quando la coincidenza salta', null, 'evento', null, 'Coincidenza persa', 'R8 · R10', true),
  ('qs_soppresso', 'Quando la coincidenza salta', null, 'decisione', null, 'Treno soppresso?', 'R10', true),
  ('qs_bus', 'Quando la coincidenza salta', null, 'azione', null, 'Autobus sostitutivi: tempi di attesa altissimi', 'R10', true),
  ('qs_cadenza', 'Quando la coincidenza salta', null, 'azione', null, 'Cadenza oraria: conviene attendere 1 ora e salire sul treno successivo', 'R10', true),
  ('qs_chi', 'Quando la coincidenza salta', null, 'decisione', null, 'Chi è il viaggiatore?', 'R8', true),
  ('qs_pendolare', 'Quando la coincidenza salta', null, 'azione', null, 'Pendolare abituale: la prende con filosofia', 'R8', true),
  ('qs_non_corrente', 'Quando la coincidenza salta', null, 'azione', null, 'Non è al corrente del regolamento: va in biglietteria a chiedere il rimborso, inutilmente', 'R8 · criticità', true);

insert into schema_archi (da_nodo, a_nodo, etichetta, documentato) values
  ('v_chiede', 'ct_riceve', null, true),
  ('ct_riceve', 'ct_telefona', null, true),
  ('ct_telefona', 'cs_valuta', null, true),
  ('cs_valuta', 'cs_quanti_minuti', null, true),
  ('cs_quanti_minuti', 'cs_decide_solo', 'pochi minuti', true),
  ('cs_quanti_minuti', 'dc_benestare', 'più a lungo: comunica l''esigenza e spiega il problema', true),
  ('dc_benestare', 'dc_interfaccia', 'sì / no', true),
  ('dc_interfaccia', 'ri_indica', null, true),
  ('ri_indica', 'dc_comunica', null, true),
  ('dc_comunica', 'cs_riceve_dafarsi', null, true),
  ('cs_riceve_dafarsi', 'cs_esegue', null, true),
  ('cs_decide_solo', 'esito', null, true),
  ('cs_esegue', 'esito', null, true),
  ('esito', 'v_esito', 'non documentato', false),
  ('dc_gestisce', 'cs_ottempera', 'ordine di trattenere', true),
  ('qs_persa', 'qs_soppresso', null, true),
  ('qs_soppresso', 'qs_bus', 'sì', true),
  ('qs_soppresso', 'qs_cadenza', 'no', true),
  ('qs_bus', 'qs_chi', null, true),
  ('qs_cadenza', 'qs_chi', null, true),
  ('qs_chi', 'qs_pendolare', 'pendolare', true),
  ('qs_chi', 'qs_non_corrente', 'non al corrente', true);

insert into chi_decide_cosa (attore, ordine, etichetta, testo) values
  ('Viaggiatore', 1, 'DECIDE', 'Se chiedere. Non decide se il treno aspetta.'),
  ('Viaggiatore', 2, 'SE NON CHIEDE', 'La catena non parte: nessuno la avvia al posto suo (PDF del gruppo, catena 1).'),
  ('Viaggiatore', 3, 'DOPO', 'Pendolare: la prende con filosofia. Non informato: va in biglietteria e chiede un rimborso inutilmente (R8).'),
  ('Capotreno (treno in arrivo)', 1, 'DECIDE', 'Se segnalare al capostazione un passeggero con la coincidenza a rischio (R1).'),
  ('Capotreno (treno in arrivo)', 2, 'NON DECIDE', 'La trattenuta del treno in coincidenza: la decide il capostazione o, oltre i pochi minuti, il Dirigente Centrale (R1).'),
  ('Capotreno (treno in arrivo)', 3, 'STRUMENTO', 'Telefono (R1). Nessun altro strumento nominato.'),
  ('Capostazione (stazione di cambio)', 1, 'DECIDE DA SOLO', 'Trattenere un treno per pochi minuti (R1). Ricevere un treno su un binario senza spiegazioni al Dirigente Centrale (R5).'),
  ('Capostazione (stazione di cambio)', 2, 'NON DECIDE', 'Trattenute più lunghe: serve il benestare del Dirigente Centrale (R1). Deve ottemperare se il Dirigente Centrale ordina di trattenere (R5).'),
  ('Capostazione (stazione di cambio)', 3, 'SOGLIA', '''Pochi minuti'' non è un numero: nessuna norma (R1, R6, R7) e conta anche la relazione (R12).'),
  ('Capostazione (stazione di cambio)', 4, 'STRUMENTO', 'Telefono (R1).'),
  ('Dirigente Centrale (sede di Bologna)', 1, 'DECIDE', 'La circolazione dei treni in linea Bologna–Padova (R5). Dà o nega il benestare alle trattenute lunghe (R1). Può ordinare di trattenere un treno fino al suo nulla osta (R5).'),
  ('Dirigente Centrale (sede di Bologna)', 2, 'SI CONSULTA CON', 'Il Responsabile dell''impresa ferroviaria (Trenitalia) del treno da trattenere, poi comunica il da farsi al capostazione (R1).'),
  ('Dirigente Centrale (sede di Bologna)', 3, 'NON SI COORDINA', 'RFI e Sala Operativa TPER viaggiano su binari paralleli, con tentativi falliti da anni (R11).'),
  ('Responsabile impresa ferroviaria (Trenitalia)', 1, 'RUOLO', 'Il Dirigente Centrale si interfaccia con lui sul treno da trattenere e poi comunica il da farsi (R1).'),
  ('Responsabile impresa ferroviaria (Trenitalia)', 2, 'DA CHIARIRE', 'Se decide o dà solo un parere: nell''intervista non è chiaro.'),
  ('Responsabile impresa ferroviaria (Trenitalia)', 3, 'NOTA', 'L''intervista nomina Trenitalia per il treno da trattenere e la Sala Operativa TPER per il coordinamento: verificare quale impresa serve la linea.');

insert into journey (codice, titolo, persona, scenario, fonte, nota_bozza, come_leggere) values
  ('studente', 'User journey · Studente pendolare', 'Studente pendolare (Stefano)', 'Bevilacqua → Monselice → Ferrara · mattina feriale', 'Racconto diretto di Stefano, 24 novembre 2026', 'BOZZA: le righe in arancione sono ipotesi mie, da confermare o correggere.', 'Testo scuro: viene dal tuo racconto del 24 novembre. Orari, tratte e azioni sono tuoi. ? Testo arancione: ipotesi mia. Nessuna fonte la conferma, serve che tu la corregga o la cancelli. I pallini colorati nella riga Attori rimandano ai sei cluster della actors map, stesso colore. Le barre delle emozioni sono inventate da me per dare una forma alla curva: sono il primo dato da sostituire. Struttura ripresa dal modello Journey Map che hai caricato. Righe aggiunte rispetto a quel modello: Attori coinvolti, per agganciare la journey alla actors map.'),
  ('capotreno', 'User journey · Capotreno', 'Capotreno', 'Bevilacqua → Monselice → Ferrara · cambio di 4 minuti a Monselice · stesso scenario della journey dello studente pendolare', 'Intervista al capostazione (Bologna–Padova) e journey dello studente pendolare del 24 novembre', 'BOZZA: le righe in arancione sono ipotesi, da confermare o correggere.', 'Testo scuro: viene dall''intervista al capostazione (Bologna–Padova) o dalla journey dello studente pendolare del 24 novembre. ? Testo arancione: ipotesi. Nessuna fonte la conferma, serve che il gruppo la corregga o la cancelli. Pallino pieno: attore con fonte (intervista o actors map). Pallino vuoto: attore dedotto, da verificare. Le barre delle emozioni sono stime per dare forma alla curva: sono il primo dato da sostituire. L''intervista non descrive mai il capotreno direttamente. Domande ed emozioni: tutta da verificare.'),
  ('capostazione', 'User journey · Capostazione', 'Capostazione', 'Stazione di cambio sulla linea Bologna–Padova · scenario: cambio di 4 minuti a Monselice (7.26–7.30) · basata sull''intervista al capostazione', 'Intervista al capostazione (risposte 1–13) e journey dello studente pendolare del 24 novembre', 'BOZZA: le righe in arancione sono ipotesi, da confermare o correggere.', 'Testo scuro: viene dall''intervista al capostazione (risposte 1–13) o dalla journey dello studente pendolare del 24 novembre. ? Testo arancione: ipotesi. Nessuna fonte la conferma, serve che il gruppo la corregga o la cancelli. Pallino pieno: attore nominato nell''intervista. Pallino vuoto: attore dedotto, da verificare. Domande ed emozioni sono ipotesi: l''intervista non le riporta. Le barre servono solo a dare forma alla curva e sono il primo dato da sostituire. L''intervista non nomina la stazione: Monselice viene dallo scenario condiviso con le altre journey. ? Da chiarire: l''intervista cita sia Trenitalia (impresa del treno da trattenere) sia la Sala Operativa TPER (coordinamento con RFI).');

insert into journey_bisogni (journey, ordine, testo, ipotesi) values
  ('studente', 1, 'Essere in dipartimento all''inizio della lezione', false),
  ('studente', 2, 'Non perdere la coincidenza di nove minuti a Monselice', false),
  ('studente', 3, 'Sapere in anticipo se il primo treno è in ritardo', true),
  ('studente', 4, 'Usare l''ora e mezza di viaggio per studiare o riposare', true),
  ('capotreno', 1, 'Conosce già il ritardo e potrebbe avvisare (il dato esiste)', false),
  ('capotreno', 2, 'Sapere chi ha una coincidenza da prendere', true),
  ('capotreno', 3, 'Poter chiedere l''attesa del treno 2 senza passare solo dal telefono', true),
  ('capostazione', 1, 'Rispettare l''orario dei treni viaggiatori', false),
  ('capostazione', 2, 'Venire incontro al viaggiatore, se i tempi lo permettono', false),
  ('capostazione', 3, 'Avere il nulla osta del Dirigente Centrale prima di trattenere un treno', false),
  ('capostazione', 4, 'Sapere in anticipo chi ha una coincidenza da prendere', true);

insert into journey_fasi (journey, numero, macro_fase, titolo, quando_dove, fase_critica, comportamento_inizio, comportamento_fine, canali, emozione_soddisfatto, emozione_incerto, emozione_frustrato) values
  ('studente', 1, 'Pre-servizio', 'Sveglia e partenza', '5.50 – 6.30', false, 'Si sveglia', 'Guarda il telefono', array['Digitale']::text[], 25, 78, 40),
  ('studente', 2, 'Pre-servizio', 'Auto e arrivo in stazione', '6.30 – 6.40 · Bevilacqua', false, 'Guida e parcheggia', 'Sale sul treno', array['Fisico','Digitale','Vocale']::text[], 15, 82, 62),
  ('studente', 3, 'Servizio', 'Primo treno', '6.44 – 7.21 · Bevilacqua → Monselice', false, 'Viaggia seduto', 'Controlla l''app', array['Fisico','Digitale','Vocale']::text[], 30, 85, 50),
  ('studente', 4, 'Servizio', 'Il cambio', '7.21 – 7.30 · Monselice · 9 minuti', true, 'Dal binario 6 all''1', 'Cerca il tabellone', array['Fisico','Visivo','Vocale']::text[], 20, 70, 80),
  ('studente', 5, 'Servizio', 'Secondo treno', '7.30 – 8.16 · Monselice → Ferrara', false, 'Viaggia seduto', 'Calcola l''arrivo', array['Fisico']::text[], 45, 25, 40),
  ('studente', 6, 'Post-servizio', 'Ultimo miglio', '8.16 – 8.35 ca. · Ferrara · bus alle 8.21', false, 'Esce dalla stazione', 'Prende il bus', array['Fisico','Digitale']::text[], 35, 45, 55),
  ('capotreno', 1, 'Pre-servizio', 'Presa servizio', 'prima delle 6.44 · Bevilacqua', false, 'Prende servizio', 'Controlla il treno', array['Fisico','Digitale']::text[], 55, 30, 5),
  ('capotreno', 2, 'Servizio', 'Viaggio sul treno 1', '6.44 – 7.26 · Bevilacqua → Monselice', false, 'Viaggia', 'Controlla l''orario', array['Fisico','Vocale']::text[], 65, 25, 5),
  ('capotreno', 3, 'Servizio', 'Ritardo e decisione', 'durante il viaggio · se il treno 1 è in ritardo', false, 'Telefona', 'Aspetta la risposta', array['Vocale','Digitale']::text[], 15, 55, 40),
  ('capotreno', 4, 'Servizio', 'Il cambio a Monselice', '7.26 – 7.30 · 4 minuti', true, 'Annuncia il binario', 'Risponde ai passeggeri', array['Fisico','Vocale']::text[], 5, 45, 75),
  ('capotreno', 5, 'Post-servizio', 'Dopo il cambio', 'se la coincidenza salta', false, 'Indirizza', 'Segnala l''evento', array['Fisico','Digitale']::text[], 20, 40, 45),
  ('capostazione', 1, 'Pre-servizio', 'Orario e fasce di punta', 'prima della mattina · stazione di cambio', false, 'Legge l''orario', 'Pesa le fasce di punta', array['Fisico','Vocale']::text[], 60, 30, 5),
  ('capostazione', 2, 'Servizio', 'Treno 1 in arrivo', '7.00 – 7.26 · gestione ordinaria', false, 'Assegna il binario', 'Segue l''arrivo', array['Fisico','Vocale']::text[], 65, 25, 5),
  ('capostazione', 3, 'Servizio', 'La telefonata del capotreno', 'poco prima delle 7.26 · se il treno 1 è in ritardo', false, 'Riceve la richiesta', 'Valuta la fattibilità', array['Vocale']::text[], 35, 50, 15),
  ('capostazione', 4, 'Servizio', 'Trattenere il treno?', '7.26 – 7.30 · 4 minuti', true, 'Chiama il Dirigente', 'Aspetta il benestare', array['Vocale','Fisico']::text[], 5, 50, 65),
  ('capostazione', 5, 'Post-servizio', 'Dopo il cambio', 'viaggiatori e coincidenza saltata', false, 'Parla ai viaggiatori', 'Indirizza all''attesa', array['Fisico','Vocale']::text[], 25, 40, 40);

insert into journey_elementi (journey, fase, riga, ordine, testo, ipotesi, attore_con_fonte) values
  ('studente', 1, 'azione', 1, 'Si sveglia alle 5.50', false, null),
  ('studente', 1, 'azione', 2, 'Riceve a un orario fisso la notifica dell''app: dice se la tratta è in orario', false, null),
  ('studente', 1, 'azione', 3, 'Controlla sull''app dove si trova il treno, due o tre stazioni prima della sua', false, null),
  ('studente', 1, 'azione', 4, 'Si prepara ed esce di casa', false, null),
  ('studente', 1, 'azione', 5, 'Ha un abbonamento trimestrale: non compra il biglietto ogni giorno', false, null),
  ('studente', 2, 'azione', 1, 'Guida 10 minuti fino a Bevilacqua', false, null),
  ('studente', 2, 'azione', 2, 'Parcheggia e raggiunge la banchina', false, null),
  ('studente', 2, 'azione', 3, 'Sull''app vede orario stimato ed effettivo di partenza e di arrivo: al parcheggio sa già quando passa il treno', false, null),
  ('studente', 2, 'azione', 4, 'Ricontrolla l''app sulla banchina, perché a Bevilacqua non c''è il tabellone', false, null),
  ('studente', 2, 'azione', 5, 'Sale sul regionale delle 6.44', false, null),
  ('studente', 3, 'azione', 1, 'Viaggia 37 minuti', false, null),
  ('studente', 3, 'azione', 2, 'Legge il ritardo sullo schermo di bordo', false, null),
  ('studente', 3, 'azione', 3, 'Spesso il treno recupera il ritardo, ma lo scopre solo arrivando a Monselice', false, null),
  ('studente', 3, 'azione', 4, 'Con un ritardo grande: a volte ferma il capotreno che passa, a volte lo sente chiedere lui chi deve fare il cambio, a volte sta zitto e spera', false, null),
  ('studente', 3, 'azione', 5, 'Usa il tempo per studiare, leggere o dormire', true, null),
  ('studente', 4, 'azione', 1, 'Scende a Monselice alle 7.21, di solito al binario 6', false, null),
  ('studente', 4, 'azione', 2, 'Il treno per Bologna parte dal binario 1: deve attraversare tutta la stazione', false, null),
  ('studente', 4, 'azione', 3, 'Raggiunge la banchina e sale entro le 7.30', false, null),
  ('studente', 4, 'azione', 4, 'Con un ritardo grande decide se correre o rinunciare', false, null),
  ('studente', 5, 'azione', 1, 'Viaggia 46 minuti fino a Ferrara', false, null),
  ('studente', 5, 'azione', 2, 'Qui è più tranquillo: si rassegna all''ora in cui arriverà', false, null),
  ('studente', 5, 'azione', 3, 'Anche il secondo treno ritarda spesso di due o tre minuti', false, null),
  ('studente', 5, 'azione', 4, 'Riprende quello che stava facendo sul primo treno', true, null),
  ('studente', 6, 'azione', 1, 'Esce dalla stazione di Ferrara', false, null),
  ('studente', 6, 'azione', 2, 'Prende il bus delle 8.21', false, null),
  ('studente', 6, 'azione', 3, 'Arriva al Dipartimento di Architettura', false, null),
  ('studente', 1, 'touchpoint', 1, 'Sveglia del telefono', false, null),
  ('studente', 1, 'touchpoint', 2, 'Notifica automatica sullo stato della tratta', false, null),
  ('studente', 1, 'touchpoint', 3, 'App di viaggio', false, null),
  ('studente', 2, 'touchpoint', 1, 'Auto e parcheggio', false, null),
  ('studente', 2, 'touchpoint', 2, 'Banchina di Bevilacqua, senza tabellone', false, null),
  ('studente', 2, 'touchpoint', 3, 'Annuncio sonoro di stazione', false, null),
  ('studente', 2, 'touchpoint', 4, 'App di viaggio', false, null),
  ('studente', 2, 'touchpoint', 5, 'Abbonamento trimestrale al treno', false, null),
  ('studente', 3, 'touchpoint', 1, 'Carrozza del regionale', false, null),
  ('studente', 3, 'touchpoint', 2, 'Schermi di bordo', false, null),
  ('studente', 3, 'touchpoint', 3, 'App di viaggio', false, null),
  ('studente', 3, 'touchpoint', 4, 'Capotreno del primo treno', false, null),
  ('studente', 3, 'touchpoint', 5, 'Annunci di bordo', true, null),
  ('studente', 4, 'touchpoint', 1, 'Sottopasso di Monselice, dal binario 6 al binario 1', false, null),
  ('studente', 4, 'touchpoint', 2, 'Tabellone di stazione', false, null),
  ('studente', 4, 'touchpoint', 3, 'Annunci sonori', false, null),
  ('studente', 5, 'touchpoint', 1, 'Carrozza del regionale', false, null),
  ('studente', 6, 'touchpoint', 1, 'Uscita della stazione di Ferrara', false, null),
  ('studente', 6, 'touchpoint', 2, 'Fermata e bus urbano', false, null),
  ('studente', 6, 'touchpoint', 3, 'Abbonamento mensile urbano', false, null),
  ('studente', 1, 'attore', 1, 'App di viaggio', false, true),
  ('studente', 2, 'attore', 1, 'Impresa ferroviaria', false, true),
  ('studente', 2, 'attore', 2, 'Stazione di partenza', false, true),
  ('studente', 3, 'attore', 1, 'Capotreno treno 1', false, true),
  ('studente', 3, 'attore', 2, 'Macchinisti', false, true),
  ('studente', 3, 'attore', 3, 'Tabelloni e annunci', false, true),
  ('studente', 4, 'attore', 1, 'Capostazione', false, true),
  ('studente', 4, 'attore', 2, 'Capotreno treno 2', false, true),
  ('studente', 4, 'attore', 3, 'Stazione di cambio', false, true),
  ('studente', 4, 'attore', 4, 'Tabelloni e annunci', false, true),
  ('studente', 4, 'attore', 5, 'Altri passeggeri', false, true),
  ('studente', 5, 'attore', 1, 'Capotreno treno 2', false, true),
  ('studente', 6, 'attore', 1, 'Trasporto locale (bus)', false, true),
  ('studente', 1, 'domanda', 1, '“Il treno è in orario?”', false, null),
  ('studente', 1, 'domanda', 2, '“Devo uscire prima?”', false, null),
  ('studente', 1, 'domanda', 3, '“Ce la farò a prendere il treno?”', false, null),
  ('studente', 2, 'domanda', 1, '“Faccio in tempo a prendere il 6.44?”', false, null),
  ('studente', 2, 'domanda', 2, '“Trovo parcheggio?”', false, null),
  ('studente', 2, 'domanda', 3, '“Quando arrivo in stazione il treno arriverà o si blocca in qualche stazione?”', false, null),
  ('studente', 3, 'domanda', 1, '“Stiamo recuperando o no?”', false, null),
  ('studente', 3, 'domanda', 2, '“Quanto ritardo abbiamo davvero?”', false, null),
  ('studente', 3, 'domanda', 3, '“Chiedo al capotreno o sto zitto?”', false, null),
  ('studente', 4, 'domanda', 1, '“Da che binario parte?”', false, null),
  ('studente', 4, 'domanda', 2, '“Ce la faccio ad arrivare dal 6 all''1?”', false, null),
  ('studente', 4, 'domanda', 3, '“Se lo perdo, quando passa il prossimo?”', false, null),
  ('studente', 5, 'domanda', 1, '“A che ora arriverò davvero?”', false, null),
  ('studente', 5, 'domanda', 2, '“Riuscirò a prendere l''autobus?”', false, null),
  ('studente', 6, 'domanda', 1, '“Il bus è già passato?”', false, null),
  ('studente', 6, 'domanda', 2, '“Conviene andare a piedi?”', false, null),
  ('studente', 1, 'criticita', 1, 'Il viaggiatore si è costruito da solo un sistema di allerta: notifica a orario fisso e controllo della posizione del treno', false, null),
  ('studente', 1, 'criticita', 2, 'La notifica dice se la tratta è in orario, non se la coincidenza di Monselice è a rischio', false, null),
  ('studente', 2, 'criticita', 1, 'A Bevilacqua non c''è un tabellone: solo un annuncio sonoro, quindi l''app resta l''unica fonte', false, null),
  ('studente', 2, 'criticita', 2, 'Se perde il 6.44 aspetta un''ora: arriva a destinazione un''ora dopo e tutta la giornata slitta', false, null),
  ('studente', 2, 'criticita', 3, 'La frustrazione sale qui, quando arriva in stazione e scopre che il ritardo è aumentato', false, null),
  ('studente', 3, 'criticita', 1, 'Il ritardo si vede sullo schermo, ma non si sa se verrà recuperato: la risposta arriva solo all''arrivo', false, null),
  ('studente', 3, 'criticita', 2, 'La richiesta di tenere la coincidenza nasce qui, a bordo, non al cambio', false, null),
  ('studente', 3, 'criticita', 3, 'Tre comportamenti davanti allo stesso problema: fermare il capotreno, rispondere se chiede lui, oppure tacere', false, null),
  ('studente', 3, 'criticita', 4, 'Quando il capotreno chiede chi deve fare il cambio la catena parte da sola, ma dipende dal singolo capotreno', false, null),
  ('studente', 4, 'criticita', 1, 'Nove minuti di margine, ma il binario di arrivo è il più lontano da quello della coincidenza: dal 6 all''1', false, null),
  ('studente', 4, 'criticita', 2, 'Il margine reale non è di nove minuti: è nove minuti meno il tempo di attraversare la stazione', false, null),
  ('studente', 4, 'criticita', 3, 'Chi assegna i binari è il capostazione, cioè la stessa figura che potrebbe trattenere il treno', false, null),
  ('studente', 4, 'criticita', 4, 'Se la coincidenza salta si aspetta un''ora: il treno per Bologna passa ogni ora, alle 27 o alle 30', false, null),
  ('studente', 5, 'criticita', 1, 'Bastano due o tre minuti di ritardo per fargli perdere l''autobus delle 8.21', false, null),
  ('studente', 5, 'criticita', 2, 'La tranquillità qui è rassegnazione: ha smesso di provare a recuperare', false, null),
  ('studente', 6, 'criticita', 1, 'Seconda coincidenza stretta: treno 8.16, bus 8.21, cinque minuti', false, null),
  ('studente', 6, 'criticita', 2, 'Due o tre minuti di ritardo del treno bastano a fargli perdere il bus', false, null),
  ('studente', 6, 'criticita', 3, 'Il bus successivo passa intorno alle 8.36: altri venti minuti di attesa', false, null),
  ('studente', 1, 'opportunita', 1, 'La notifica che riceve già potrebbe dire non solo “il treno è in orario”, ma “con questo ritardo la coincidenza di Monselice è a rischio”', false, null),
  ('studente', 2, 'opportunita', 1, 'L''orario stimato c''è già: quello che manca è quanto sia affidabile, perché il ritardo cambia fino a Monselice', false, null),
  ('studente', 3, 'opportunita', 1, 'Avviso a bordo quando il ritardo mette a rischio la coincidenza, prima dell''arrivo', false, null),
  ('studente', 3, 'opportunita', 2, 'Il dato esiste già: lo conoscono il capotreno e il Dirigente Centrale', false, null),
  ('studente', 3, 'opportunita', 3, 'Rendere sistematica la domanda che alcuni capotreni fanno già: “chi deve fare un cambio a Monselice?”', false, null),
  ('studente', 4, 'opportunita', 1, 'Assegnare al treno in arrivo un binario vicino a quello della coincidenza, quando si sa chi deve cambiare', false, null),
  ('studente', 4, 'opportunita', 2, 'Rendere automatica la richiesta di attesa, invece che su iniziativa del passeggero', false, null),
  ('studente', 4, 'opportunita', 3, 'Tabelloni di binario con i prossimi tre o quattro treni (proposta del capostazione)', false, null),
  ('studente', 4, 'opportunita', 4, 'Dire subito che cosa succede se la coincidenza salta: quando passa il prossimo treno e a che cosa si ha diritto', false, null),
  ('studente', 5, 'opportunita', 1, 'Dire già a bordo se il bus delle 8.21 è ancora raggiungibile, e qual è l''alternativa', false, null),
  ('studente', 6, 'opportunita', 1, 'Collegare l''orario del bus urbano all''arrivo reale del treno', false, null),
  ('capotreno', 1, 'azione', 1, 'Riceve il turno e controlla la composizione del treno', true, null),
  ('capotreno', 1, 'azione', 2, 'Controlla gli avvisi di circolazione sulla linea', true, null),
  ('capotreno', 1, 'azione', 3, 'Sale sul regionale a Bevilacqua', true, null),
  ('capotreno', 2, 'azione', 1, 'Viaggia 42 minuti fino a Monselice', false, null),
  ('capotreno', 2, 'azione', 2, 'Fa gli annunci a bordo', true, null),
  ('capotreno', 2, 'azione', 3, 'Controlla i biglietti e assiste i passeggeri', true, null),
  ('capotreno', 3, 'azione', 1, 'Il ritardo passa per telefono lungo la catena della coincidenza', false, null),
  ('capotreno', 3, 'azione', 2, 'Chiede alla sala operativa se il treno 2 può aspettare', true, null),
  ('capotreno', 3, 'azione', 3, 'Aspetta una risposta', true, null),
  ('capotreno', 4, 'azione', 1, 'Arriva a Monselice alle 7.26', false, null),
  ('capotreno', 4, 'azione', 2, 'Annuncia il binario del treno per Bologna', true, null),
  ('capotreno', 4, 'azione', 3, 'Risponde ai passeggeri che hanno fretta', true, null),
  ('capotreno', 5, 'azione', 1, 'Se la coincidenza salta non esiste un piano: si aspetta il treno dopo', false, null),
  ('capotreno', 5, 'azione', 2, 'Rimanda i passeggeri alla biglietteria', true, null),
  ('capotreno', 5, 'azione', 3, 'Segnala l''evento nel rapporto di servizio', true, null),
  ('capotreno', 1, 'touchpoint', 1, 'Foglio turno', true, null),
  ('capotreno', 1, 'touchpoint', 2, 'Palmare / tablet', true, null),
  ('capotreno', 2, 'touchpoint', 1, 'Carrozza del regionale', false, null),
  ('capotreno', 2, 'touchpoint', 2, 'Annunci di bordo', true, null),
  ('capotreno', 3, 'touchpoint', 1, 'Telefono di servizio', false, null),
  ('capotreno', 3, 'touchpoint', 2, 'Palmare / tablet', true, null),
  ('capotreno', 4, 'touchpoint', 1, 'Banchina e sottopasso di Monselice', false, null),
  ('capotreno', 4, 'touchpoint', 2, 'Annunci sonori', false, null),
  ('capotreno', 4, 'touchpoint', 3, 'Contatto diretto con i passeggeri', true, null),
  ('capotreno', 5, 'touchpoint', 1, 'Biglietteria', false, null),
  ('capotreno', 5, 'touchpoint', 2, 'Rapporto di servizio', true, null),
  ('capotreno', 1, 'attore', 1, 'Impresa ferroviaria', false, false),
  ('capotreno', 1, 'attore', 2, 'Sala operativa', false, true),
  ('capotreno', 2, 'attore', 1, 'Capotreno 1', false, false),
  ('capotreno', 2, 'attore', 2, 'Macchinisti', false, false),
  ('capotreno', 2, 'attore', 3, 'Altri passeggeri', false, false),
  ('capotreno', 3, 'attore', 1, 'Sala operativa', false, true),
  ('capotreno', 3, 'attore', 2, 'RFI', false, true),
  ('capotreno', 3, 'attore', 3, 'Capostazione', false, true),
  ('capotreno', 4, 'attore', 1, 'Capostazione', false, true),
  ('capotreno', 4, 'attore', 2, 'Capotreno 2', false, false),
  ('capotreno', 4, 'attore', 3, 'Stazione di cambio', false, false),
  ('capotreno', 4, 'attore', 4, 'Altri passeggeri', false, false),
  ('capotreno', 5, 'attore', 1, 'Biglietteria', false, true),
  ('capotreno', 5, 'attore', 2, 'Capostazione', false, true),
  ('capotreno', 1, 'domanda', 1, '“Ci sono ritardi sulla linea oggi?”', true, null),
  ('capotreno', 1, 'domanda', 2, '“Il palmare funziona?”', true, null),
  ('capotreno', 2, 'domanda', 1, '“Siamo in orario?”', true, null),
  ('capotreno', 2, 'domanda', 2, '“Chi ha una coincidenza a Monselice?”', true, null),
  ('capotreno', 3, 'domanda', 1, '“Il treno 2 ci aspetta?”', true, null),
  ('capotreno', 3, 'domanda', 2, '“Chi decide e quando risponde?”', true, null),
  ('capotreno', 4, 'domanda', 1, '“Posso trattenere i passeggeri o chiedere l''attesa?”', true, null),
  ('capotreno', 4, 'domanda', 2, '“Come spiego il binario senza gergo?”', true, null),
  ('capotreno', 5, 'domanda', 1, '“Come finisce per chi ha perso la coincidenza?”', true, null),
  ('capotreno', 5, 'domanda', 2, '“Il mio rapporto serve a qualcosa?”', true, null),
  ('capotreno', 1, 'criticita', 1, 'Le informazioni sulla linea arrivano frammentate', true, null),
  ('capotreno', 1, 'criticita', 2, 'Non è chiaro quali strumenti abbia davvero', true, null),
  ('capotreno', 2, 'criticita', 1, 'Il ritardo si accumula durante il viaggio e nessuno dice se mette a rischio la coincidenza', false, null),
  ('capotreno', 2, 'criticita', 2, 'Non sa chi ha una coincidenza da prendere', true, null),
  ('capotreno', 3, 'criticita', 1, 'Il coordinamento tra RFI e sala operativa non funziona', false, null),
  ('capotreno', 3, 'criticita', 2, 'La richiesta di attendere parte solo se il viaggiatore la fa al capotreno', false, null),
  ('capotreno', 4, 'criticita', 1, 'Quattro minuti di margine: qualsiasi ritardo fa saltare la coincidenza', false, null),
  ('capotreno', 4, 'criticita', 2, 'Gli annunci in gergo ferroviario non vengono capiti', false, null),
  ('capotreno', 4, 'criticita', 3, 'Il biglietto non garantisce la coincidenza', false, null),
  ('capotreno', 4, 'criticita', 4, 'Non è chiaro cosa può promettere al viaggiatore', true, null),
  ('capotreno', 5, 'criticita', 1, 'Il rimborso chiesto in biglietteria non viene accolto', false, null),
  ('capotreno', 5, 'criticita', 2, 'I bus sostitutivi sono previsti solo in caso di soppressione', false, null),
  ('capotreno', 5, 'criticita', 3, 'Nessun ritorno sul rapporto inviato', true, null),
  ('capotreno', 1, 'opportunita', 1, 'Briefing con le coincidenze più a rischio del giorno', true, null),
  ('capotreno', 2, 'opportunita', 1, 'Avviso a bordo quando il ritardo mette a rischio la coincidenza', false, null),
  ('capotreno', 2, 'opportunita', 2, 'Il dato esiste già: lo conosce il capotreno e il DCO', false, null),
  ('capotreno', 3, 'opportunita', 1, 'Rendere automatica la richiesta di attesa, invece che su iniziativa del passeggero', false, null),
  ('capotreno', 4, 'opportunita', 1, 'Tabelloni di binario con i prossimi tre o quattro treni', false, null),
  ('capotreno', 4, 'opportunita', 2, 'Frasi standard senza gergo per gli annunci', true, null),
  ('capotreno', 5, 'opportunita', 1, 'Dire subito cosa succede se la coincidenza salta: quando passa il prossimo treno e a cosa si ha diritto', false, null),
  ('capostazione', 1, 'azione', 1, 'Ha davanti l''orario: ogni treno ha un arrivo e una partenza', false, null),
  ('capostazione', 1, 'azione', 2, 'Sa che nelle fasce di punta i treni dei pendolari hanno più importanza', false, null),
  ('capostazione', 1, 'azione', 3, 'Controlla gli avvisi di circolazione', true, null),
  ('capostazione', 2, 'azione', 1, 'Gestisce la circolazione dei treni dentro la propria stazione', false, null),
  ('capostazione', 2, 'azione', 2, 'Può ricevere un treno su un binario senza dare spiegazioni al Dirigente Centrale', false, null),
  ('capostazione', 2, 'azione', 3, 'Il Dirigente Centrale gestisce i treni in linea dalla sede di Bologna', false, null),
  ('capostazione', 3, 'azione', 1, 'Il capotreno telefona: un passeggero in arrivo (es. da Ravenna) non deve perdere l''ultimo treno per Padova', false, null),
  ('capostazione', 3, 'azione', 2, 'Valuta se la cosa è fattibile', false, null),
  ('capostazione', 3, 'azione', 3, 'Se si parla di pochi minuti, cerca di venire incontro al viaggiatore', false, null),
  ('capostazione', 4, 'azione', 1, 'Se serve più tempo, spiega il problema al Dirigente Centrale a Bologna e chiede il benestare', false, null),
  ('capostazione', 4, 'azione', 2, 'Il Dirigente Centrale si interfaccia con il Responsabile dell''impresa ferroviaria (Trenitalia) e comunica il da farsi', false, null),
  ('capostazione', 4, 'azione', 3, 'Se il Dirigente Centrale ordina di trattenere, ha l''obbligo di ottemperare', false, null),
  ('capostazione', 4, 'azione', 4, 'Normalmente si cerca di agevolare il viaggiatore', false, null),
  ('capostazione', 5, 'azione', 1, 'Se il treno parte, i pendolari la prendono con filosofia', false, null),
  ('capostazione', 5, 'azione', 2, 'Chi non conosce il regolamento va in biglietteria a chiedere il rimborso, inutilmente', false, null),
  ('capostazione', 5, 'azione', 3, 'Con chi protesta cerca di andare incontro finché ci sono educazione e rispetto', false, null),
  ('capostazione', 5, 'azione', 4, 'Se un treno è soppresso, mette in piedi autobus sostitutivi', false, null),
  ('capostazione', 1, 'touchpoint', 1, 'Orario dei treni', false, null),
  ('capostazione', 1, 'touchpoint', 2, 'Telefono di servizio', true, null),
  ('capostazione', 2, 'touchpoint', 1, 'Binari della stazione', false, null),
  ('capostazione', 2, 'touchpoint', 2, 'Tabelloni sui binari (solo il prossimo treno)', false, null),
  ('capostazione', 2, 'touchpoint', 3, 'Altoparlanti', false, null),
  ('capostazione', 3, 'touchpoint', 1, 'Telefono di servizio', false, null),
  ('capostazione', 3, 'touchpoint', 2, 'Orario del treno in coincidenza', false, null),
  ('capostazione', 4, 'touchpoint', 1, 'Telefono con il Dirigente Centrale', false, null),
  ('capostazione', 4, 'touchpoint', 2, 'Nulla osta del Dirigente Centrale', false, null),
  ('capostazione', 4, 'touchpoint', 3, 'Annunci sonori in stazione', false, null),
  ('capostazione', 5, 'touchpoint', 1, 'Biglietteria', false, null),
  ('capostazione', 5, 'touchpoint', 2, 'Altoparlanti (oggi in italiano chiaro)', false, null),
  ('capostazione', 5, 'touchpoint', 3, 'Tabelloni sui binari', false, null),
  ('capostazione', 1, 'attore', 1, 'Capostazione', false, true),
  ('capostazione', 1, 'attore', 2, 'Dirigente Centrale (Bologna)', false, true),
  ('capostazione', 1, 'attore', 3, 'Pendolari', false, true),
  ('capostazione', 2, 'attore', 1, 'Capostazione', false, true),
  ('capostazione', 2, 'attore', 2, 'Dirigente Centrale (Bologna)', false, true),
  ('capostazione', 2, 'attore', 3, 'Pendolari', false, true),
  ('capostazione', 3, 'attore', 1, 'Capotreno', false, true),
  ('capostazione', 3, 'attore', 2, 'Capostazione', false, true),
  ('capostazione', 3, 'attore', 3, 'Viaggiatore con coincidenza', false, true),
  ('capostazione', 4, 'attore', 1, 'Dirigente Centrale (Bologna)', false, true),
  ('capostazione', 4, 'attore', 2, 'Resp. impresa ferroviaria (Trenitalia)', false, true),
  ('capostazione', 4, 'attore', 3, 'Sala Operativa TPER', false, true),
  ('capostazione', 4, 'attore', 4, 'Capostazione', false, true),
  ('capostazione', 5, 'attore', 1, 'Pendolari', false, true),
  ('capostazione', 5, 'attore', 2, 'Viaggiatori non informati', false, true),
  ('capostazione', 5, 'attore', 3, 'Biglietteria', false, true),
  ('capostazione', 5, 'attore', 4, 'Bus sostitutivi', false, true),
  ('capostazione', 1, 'domanda', 1, '“Il treno viaggiatori rispetta l''orario?”', true, null),
  ('capostazione', 1, 'domanda', 2, '“Quali treni oggi contano di più?”', true, null),
  ('capostazione', 2, 'domanda', 1, '“Il treno 1 arriva in orario?”', true, null),
  ('capostazione', 2, 'domanda', 2, '“Su quale binario lo ricevo?”', true, null),
  ('capostazione', 3, 'domanda', 1, '“Quanti minuti servono per tenere fermo il treno?”', true, null),
  ('capostazione', 3, 'domanda', 2, '“Decido io o devo chiamare Bologna?”', true, null),
  ('capostazione', 4, 'domanda', 1, '“Quanto posso trattenere senza danneggiare gli altri treni?”', true, null),
  ('capostazione', 4, 'domanda', 2, '“Arriverà il benestare?”', true, null),
  ('capostazione', 4, 'domanda', 3, '“Chi avvisa il capotreno del treno 2?”', true, null),
  ('capostazione', 5, 'domanda', 1, '“Quando passa il prossimo treno?”', true, null),
  ('capostazione', 5, 'domanda', 2, '“Posso avere il rimborso?”', true, null),
  ('capostazione', 1, 'criticita', 1, 'Le coincidenze e i comporti non sono più normati: il vecchio RCT li prevedeva, oggi non esistono', false, null),
  ('capostazione', 1, 'criticita', 2, 'Nessuna regola scritta a cui appoggiarsi quando arriva una richiesta', true, null),
  ('capostazione', 2, 'criticita', 1, 'Per i treni viaggiatori il rispetto dell''orario è fondamentale', false, null),
  ('capostazione', 2, 'criticita', 2, 'Possono capitare mille situazioni singolari fuori dall''orario', false, null),
  ('capostazione', 2, 'criticita', 3, 'Un ritardo del treno 1 non gli arriva in anticipo', true, null),
  ('capostazione', 3, 'criticita', 1, 'La richiesta arriva solo a telefono e solo se il capotreno la fa', false, null),
  ('capostazione', 3, 'criticita', 2, 'Se il tempo di attesa è maggiore, non può decidere da solo', false, null),
  ('capostazione', 3, 'criticita', 3, 'Non sa quanti passeggeri sono coinvolti', true, null),
  ('capostazione', 4, 'criticita', 1, 'Più di pochi minuti richiede la catena capostazione → Dirigente Centrale → impresa → capostazione', false, null),
  ('capostazione', 4, 'criticita', 2, 'RFI e Sala Operativa TPER viaggiano su binari paralleli: ci provano da anni con pessimi risultati', false, null),
  ('capostazione', 4, 'criticita', 3, 'Senza norma, tutto dipende dal benestare del momento', false, null),
  ('capostazione', 5, 'criticita', 1, 'Il rimborso chiesto in biglietteria non viene accolto', false, null),
  ('capostazione', 5, 'criticita', 2, 'Bus: tempi di attesa altissimi; con un treno all''ora conviene aspettare il successivo', false, null),
  ('capostazione', 5, 'criticita', 3, 'Un tempo gli annunci erano in gergo ferroviario e il 95% non li capiva (oggi migliorati)', false, null),
  ('capostazione', 1, 'opportunita', 1, 'Una regola scritta sulle coincidenze nelle fasce di punta', true, null),
  ('capostazione', 2, 'opportunita', 1, 'Avviso anticipato dal capotreno sui passeggeri con un cambio', true, null),
  ('capostazione', 3, 'opportunita', 1, 'Rendere automatica la richiesta di attesa, invece che su iniziativa del passeggero', false, null),
  ('capostazione', 3, 'opportunita', 2, 'Vedere quanti passeggeri hanno un cambio prima di decidere', true, null),
  ('capostazione', 4, 'opportunita', 1, 'Un canale unico condiviso tra capostazione, Dirigente Centrale e impresa', true, null),
  ('capostazione', 4, 'opportunita', 2, 'Un criterio scritto sui minuti di attesa accettabili', true, null),
  ('capostazione', 5, 'opportunita', 1, 'Tabelloni con i prossimi 3 o 4 treni sul binario, come in Germania: tranquillizzerebbe i viaggiatori (proposta del capostazione)', false, null),
  ('capostazione', 5, 'opportunita', 2, 'Dire subito cosa succede se la coincidenza salta e a cosa si ha diritto', true, null);

insert into mattina_segmenti (ordine, nome, orario, durata) values
  (1, 'Sveglia e partenza', '5.50 – 6.30', '40 min'),
  (2, 'Auto e stazione', '6.30 – 6.44', '14 min'),
  (3, 'Primo treno', '6.44 – 7.21', '37 min'),
  (4, 'Il cambio', '7.21 – 7.30', '9 min'),
  (5, 'Secondo treno', '7.30 – 8.16', '46 min'),
  (6, 'Attesa del bus', '8.16 – 8.21', '5 min'),
  (7, 'Bus urbano', '8.21 – 8.35', '14 min');

insert into punti_rottura (numero, titolo, margine, costo_se_salta, dettaglio_se_salta, qui_interveniamo) values
  (1, 'Perdi il treno delle 6.44', 'Nessun margine. Il treno passa e basta.', '+ 1 ora', 'Tutta la giornata slitta di un''ora.', false),
  (2, 'Perdi la coincidenza a Monselice', '9 minuti, meno il tempo per andare dal binario 6 al binario 1.', '+ 1 ora', 'Il treno per Bologna passa ogni ora, alle 27 o alle 30: il successivo è alle 8.27.', true),
  (3, 'Perdi il bus delle 8.21', '5 minuti. Bastano 2 o 3 minuti di ritardo del secondo treno.', '+ 15 minuti', 'Il bus successivo passa verso le 8.36.', false);

insert into chi_sa_cosa (ordine, momento, sa_viaggiatore, sa_servizio) values
  (1, '6.30 · al parcheggio', 'Orario stimato ed effettivo sull''app.', 'La posizione reale del treno e la previsione di arrivo a Monselice.'),
  (2, '6.44 – 7.21 · a bordo', 'Il ritardo di adesso, scritto sullo schermo.', 'Se quel ritardo verrà recuperato prima di Monselice.'),
  (3, '7.21 · a Monselice', 'Il binario, e se il treno è ancora fermo lì.', 'Da quale binario arriva e da quale riparte, e se conviene trattenerlo.'),
  (4, '8.16 · a Ferrara', 'Se il bus è già passato.', 'L''orario reale di arrivo rispetto al bus delle 8.21.');

insert into scoperte (numero, titolo, sottotitolo, cosa_succede, perche_conta, dove_si_interviene, frase_chiave, note) values
  (1, 'L''informazione arriva troppo tardi', 'Quello che il viaggiatore vede non è quello che gli serve.', 'Sullo schermo di bordo si legge il ritardo di adesso. Ma il treno spesso lo recupera, e il viaggiatore lo scopre solo quando arriva a Monselice.', 'Per 37 minuti decide usando un numero destinato a cambiare. Il dato che gli servirebbe — il ritardo previsto all''arrivo — esiste già: lo conoscono il capotreno e il Dirigente Centrale.', 'Mostrare a bordo la previsione all''arrivo, non il ritardo corrente.', 'Il numero che leggi a bordo non è il numero che deciderà la tua coincidenza.', 'Esempio nel grafico: a Bevilacqua 6.44 "ritardo 8 min" (qui guardi, qui decidi); a Monselice 7.21 "ritardo 2 min" (qui si vede se serviva).'),
  (2, 'La richiesta dipende dal caso', 'Davanti allo stesso ritardo succedono tre cose diverse.', 'A volte è il viaggiatore a fermare il capotreno. A volte è il capotreno a chiedere ad alta voce chi deve fare un cambio. A volte nessuno dice niente.', 'Il capostazione racconta che la catena parte dalla richiesta del passeggero. La journey mostra che a volte parte dal capotreno. Quindi la coincidenza non dipende dal bisogno: dipende da chi c''è quel giorno.', 'Rendere sistematica la domanda che alcuni capotreni già fanno.', 'La catena parte solo se qualcuno parla. Chi parla cambia ogni giorno.', 'Tre casi dopo "Vedi il ritardo a bordo": Fermi tu il capotreno → la catena parte; È il capotreno a chiedere → la catena parte; Non dici niente → la catena non parte.'),
  (3, 'I nove minuti non sono nove minuti', 'Il margine sulla carta non è il margine reale.', 'Il treno arriva al binario 6. Il treno per Bologna parte dal binario 1. In mezzo c''è tutta la stazione da attraversare.', 'Il margine utile è nove minuti meno l''attraversamento. E i binari li assegna il capostazione, la stessa figura che può decidere di trattenere il treno: due leve nelle stesse mani, usate separatamente.', 'Avvicinare i binari quando si sa che c''è un cambio, prima ancora di trattenere il treno.', 'Margine reale = 9 min − attraversamento.', 'Arrivo da Bevilacqua alle 7.21 al binario 6; treno per Bologna alle 7.30 dal binario 1 (binari 1–6). Il tempo di attraversamento non è ancora stato misurato: è il prossimo dato da raccogliere.');

insert into stato_avanzamento (stato, voce, documento) values
  ('fatto', 'Actors map del sistema, 40 attori e 46 flussi.', 'tre_scoperte'),
  ('fatto', 'Un''intervista a un capostazione.', 'tre_scoperte'),
  ('fatto', 'Una user journey completa del viaggiatore, con orari reali.', 'tre_scoperte'),
  ('in_verifica', 'La versione del capotreno: la stessa catena vista da bordo.', 'tre_scoperte'),
  ('in_verifica', 'Il tempo reale di attraversamento a Monselice.', 'tre_scoperte'),
  ('prossimo_passo', 'Progettare come le richieste di coincidenza arrivano al capotreno.', 'tre_scoperte');

insert into domande_aperte (documento, gruppo, domanda) values
  ('actors_map', 'Da chiedere a un capotreno', 'Come capisce che un passeggero ha una coincidenza a rischio: glielo chiedono o se ne accorge?'),
  ('actors_map', 'Da chiedere a un capotreno', 'Quanti glielo chiedono in una corsa tipo, e chi sono?'),
  ('actors_map', 'Da chiedere a un capotreno', 'Con quale strumento telefona e a chi, quando non conosce il capostazione della stazione di cambio?'),
  ('actors_map', 'Da chiedere a un capotreno', 'Cosa dice al passeggero mentre aspetta la risposta?'),
  ('actors_map', 'Da chiedere a un capotreno', 'Cosa succede quando la risposta è no?'),
  ('actors_map', 'Da chiedere a un capotreno', 'Quanto spesso non chiede nemmeno, e perché?'),
  ('actors_map', 'Rimaste aperte anche con il capostazione', 'Quali strumenti software usa davvero (nell''intervista compare solo il telefono)?'),
  ('actors_map', 'Rimaste aperte anche con il capostazione', 'Qual è il ritardo oltre il quale la coincidenza è persa?'),
  ('actors_map', 'Rimaste aperte anche con il capostazione', 'Cosa succede sull''ultima corsa della giornata?'),
  ('tre_scoperte', 'Prossimo passo: le domande da risolvere', 'Quando si dichiara: all''acquisto, alla salita, o solo quando il ritardo supera una soglia?'),
  ('tre_scoperte', 'Prossimo passo: le domande da risolvere', 'Chi dichiara: il viaggiatore di sua iniziativa, o il servizio che già conosce l''itinerario di un abbonato?'),
  ('tre_scoperte', 'Prossimo passo: le domande da risolvere', 'Con che canale: a voce, dall''app, dal posto a sedere?'),
  ('tre_scoperte', 'Prossimo passo: le domande da risolvere', 'Che cosa riceve il capotreno: quante persone, o quali coincidenze?'),
  ('tre_scoperte', 'Prossimo passo: le domande da risolvere', 'Che cosa torna indietro al viaggiatore: un sì, un no, o un “stiamo chiedendo”?'),
  ('dove_si_rompe', 'Che cosa manca (se il professore lo chiede)', 'La versione del capotreno.'),
  ('dove_si_rompe', 'Che cosa manca (se il professore lo chiede)', 'Il tempo reale di attraversamento a Monselice.'),
  ('schema_intervista_pdf', 'Da chiarire nello schema', 'Il Responsabile dell''impresa ferroviaria decide o dà solo un parere?'),
  ('schema_intervista_pdf', 'Da chiarire nello schema', 'Quale impresa serve la linea: Trenitalia (treno da trattenere) o TPER (sala operativa)?'),
  ('spiegazione', 'Decisioni per il gruppo sulla actors map', 'Tenere, verificare o togliere ciascuno dei dieci cerchi bianchi?'),
  ('spiegazione', 'Decisioni per il gruppo sulla actors map', 'Le due frecce anomale (RFI ↔ sala operativa; viaggiatore → biglietteria per il rimborso): lasciarle così, marcarle in modo diverso, oppure spostarle nel pannello laterale?'),
  ('spiegazione', 'Decisioni per il gruppo sulla actors map', 'Dimensione dei cerchi: dichiarare un criterio (frequenza di incontro, o capacità di far saltare la coincidenza) oppure uniformare tutti i cerchi?'),
  ('spiegazione', 'Decisioni per il gruppo sulla actors map', 'La mappa contiene solo soggetti? (Se sì escono la stazione come luogo e i fattori esterni.)'),
  ('spiegazione', 'Decisioni per il gruppo sulla actors map', 'Lo sciopero rientra nel perimetro del progetto?'),
  ('user_journey', 'Da confermare nella journey', 'Tutte le righe in arancione (ipotesi) delle tre journey vanno confermate, corrette o cancellate.'),
  ('user_journey', 'Da confermare nella journey', 'Le barre delle emozioni sono stime: sono il primo dato da sostituire con dati reali.');

insert into contenuti (documento, sezione, ordine, tipo, titolo, testo, riferimento, ipotesi) values
  ('actors_map', 'Intestazione', 1, 'nota', 'Titolo', 'Actors map. Esperienza del viaggiatore in un viaggio in treno con coincidenza, dall''acquisto del biglietto all''arrivo a destinazione.', null, false),
  ('actors_map', 'Intestazione', 2, 'nota', 'Versione', 'v2 – aggiornata con l''intervista a un capostazione (linea Bologna–Padova, novembre 2026).', null, false),
  ('actors_map', 'Intestazione', 3, 'nota', 'Centro della mappa', 'Esperienza del viaggiatore: viaggio in treno con coincidenza.', null, false),
  ('actors_map', 'Il punto di vista del capostazione', 1, 'nota', 'Fonte', 'Intervista ad Andrea, capostazione di Ferrara. È una testimonianza situata, non la descrizione ufficiale del sistema: va letta come una fonte, da confrontare con le altre.', null, false),
  ('actors_map', 'Il punto di vista del capostazione', 2, 'nota', 'Come funziona davvero la coincidenza', '1. Il viaggiatore chiede al capotreno di non perdere il treno successivo. 2. Il capotreno telefona al capostazione della stazione di cambio. 3. Se si tratta di pochi minuti, il capostazione decide da solo e trattiene il treno. 4. Se l''attesa è più lunga serve il benestare del Dirigente Centrale di Bologna. 5. Il Dirigente Centrale si interfaccia con il responsabile dell''impresa ferroviaria e comunica il da farsi.', null, false),
  ('actors_map', 'Il punto di vista del capostazione', 3, 'nota', 'Citazione', 'Normalmente si cerca di agevolare il viaggiatore.', null, false),
  ('actors_map', 'Punti critici', 1, 'punto_critico', 'La coincidenza non è un diritto', 'Il vecchio Regolamento Circolazione Treni normava coincidenze e comporti; da anni non sono più normati. Quello che resta è una prassi di cortesia.', null, false),
  ('actors_map', 'Punti critici', 2, 'punto_critico', 'Serve che qualcuno chieda', 'Se il viaggiatore non sa di poter chiedere, o non lo fa, la catena non parte nemmeno.', null, false),
  ('actors_map', 'Punti critici', 3, 'punto_critico', 'Il servizio dipende dalla relazione', 'Si va incontro al passeggero finché si vedono educazione e rispetto: la stessa situazione può avere esiti diversi.', null, false),
  ('actors_map', 'Punti critici', 4, 'punto_critico', 'La decisione passa dal telefono', 'Cinque passaggi e nessuno strumento digitale condiviso, per decidere su pochi minuti.', null, false),
  ('actors_map', 'Punti critici', 5, 'punto_critico', 'RFI e sala operativa dell''impresa non si parlano', 'Due organizzazioni che "viaggiano su binari paralleli", con tentativi di integrazione falliti da anni. È il punto più duro dell''intervista ed è anche quello su cui l''intervistato si ferma.', null, false),
  ('actors_map', 'Punti critici', 6, 'punto_critico', 'Il rimborso che non c''è', 'Chi non conosce le regole va in biglietteria a chiedere un rimborso che non otterrà.', null, false),
  ('actors_map', 'Punti critici', 7, 'punto_critico', 'Se la coincidenza salta non c''è un piano', 'I bus sostitutivi esistono solo per le soppressioni, e con cadenza oraria conviene comunque aspettare il treno dopo.', null, false),
  ('actors_map', 'Punti interessanti', 1, 'punto_interessante', 'Due livelli di potere distinti', 'Il capostazione comanda dentro la sua stazione e sceglie i binari senza dover spiegare nulla; il Dirigente Centrale comanda sulla linea e può ordinare di trattenere un treno.', null, false),
  ('actors_map', 'Punti interessanti', 2, 'punto_interessante', 'Una soglia implicita', '"Pochi minuti" separa la decisione locale da quella centrale, ma non è un numero scritto da nessuna parte.', null, false),
  ('actors_map', 'Punti interessanti', 3, 'punto_interessante', 'Le fasce pendolari pesano', 'Anche senza norma, in certe fasce orarie i treni pendolari hanno un''importanza maggiore.', null, false),
  ('actors_map', 'Punti interessanti', 4, 'punto_interessante', 'Il linguaggio come barriera, riconosciuta dall''interno', 'Gli annunci usavano un gergo che il 95% dei viaggiatori non capiva; oggi è in parte corretto.', null, false),
  ('actors_map', 'Punti interessanti', 5, 'punto_interessante', 'Pendolari e occasionali reagiscono in modo opposto', 'I primi "la prendono con filosofia", i secondi vanno allo sportello.', null, false),
  ('actors_map', 'Punti interessanti', 6, 'punto_interessante', 'Una proposta dal campo', 'Tabelloni di binario con i prossimi 3 o 4 treni, come in Germania: lavora sull''ansia, non sul ritardo.', null, false),
  ('actors_map', 'Da chiedere a un capotreno', 1, 'nota', null, 'La sua versione probabilmente conferma la catena, ma copre la parte che il capostazione non vede. (Le domande sono nella tabella domande_aperte.)', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 1, 'non_in_mappa', 'Premessa', 'Una actors map rappresenta soggetti e relazioni, non regole. Questi elementi restano qui a lato.', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 2, 'non_in_mappa', null, 'L''assenza di norma su coincidenze e comporti.', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 3, 'non_in_mappa', null, 'L''orario come primo vincolo di ogni decisione.', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 4, 'non_in_mappa', null, 'La soglia dei "pochi minuti".', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 5, 'non_in_mappa', null, 'La priorità delle fasce pendolari.', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 6, 'non_in_mappa', null, 'La gerarchia tra stazione e linea.', null, false),
  ('actors_map', 'Cosa non entra nella mappa', 7, 'non_in_mappa', 'Palmare', 'Il palmare del capotreno resta in mappa come ipotesi da verificare: nell''intervista non viene mai nominato, al suo posto compare il telefono.', null, false),
  ('actors_map', 'Legenda', 1, 'legenda', 'Cerchio colorato, bordo sottile', 'Attore presente nella lista di partenza.', null, false),
  ('actors_map', 'Legenda', 2, 'legenda', 'Cerchio bianco', 'Da verificare: ipotesi, o attore che l''intervista non conferma.', null, false),
  ('actors_map', 'Legenda', 3, 'legenda', 'Cerchio colorato, bordo spesso', 'Attore confermato o emerso dall''intervista.', null, false),
  ('actors_map', 'Legenda', 4, 'legenda', 'Dimensione dei cerchi', 'La dimensione del cerchio è un''ipotesi di peso nell''esperienza, da rivedere.', null, false),
  ('actors_map', 'Legenda', 5, 'legenda', 'Flussi', 'Flusso economico (verde), flusso di servizio (blu), flusso di persone (magenta), flusso di informazioni (tratteggiato).', null, false),
  ('actors_map', 'Legenda', 6, 'legenda', 'Frecce numerate', 'Le frecce numerate da 1 a 5 ricostruiscono la catena della coincidenza descritta nell''intervista.', null, false),
  ('actors_map', 'Legenda', 7, 'legenda', 'Conteggio', '40 attori e 46 flussi. Ogni freccia ha un verso e un nome completo nel pannello livelli del file Figma: i nomi delle singole frecce non sono scritti nel PDF. Nel database sono registrati i flussi descritti a parole nei file (tabella flussi) e le categorie di flussi inferiti (qui sotto).', null, false),
  ('spiegazione', 'Introduzione', 1, 'nota', null, 'Spiegazione della actors map. Come è stata costruita, che cosa è documentato e che cosa è ipotesi. Scritto per il gruppo: serve a decidere cosa tenere, cosa verificare e cosa togliere.', null, false),
  ('spiegazione', '1. Le tre fonti, e come si leggono dal bordo', 1, 'legenda', 'Cerchio colorato, bordo sottile', 'Viene dalla lista grezza del gruppo. Ho solo fuso i doppioni fra le due liste e riorganizzato tutto in sei cluster.', null, false),
  ('spiegazione', '1. Le tre fonti, e come si leggono dal bordo', 2, 'legenda', 'Cerchio bianco', 'Ipotesi. Nessuna fonte la conferma: l''ho aggiunta io per coprire i buchi del perimetro, oppure è un attore della lista che l''intervista non conferma.', null, false),
  ('spiegazione', '1. Le tre fonti, e come si leggono dal bordo', 3, 'legenda', 'Bordo spesso', 'Confermato o emerso dall''intervista al capostazione sulla linea Bologna–Padova. È l''unica parte della mappa con una fonte diretta.', null, false),
  ('spiegazione', '1. Le tre fonti, e come si leggono dal bordo', 4, 'legenda', 'Perché il bianco vuol dire "da verificare"', 'Il bianco raccoglie due casi diversi: le ipotesi che ho aggiunto io per coprire i buchi del perimetro, e gli attori che erano nella vostra lista ma che l''intervista non conferma — per ora solo il palmare del capotreno, mai nominato dal capostazione. In entrambi i casi la regola è la stessa: se non c''è una fonte, resta da verificare.', null, false),
  ('spiegazione', '2. I dieci cerchi bianchi, uno per uno', 1, 'nota', null, 'Per ciascuno: perché sta nella mappa e che cosa servirebbe per confermarlo o eliminarlo. Sono il primo punto su cui decidere, perché nessuno di questi ha una fonte. (Il dettaglio di ognuno è nella tabella attori, colonne perche_in_mappa e come_verificarlo.)', null, false),
  ('spiegazione', '2. I dieci cerchi bianchi, uno per uno', 2, 'nota', 'In sintesi', 'I tre più solidi sono gli altri passeggeri, la stazione come luogo e i comitati pendolari. I due più deboli sono i circuiti di pagamento e gli esercizi commerciali: se la mappa va alleggerita, si parte da lì.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 1, 'scelta_metodologica', 'Modello', 'Il modello è quello di Mercafir, che usa quattro flussi: economico, merce, persone, informazioni. Qui la merce non esiste, quindi l''ho sostituita con un flusso di servizio, cioè chi eroga qualcosa a chi. Ogni freccia ha un verso e un nome completo nel pannello livelli di Figma: selezionandola si legge che cosa rappresenta.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 2, 'scelta_metodologica', 'Che cosa viene dall''intervista', 'Sono le uniche frecce con una fonte diretta: la catena della coincidenza, frecce numerate da 1 a 5; il coordinamento fra RFI e sala operativa che non funziona; il rimborso chiesto in biglietteria e non accolto; i bus sostitutivi solo in caso di soppressione; gli annunci in gergo ferroviario; il biglietto che non garantisce la coincidenza.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 3, 'scelta_metodologica', 'Che cosa è inferenza mia', 'Ricavate dalle descrizioni della vostra lista e da conoscenza generica del sistema ferroviario. Plausibili, non verificate: tutti e undici i flussi economici (pedaggio, corrispettivi, incassi dei rivenditori, accrediti); i flussi di servizio di manutenzione e pulizie; i tre flussi di persone; i flussi istituzionali (ART, Regione, associazioni, sindacati, Comuni).', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 4, 'scelta_metodologica', 'Non disegnato: nessuna freccia tocca il centro', 'Il centro è l''esperienza del viaggiatore, non un attore: collegarci tutto avrebbe prodotto un sole, nascondendo le relazioni laterali, che sono il punto della mappa.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 5, 'scelta_metodologica', 'Non disegnato: viaggiatori come cluster', 'I viaggiatori sono collegati come cluster, non profilo per profilo. Unica eccezione la Sala Blu, che punta al viaggiatore con esigenze speciali. Senza questa scelta ogni freccia si moltiplicava per cinque.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 6, 'scelta_metodologica', 'Non disegnato: flussi interni ovvi', 'Niente flussi interni ovvi. Per esempio fra macchinista e capotreno dello stesso treno.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 7, 'scelta_metodologica', 'Non disegnato: spessore', 'Tutte le frecce hanno lo stesso spessore, anche se non pesano uguale: non c''è nessun criterio di frequenza o di importanza.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 8, 'scelta_metodologica', 'Non disegnato: tempo', 'Nessuna freccia rappresenta il tempo. Per la sequenza serve la user journey, non questa mappa.', null, false),
  ('spiegazione', '3. I flussi: che cosa ho valutato e che cosa no', 9, 'scelta_metodologica', 'Due frecce sono anomale, e il gruppo deve decidere', 'RFI ↔ sala operativa e viaggiatore → biglietteria per il rimborso dicono "qui non funziona", mentre tutte le altre dicono "qui passa qualcosa". È un''incoerenza voluta, per non perdere due risultati dell''intervista. Si può lasciarle così, marcarle in modo diverso, oppure spostarle nel pannello laterale e tenere la mappa pulita.', null, false),
  ('spiegazione', '4. Le tre scelte che non hanno nessuna fonte', 1, 'scelta_metodologica', 'Premessa', 'Non vengono né dalla vostra lista né dall''intervista: le ho decise io costruendo la mappa. Sono le prime cose da mettere in discussione.', null, false),
  ('spiegazione', '4. Le tre scelte che non hanno nessuna fonte', 2, 'scelta_metodologica', 'La dimensione dei cerchi', 'È un''ipotesi di peso nell''esperienza, fatta a occhio. O si dichiara un criterio — quanto spesso il viaggiatore incontra quell''attore, oppure quanto quell''attore può far saltare la coincidenza — o si uniformano tutti i cerchi.', null, false),
  ('spiegazione', '4. Le tre scelte che non hanno nessuna fonte', 3, 'scelta_metodologica', 'I sei cluster', 'Ho scartato due alternative. Front-stage e back-stage è una logica da blueprint e spezza gli attori che stanno in entrambi. La distanza dall''utente, cioè primari e secondari, moltiplicava i doppioni. Ho adottato il ruolo nel sistema, come nel riferimento Mercafir.', null, false),
  ('spiegazione', '4. Le tre scelte che non hanno nessuna fonte', 4, 'scelta_metodologica', '"Fattori esterni"', 'Meteo, guasti e scioperi sono l''unico elemento della mappa che non è un soggetto: sono eventi. Restano perché il gruppo voleva anche gli attori immateriali, ma sono il candidato più ovvio a uscire se si vuole una mappa rigorosa.', null, false),
  ('spiegazione', '5. Che cosa questa mappa non dice', 1, 'limite', 'Il tempo e la sequenza', 'Due attori collegati da una freccia possono non incontrarsi mai nello stesso momento.', null, false),
  ('spiegazione', '5. Che cosa questa mappa non dice', 2, 'limite', 'La frequenza', 'Una relazione che scatta ogni giorno e una che scatta una volta l''anno hanno la stessa freccia.', null, false),
  ('spiegazione', '5. Che cosa questa mappa non dice', 3, 'limite', 'La qualità della relazione', 'Tranne nelle due frecce anomale.', null, false),
  ('spiegazione', '5. Che cosa questa mappa non dice', 4, 'limite', 'Il punto di vista dei viaggiatori', 'Non c''è nessuna intervista a un passeggero: i cinque profili sono dedotti, non osservati.', null, false),
  ('spiegazione', '5. Che cosa questa mappa non dice', 5, 'limite', 'Il lato dell''impresa ferroviaria', 'L''unica testimonianza raccolta è di RFI, e descrive una linea sola.', null, false),
  ('spiegazione', '5. Che cosa questa mappa non dice', 6, 'limite', 'Crediti', 'Mappa e spiegazione costruite con Claude a partire dalla lista del gruppo, dal riferimento Mercafir e dall''intervista al capostazione. Versione 2, novembre 2026.', null, false),
  ('catena_decisionale', 'Introduzione', 1, 'nota', null, 'Chi decide se un treno aspetta chi sta arrivando in ritardo. Ricostruita dall''intervista ad Andrea, capostazione sulla linea Bologna–Padova. Le coincidenze non sono più normate dal Regolamento Circolazione Treni: quello che resta è questa prassi.', null, false),
  ('catena_decisionale', 'Introduzione', 2, 'nota', null, 'I pallini rossi segnano i punti critici, elencati in basso a destra.', null, false),
  ('catena_decisionale', 'Introduzione', 3, 'nota', 'Esito', 'Il treno aspetta, oppure non aspetta.', null, false),
  ('catena_decisionale', 'Introduzione', 4, 'nota', 'Nota sul Dirigente Centrale', 'Il Dirigente Centrale può ordinare di trattenere un treno fino al suo nulla osta: per il capostazione c''è obbligo di ottemperare.', null, false),
  ('catena_decisionale', 'Introduzione', 5, 'nota', 'E la risposta torna al viaggiatore?', 'Nell''intervista questo passaggio non c''è.', null, false),
  ('catena_decisionale', 'Le due leve del capostazione', 1, 'leva', null, 'Dentro la propria stazione può ricevere un treno su un binario senza dare spiegazioni al Dirigente Centrale.', null, false),
  ('catena_decisionale', 'Le due leve del capostazione', 2, 'leva', null, 'Può trattenere un treno di pochi minuti di sua iniziativa.', null, false),
  ('catena_decisionale', 'Le due leve del capostazione', 3, 'leva', null, 'Sono le due leve che decidono una coincidenza e stanno nelle stesse mani. Oggi vengono usate separatamente: il binario si assegna senza sapere chi deve cambiare.', null, false),
  ('catena_decisionale', 'Che cosa pesa sulla decisione', 1, 'vincolo', 'L''orario', 'Ogni treno ha un''ora di arrivo e una di partenza: è il primo vincolo.', null, false),
  ('catena_decisionale', 'Che cosa pesa sulla decisione', 2, 'vincolo', 'Nessuna norma', 'Il Regolamento Circolazione Treni normava coincidenze e comporti, da anni non più.', null, false),
  ('catena_decisionale', 'Che cosa pesa sulla decisione', 3, 'vincolo', 'Le fasce', 'Nelle fasce pendolari i treni hanno un''importanza maggiore.', null, false),
  ('catena_decisionale', 'Che cosa pesa sulla decisione', 4, 'vincolo', 'La relazione', 'Si va incontro al viaggiatore "fintantoché vediamo educazione e rispetto".', null, false),
  ('catena_decisionale', 'I quattro punti critici', 1, 'punto_critico', '1', 'La catena parte solo se qualcuno parla. Nessuna richiesta, nessuna catena.', null, false),
  ('catena_decisionale', 'I quattro punti critici', 2, 'punto_critico', '2', 'Tutto passa dal telefono, fra due persone che devono trovarsi in quel momento.', null, false),
  ('catena_decisionale', 'I quattro punti critici', 3, 'punto_critico', '3', 'Le due leve del capostazione stanno nelle stesse mani ma vengono usate separatamente.', null, false),
  ('catena_decisionale', 'I quattro punti critici', 4, 'punto_critico', '4', 'La risposta non torna indietro: nessun passaggio riporta l''esito a chi ha chiesto.', null, false),
  ('catena_decisionale', 'Citazioni', 1, 'citazione', 'Andrea, capostazione — linea Bologna–Padova, novembre 2026', 'Normalmente si cerca di agevolare il viaggiatore.', null, false),
  ('catena_decisionale', 'Citazioni', 2, 'citazione', 'Andrea, capostazione — linea Bologna–Padova, novembre 2026', 'Cerchiamo di andare loro incontro fintantoché vediamo educazione e rispetto.', null, false),
  ('catena_decisionale', 'Nota sulle fonti', 1, 'limite', null, 'Tutto lo schema viene da una sola intervista, dal lato del gestore dell''infrastruttura. La stessa catena vista dal capotreno e dal viaggiatore non è ancora stata verificata.', null, false),
  ('schema_intervista_pdf', 'Intestazione', 1, 'nota', 'Titolo', 'Schema decisionale: la coincidenza vista dal capostazione.', null, false),
  ('schema_intervista_pdf', 'Intestazione', 2, 'nota', 'Sottotitolo', 'Ricostruito dalle risposte dell''intervista (R1–R13, numerate come le domande). Ogni passaggio riporta la risposta da cui viene. In arancione ciò che l''intervista non dice.', null, false),
  ('schema_intervista_pdf', 'Intestazione', 3, 'nota', 'Come leggere lo schema', 'Rettangolo = azione · Rombo = decisione · Pillola = evento · Cerchio numerato = passo della catena (1 viaggiatore, 2 capotreno, 3 capostazione, 4 Dirigente Centrale, 5 impresa) · Bordo arancione tratteggiato = non documentato o da chiarire · Bordo rosso = criticità · Etichetta R# = risposta dell''intervista.', null, false),
  ('schema_intervista_pdf', 'Vincoli', 1, 'vincolo', 'Vincolo · R5', 'L''orario è il primo vincolo: per i treni viaggiatori il rispetto dell''orario è fondamentale.', 'R5', false),
  ('schema_intervista_pdf', 'Vincoli', 2, 'vincolo', 'Vincolo · R1 · R6', 'Nessuna norma: coincidenze e comporti non sono più normati (ex RCT). Esistono solo fasce pendolari con più importanza.', 'R1, R6', false),
  ('schema_intervista_pdf', 'Vincoli', 3, 'vincolo', 'Vincolo · R12', 'La relazione conta: si va incontro al viaggiatore finché ci sono educazione e rispetto.', 'R12', false),
  ('schema_intervista_pdf', 'Vincoli', 4, 'vincolo', 'Vincolo · R1', 'Si cerca normalmente di agevolare il viaggiatore.', 'R1', false),
  ('schema_intervista_pdf', 'Quando la coincidenza salta', 1, 'nota', null, 'Percorsi dopo la coincidenza persa: soppressione del treno, attesa del successivo, reazione del viaggiatore (R8, R10). (Nodi e frecce nelle tabelle schema_nodi e schema_archi.)', null, false),
  ('schema_intervista_pdf', 'Informazione e proposta dal campo', 1, 'punto_interessante', 'Annunci', 'Un tempo in gergo ferroviario, anche sui treni: il 95% dei viaggiatori non capiva. Da qualche anno si usa un italiano più corretto.', 'R9', false),
  ('schema_intervista_pdf', 'Informazione e proposta dal campo', 2, 'punto_interessante', 'Ansia scaricata sul personale', 'Accade spesso; si va incontro ai viaggiatori finché ci sono educazione e rispetto.', 'R12', false),
  ('schema_intervista_pdf', 'Informazione e proposta dal campo', 3, 'punto_interessante', 'Proposta', 'Tabelloni di binario con i prossimi 3 o 4 treni in arrivo, come in Germania, per tranquillizzare i viaggiatori.', 'R13', false),
  ('schema_intervista_pdf', 'Informazione e proposta dal campo', 4, 'punto_interessante', 'Comunicazione con la sala operativa', 'Migliorarla è un tentativo di anni con pessimi risultati.', 'R11', false),
  ('schema_intervista_pdf', 'Che cosa l''intervista non dice', 1, 'limite', 'Strumenti', 'Nelle risposte compare solo il telefono, nessun software.', 'D3', false),
  ('schema_intervista_pdf', 'Che cosa l''intervista non dice', 2, 'limite', 'Fattori del ''No''', 'Non cita binario unico, precedenze o fine turno; indica orario, Dirigente Centrale e ''mille situazioni singolari''.', 'D5', false),
  ('schema_intervista_pdf', 'Che cosa l''intervista non dice', 3, 'limite', 'Ultima corsa', 'Non confronta ultima corsa e punta; dice solo che le fasce pendolari pesano di più.', 'D6', false),
  ('schema_intervista_pdf', 'Che cosa l''intervista non dice', 4, 'limite', 'Ritardo massimo', 'Rimanda alla R1: nessun numero, solo ''pochi minuti'' contro ''tempo maggiore''.', 'D7', false),
  ('schema_intervista_pdf', 'Che cosa l''intervista non dice', 5, 'limite', 'Riprotezione', 'Solo bus per le soppressioni e attesa del treno dopo; nessun taxi o voucher.', 'D10', false),
  ('schema_intervista_pdf', 'Che cosa l''intervista non dice', 6, 'limite', 'Ritorno al viaggiatore', 'Nessun passaggio riporta l''esito a chi ha chiesto.', null, false),
  ('dove_si_rompe', 'Introduzione', 1, 'nota', null, 'La mattina di uno studente pendolare, minuto per minuto. Il viaggio si rompe in tre punti: due costano un''ora ciascuno, e ogni rottura dipende da un''informazione che il servizio possiede già e che al viaggiatore non arriva.', null, false),
  ('dove_si_rompe', 'Introduzione', 2, 'nota', null, 'I numeri segnano l''ordine in cui raccontare lo schema. La traccia è in fondo.', null, false),
  ('dove_si_rompe', 'Introduzione', 3, 'nota', 'Chi sa che cosa, e quando', 'La riga azzurra è informazione che esiste già dentro il servizio. Le frecce rosse sono il salto che il viaggiatore deve fare da solo, ogni mattina.', null, false),
  ('dove_si_rompe', 'Dove voglio intervenire', 1, 'nota', 'Nei 37 minuti del primo treno, e nella scelta dei binari a Monselice', 'In questa finestra il servizio sa già tutto quello che serve: il ritardo previsto all''arrivo, chi deve fare un cambio, da che binario far arrivare il treno. Il viaggiatore no. Il progetto lavora qui: non per far arrivare i treni in orario, ma per far arrivare al viaggiatore, mentre è ancora a bordo, l''informazione che il servizio possiede già.', null, false),
  ('dove_si_rompe', 'Dove voglio intervenire', 2, 'nota', 'Nel grafico', '37 minuti in cui la decisione è ancora possibile, fino all''assegnazione del binario.', null, false),
  ('dove_si_rompe', 'Che cosa dire al professore: cinque passaggi, nell''ordine dei numeri sullo schema', 1, 'traccia', '1', 'Partiamo da un viaggio vero, non da un caso di studio: due treni e un bus, due ore e tre quarti, tutte le mattine.', null, false),
  ('dove_si_rompe', 'Che cosa dire al professore: cinque passaggi, nell''ordine dei numeri sullo schema', 2, 'traccia', '2', 'Il viaggio si rompe in tre punti, e due costano un''ora ciascuno, perché i regionali sono cadenzati ogni ora.', null, false),
  ('dove_si_rompe', 'Che cosa dire al professore: cinque passaggi, nell''ordine dei numeri sullo schema', 3, 'traccia', '3', 'Il punto su cui lavoriamo è il secondo: nove minuti a Monselice, che però si consumano andando dal binario 6 al binario 1.', null, false),
  ('dove_si_rompe', 'Che cosa dire al professore: cinque passaggi, nell''ordine dei numeri sullo schema', 4, 'traccia', '4', 'La causa non è il ritardo in sé: è che l''informazione per decidere esiste già nel servizio e non arriva al viaggiatore.', null, false),
  ('dove_si_rompe', 'Che cosa dire al professore: cinque passaggi, nell''ordine dei numeri sullo schema', 5, 'traccia', '5', 'Quindi interveniamo nei 37 minuti a bordo, dove la decisione è ancora possibile: è lì che va raccolta la richiesta di chi deve fare la coincidenza.', null, false),
  ('dove_si_rompe', 'Che cosa dire al professore: cinque passaggi, nell''ordine dei numeri sullo schema', 6, 'traccia', 'Se chiede che cosa manca', 'La versione del capotreno e il tempo reale di attraversamento a Monselice.', null, false),
  ('tre_scoperte', 'Introduzione', 1, 'nota', null, 'Che cosa dice il viaggio reale di uno studente pendolare, e dove il servizio può intervenire. Ogni scoperta nasce dal confronto fra il racconto del viaggiatore e l''intervista al capostazione.', null, false),
  ('tre_scoperte', 'Il prossimo passo di progetto', 1, 'nota', 'Come arriva al capotreno la richiesta di chi deve fare una coincidenza', 'La scoperta 2 dice che la catena parte solo se qualcuno parla, e che chi parla cambia ogni giorno. Il passo successivo è progettare il modo in cui quelle richieste vengono raccolte.', null, false),
  ('tre_scoperte', 'Il prossimo passo di progetto', 2, 'nota', 'Quello che esiste già', 'Alcuni capotreni chiedono ad alta voce chi deve fare un cambio: il servizio esiste già, in forma orale e non sistematica.', null, false),
  ('tre_scoperte', 'Il prossimo passo di progetto', 3, 'nota', 'Quello che esiste già', 'Il canale a valle c''è ed è il telefono: capotreno → capostazione → Dirigente Centrale.', null, false),
  ('tre_scoperte', 'Il prossimo passo di progetto', 4, 'nota', 'Quello che esiste già', 'La decisione è già definita: pochi minuti li concede il capostazione, di più serve il benestare della linea.', null, false),
  ('tre_scoperte', 'Il prossimo passo di progetto', 5, 'nota', 'Attenzione', 'Raccogliere le richieste non basta se la risposta non torna indietro. Oggi il viaggiatore non sa mai come è andata finché non scende dal treno.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 1, 'nota', 'Team', 'Stefano, Benedetta, Beatrice, con 1–2 giorni a settimana per il progetto.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 2, 'nota', 'Obiettivo', 'Stefano vuole aiuto per coordinare i tre, con decision making e scelte di implementazione, spendendo il meno possibile per un risultato ottimale.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 3, 'nota', 'Lingua e stile', 'Italiano. Stefano non è tecnico: guida semplice passo passo.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 4, 'nota', 'Materiale', 'Cartella locale "DE CIA - COINCIDENZE" con i PDF della ricerca: actors map, user journey, schema dell''intervista, catena decisionale, "dove si rompe il viaggio", tre scoperte, spiegazione.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 5, 'nota', 'Repository', 'github.com/bertellibenedetta03/DE-CIA: MEMORIA_PROGETTO.md (PR 1) e sito statico index.html (PR 2) su main.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 6, 'nota', 'Sito', 'Pubblicato su Vercel (gratuito), progetto "decia" nel team "coincidenze-decia"; si aggiorna in automatico da main e crea un''anteprima per ogni PR. Per cambiare il sito si modificano index.html e style.css con una PR; il bot di Vercel commenta il link di anteprima.', null, false),
  ('memoria_progetto', 'Memoria del progetto', 7, 'nota', 'Regola di lavoro', 'Stefano è d''accordo che Claude unisca su main dopo il suo ok.', null, false);


-- =====================================================================
-- DE CIA · Coincidenze
-- 003 · Spazio per i file originali (Supabase Storage)
--
-- Crea un "bucket" privato chiamato "ricerca" dove caricare i file
-- originali (PDF, PNG, MEMORIA_PROGETTO.md). La colonna
-- documenti.percorso_storage dice dove si trova ciascun file.
-- Limite per file: 50 MB (il file più grande della ricerca è di 4,4 MB).
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit)
values ('ricerca', 'ricerca', false, 52428800)
on conflict (id) do nothing;

-- Vista comoda: quali documenti hanno già il file caricato nello Storage
create or replace view documenti_file as
select d.codice,
       d.titolo,
       d.nome_file,
       d.percorso_storage,
       (o.id is not null) as file_caricato
from documenti d
left join storage.objects o
  on o.bucket_id = 'ricerca' and 'ricerca/' || o.name = d.percorso_storage;

-- la vista rispetta i permessi di chi la interroga
alter view documenti_file set (security_invoker = true);

commit;
