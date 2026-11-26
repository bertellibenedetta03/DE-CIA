# Database Supabase di DE CIA: guida passo passo

Questa cartella contiene il database della ricerca: **tutto** quello che c'è nei file della cartella "DE CIA - COINCIDENZE" e nella memoria del progetto. Costa zero (piano gratuito di Supabase).

## Che cosa c'è dentro

| Tabella | Che cosa contiene |
|---|---|
| `progetto_info`, `team` | Nome, obiettivi, team, tempo disponibile, sito, regole di lavoro (dalla memoria del progetto) |
| `documenti` | I 10 file originali, con il **testo integrale** di ognuno e dove trovarli nello Storage |
| `fonti`, `riferimenti_intervista` | Le fonti (intervista, racconto del 24 novembre…) e le risposte R1–R13 / domande D dell'intervista |
| `cluster_attori`, `attori` | I 6 cluster e i 40 attori della actors map, con lo stato (lista, confermato, da verificare) e, per i 10 cerchi bianchi, perché ci sono e come verificarli |
| `tipi_flusso`, `flussi` | I 4 tipi di flusso e i flussi descritti nei file (catena 1–5, frecce anomale…) |
| `catena_passaggi` | I 5 passaggi della catena decisionale |
| `schema_nodi`, `schema_archi`, `chi_decide_cosa` | Lo schema dell'intervista (che nel file è solo un'immagine, trascritto a mano) |
| `journey`, `journey_bisogni`, `journey_fasi`, `journey_elementi` | Le tre user journey: studente, capotreno, capostazione, riga per riga, con le ipotesi segnate |
| `mattina_segmenti`, `punti_rottura`, `chi_sa_cosa` | "Dove si rompe il viaggio" |
| `scoperte`, `stato_avanzamento` | Le tre scoperte e a che punto siamo |
| `domande_aperte` | Tutte le domande ancora senza risposta |
| `contenuti` | Tutti gli altri testi, sezione per sezione (punti critici, punti interessanti, legende, citazioni, note di metodo, traccia per il professore) |

I file originali (PDF e PNG) vanno nello **Storage**, in uno spazio privato chiamato `ricerca`.

Nessun dato è pubblico: si vede solo entrando nel pannello Supabase.

---

## Passo 1 · Crea il progetto (se non l'hai già fatto)

1. Vai su **supabase.com** e accedi (anche con GitHub).
2. Clicca **New project**.
3. Nome: `DE-CIA`. Regione: una europea (per esempio **Central EU (Frankfurt)**). Piano: **Free**.
4. Scegli una password del database e **salvala in un posto sicuro** (non serve mandarla a nessuno, nemmeno a Claude).
5. Aspetta un paio di minuti che il progetto sia pronto.

## Passo 2 · Crea le tabelle e inserisci tutti i dati

1. Nel menu a sinistra apri **SQL Editor**.
2. Clicca **New query** (o il **+**).
3. Apri il file [`TUTTO_IN_UNO.sql`](TUTTO_IN_UNO.sql) su GitHub, clicca il pulsante **Copy raw file** (icona dei due fogli in alto a destra del file), e incolla tutto nell'editor.
4. Clicca **Run** (in basso a destra).
5. Deve comparire **Success. No rows returned**. Se Supabase chiede conferma per un'operazione "potenzialmente distruttiva", conferma: il file crea solo cose nuove.

Fallo **una volta sola**. Se compare un errore, non viene salvato niente: copia il messaggio di errore e mandalo a Claude.

## Passo 3 · Carica i file originali

1. Nel menu a sinistra apri **Storage**.
2. Vedrai lo spazio **ricerca** (creato al passo 2). Aprilo.
3. Trascina dentro **tutti i 10 file** della cartella `supabase-da-caricare` (è nei file del progetto). Hanno già i nomi giusti, senza caratteri strani, così Supabase li accetta.

| File da caricare | Documento originale |
|---|---|
| `actors-map.pdf` | Actors map v2 – Viaggio in treno con coincidenza.pdf |
| `dove-si-rompe.pdf` | Dove si rompe il viaggio.pdf |
| `catena-decisionale.pdf` | La catena decisionale.pdf |
| `schema-intervista-pdf.pdf` | Schema tratto dall'intervista.pdf |
| `schema-intervista-png.png` | Schema tratto dall'intervista.png |
| `spiegazione.pdf` | Spiegazione di Claude.pdf |
| `tre-scoperte.pdf` | Tre scoperte.pdf |
| `user-journey.pdf` | User Journey.pdf |
| `memoria-progetto.md` | MEMORIA_PROGETTO.md |
| `anteprima-sito.png` | Anteprima della pagina web |

## Passo 4 · Controlla che ci sia tutto

Nel **SQL Editor**, in una nuova query, incolla ed esegui:

```sql
select codice, titolo, file_caricato from documenti_file order by codice;
```

Tutte le righe devono avere `file_caricato = true`.

Per vedere i dati, apri **Table Editor** nel menu a sinistra e scegli una tabella (per esempio `attori` o `journey_elementi`).

---

## Come si aggiunge qualcosa in futuro

Per esempio quando arriva l'intervista al capotreno: scrivi a Claude che cosa è cambiato e Claude prepara un nuovo file `migrations/004_….sql` da eseguire allo stesso modo. Così il repository resta la copia di sicurezza di tutto il database.

## Note

- **Costo:** il piano gratuito include 500 MB di database e 1 GB di file. Qui usiamo meno di 1 MB di dati e circa 21 MB di file.
- **Pausa automatica:** sul piano gratuito, un progetto non usato per 7 giorni viene messo in pausa. Basta riattivarlo dal pannello (pulsante **Restore**): i dati non si perdono.
- **Che cosa è trascritto a mano:** lo schema dell'intervista e le journey di capotreno e capostazione nei PDF sono immagini; sono stati trascritti leggendo le immagini. I valori delle emozioni (0–100) sono letti dalla lunghezza delle barre, che nei file stessi sono stime da sostituire.
- **Che cosa non è nei PDF:** i nomi delle 46 singole frecce della actors map stanno solo nel pannello livelli del file Figma. Nel database ci sono i flussi descritti a parole nei file; se volete anche tutte le 46 frecce, esportatele da Figma e Claude le aggiunge.
