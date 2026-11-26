# Modulo contatti con email (Resend): guida passo passo

Sul sito c'è ora la sezione **"Racconta la tua coincidenza"**: chi visita lascia un messaggio o una testimonianza. Ogni messaggio:

1. viene **salvato su Supabase**, nella tabella `messaggi`;
2. arriva **per email** al team, tramite **Resend**.

Tutto gratis: Resend gratuito permette 3.000 email al mese (100 al giorno), Supabase e Vercel restano sul piano gratuito.

Ci vogliono circa **15 minuti**, una volta sola. Le chiavi segrete le copi tu direttamente da un sito all'altro: **non mandarle a nessuno, nemmeno a Claude**.

---

## Passo 1 · Crea la tabella dei messaggi su Supabase

1. Vai su **supabase.com**, apri il progetto **DE-CIA**.
2. Nel menu a sinistra apri **SQL Editor** e clicca **New query**.
3. Apri il file [`supabase/migrations/004_messaggi.sql`](supabase/migrations/004_messaggi.sql) su GitHub, clicca **Copy raw file** e incollalo nell'editor.
4. Clicca **Run**. Deve comparire **Success. No rows returned**.

## Passo 2 · Copia due dati da Supabase (li incolli al passo 4)

1. Sempre su Supabase, clicca **Project Settings** (l'ingranaggio in basso a sinistra).
2. Apri **Data API**: copia il **Project URL** (tipo `https://abcd1234.supabase.co`). Questo è `SUPABASE_URL`.
3. Apri **API Keys**. Nella parte **Secret keys** clicca l'occhio o **Copy** sulla chiave che inizia con `sb_secret_`. Questa è `SUPABASE_SECRET_KEY`.
   *Se vedi solo la scheda "Legacy API keys", usa la chiave **service_role** (inizia con `eyJ`): funziona uguale.*

Questa chiave apre tutto il database: va solo su Vercel, mai nel codice o in chat.

## Passo 3 · Crea l'account Resend e la chiave

1. Vai su **resend.com** e clicca **Sign up**. Puoi entrare con **GitHub**. Il piano è **Free**.
2. **Importante:** l'email con cui ti registri è quella che riceverà gli avvisi (vedi il riquadro sotto).
3. Nel menu a sinistra apri **API Keys** e clicca **Create API Key**.
   - Name: `sito DE CIA`
   - Permission: **Sending access**
   - Clicca **Add** e **copia** la chiave (inizia con `re_`). Resend te la mostra una volta sola. Questa è `RESEND_API_KEY`.

> **Chi riceve le email, all'inizio.** Finché non colleghiamo un dominio, Resend spedisce dall'indirizzo di prova `onboarding@resend.dev` e **può mandare email solo all'indirizzo del tuo account Resend**. Per far arrivare gli avvisi anche a Benedetta e Beatrice, gratis, la cosa più semplice è un **inoltro automatico** dalla tua casella:
> in Gmail, *Impostazioni → Inoltro e POP/IMAP → Aggiungi un indirizzo di inoltro*, poi un filtro con oggetto `[DE CIA]` → *Inoltra a* Benedetta (e un secondo filtro per Beatrice).
> Più avanti, se comprate un dominio (circa 10 € l'anno), lo colleghiamo a Resend e le email partono direttamente a tutti e tre.

## Passo 4 · Metti le chiavi su Vercel

1. Vai su **vercel.com**, apri il progetto **decia** → **Settings** → **Environment Variables**.
2. Aggiungi queste 4 variabili, una alla volta (**Key** a sinistra, **Value** a destra, ambienti: lascia tutti spuntati), poi **Save**:

| Key | Value |
|---|---|
| `SUPABASE_URL` | il Project URL del passo 2 |
| `SUPABASE_SECRET_KEY` | la chiave `sb_secret_…` del passo 2 |
| `RESEND_API_KEY` | la chiave `re_…` del passo 3 |
| `EMAIL_TEAM` | l'email del tuo account Resend |

3. Le variabili valgono dalla pubblicazione successiva. Vai su **Deployments**, sull'ultimo clicca i tre puntini **⋯** → **Redeploy** → **Redeploy**.

## Passo 5 · Prova

1. Apri il sito, vai in fondo alla sezione **Racconta la tua coincidenza**.
2. Scrivi un messaggio di prova, spunta il consenso e clicca **Invia**. Deve comparire *"Grazie! Il tuo messaggio è arrivato."*
3. Controlla:
   - la tua **email** (guarda anche nello spam la prima volta): oggetto che inizia con `[DE CIA]`;
   - su **Supabase → Table Editor → messaggi**: c'è la riga, con `email_inviata` = true.

Se rispondi all'email, la risposta va direttamente a chi ha scritto (se ha lasciato il suo indirizzo).

---

## Se qualcosa non va

| Cosa vedi | Cosa vuol dire |
|---|---|
| *"Non siamo riusciti a salvare il messaggio"* | Supabase non risponde: controlla `SUPABASE_URL` e `SUPABASE_SECRET_KEY` su Vercel, e che il passo 1 sia stato fatto. Poi **Redeploy**. |
| Il messaggio è su Supabase ma l'email non arriva (`email_inviata` = false) | Controlla `RESEND_API_KEY` ed `EMAIL_TEAM` (deve essere l'email del tuo account Resend). Su resend.com → **Emails** vedi se ha provato a spedire. |
| Errore 404 sul modulo | Il sito non ha ancora la nuova versione: aspetta qualche minuto o fai **Redeploy**. |

Per i dettagli tecnici: Vercel → progetto → **Logs** mostra le righe *"Email non inviata"* o *"Salvataggio fallito"* con il motivo. Copia il messaggio e mandalo a Claude (senza chiavi).

## Antispam

Il modulo ha due protezioni invisibili, senza captcha: un campo nascosto che solo i robot compilano e un controllo sul tempo (chi invia in meno di 3 secondi viene ignorato). Se un giorno arrivasse molto spam, si può aggiungere Cloudflare Turnstile, anche quello gratuito.
