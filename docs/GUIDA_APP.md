# Guida: accendere e provare l'app Coincidenze

L'app sta all'indirizzo del sito con **/app/** alla fine (per esempio `https://il-vostro-sito.vercel.app/app/`).
Il sito e il modulo contatti restano come sono.

Servono due cose fatte una volta sola da Stefano: le tabelle su Supabase (parte A) e le chiavi per le notifiche su Vercel (parte B). Senza la parte B l'app funziona lo stesso, solo senza notifiche.

## Parte A. Le tabelle su Supabase (5 minuti)

1. Apri **supabase.com** e accedi.
2. Clicca sul progetto **DE-CIA**.
3. Nel menu a sinistra clicca **SQL Editor**.
4. In alto clicca **+** (oppure **New query**): si apre un foglio vuoto.
5. In un'altra scheda apri questo indirizzo: https://github.com/bertellibenedetta03/DE-CIA/blob/main/supabase/migrations/005_app.sql
6. Su quella pagina, in alto a destra del testo, clicca l'icona **Copy raw file** (due quadratini sovrapposti).
7. Torna su Supabase e incolla nel foglio vuoto (tasto destro → **Incolla**).
8. Clicca il bottone verde **Run** in basso a destra.
9. Deve comparire **Success. No rows returned**. Se compare un avviso con un bottone **Run this query**, cliccalo: è normale.
10. Controllo: nel menu a sinistra clicca **Table Editor**. Devi vedere tre tabelle nuove: **app_viaggio**, **app_richieste**, **app_push**.

Si può rifare più volte: non cancella niente.

## Parte B. Le chiavi per le notifiche (10 minuti)

1. Apri l'indirizzo del sito con **/app/chiavi.html** alla fine.
2. Clicca **Crea le chiavi**. Compaiono due righe lunghe di lettere e numeri. Lascia aperta questa pagina.
3. In un'altra scheda apri **vercel.com** e clicca sul progetto del sito.
4. In alto clicca **Settings**, poi a sinistra **Environment Variables**.
5. Nella casella **Key** scrivi esattamente: `VAPID_PUBLIC_KEY`
6. Torna alla pagina delle chiavi, clicca **Copia** sotto la riga 1, torna su Vercel e incolla nella casella **Value**.
7. Lascia spuntati tutti gli ambienti (**Production**, **Preview**, **Development**) e clicca **Save**.
8. Ripeti con la seconda chiave: nella casella **Key** scrivi `VAPID_PRIVATE_KEY`, poi clicca **Copia** sotto la riga 2 e incolla in **Value**, poi **Save**.
9. In alto clicca **Deployments**. Sulla prima riga clicca i tre puntini **⋯** a destra, poi **Redeploy**, poi di nuovo **Redeploy**.
10. Aspetta un paio di minuti che la riga diventi **Ready**.
11. Chiudi la pagina delle chiavi. La chiave privata non va mai incollata in chat o in un'email.

## Parte C. Provare l'app con due telefoni

Serve un telefono che fa il viaggiatore e uno che fa il capotreno, più un computer per la Regia.

1. **Viaggiatore.** Sul telefono apri l'indirizzo del sito con **/app/** alla fine e scegli **Viaggiatore**.
2. Mettila sulla schermata Home:
    - **iPhone (Safari):** tasto **Condividi** (quadrato con la freccia in su) → **Aggiungi alla schermata Home** → **Aggiungi**. Poi chiudi Safari e apri l'app dall'icona **Coincidenze**. Serve iOS 16.4 o più recente.
    - **Android (Chrome):** tre puntini in alto a destra → **Aggiungi a schermata Home** (o **Installa app**).
3. Nell'app scorri in basso e premi **Attiva le notifiche**, poi **Consenti**. Arriva subito una notifica di prova.
4. **Capotreno.** Sul secondo telefono fai gli stessi passi 1-3, ma scegli **Capotreno**.
5. **Regia.** Sul computer apri l'indirizzo del sito con **/app/#regia** alla fine.
6. Nella Regia premi **6 min**. Al viaggiatore arriva la notifica "Il 6.44 ha 6 minuti di ritardo previsto a Monselice" e il semaforo diventa rosso.
7. Sul telefono del viaggiatore premi **Avvisa il capotreno**, scrivi il nome se vuoi, poi **Sì, avvisa il capotreno**.
8. Al capotreno arriva la notifica. Apre l'app: vede "1 persona deve cambiare". Il viaggiatore vede "Il capotreno ha letto la tua richiesta".
9. Il capotreno preme **Sto chiedendo al capostazione**, poi **Confermata** oppure **Rifiutata**. Al viaggiatore arriva la notifica; se è rifiutata vede subito le alternative.
10. Prova anche il caso "nessuna risposta": invia una richiesta e lascia il capotreno fermo per 3 minuti. Al viaggiatore compare l'avviso e le alternative.
11. Alla fine, nella Regia, premi **Ricomincia la prova da capo**.

## Cosa cambiare a mano

- **Orari, carrozza consigliata, alternative, turni del capotreno:** file `app/dati.js`. Gli orari dei treni e le alternative sono veri (orario ufficiale Trenitalia, dati aperti). Le righe con `DA VERIFICARE` (binari, carrozza) e i turni del capotreno sono ancora ipotesi.
- **Dal 13 dicembre 2026** cambia l'orario: il treno per Bologna parte da Monselice alle 7.29 e il cambio scende a 8 minuti. L'app lo fa da sola.
- **Minuti per andare dal binario 6 al binario 1** (oggi 4, ipotesi) e **minuti prima dell'avviso "nessuna risposta"** (oggi 3): si cambiano dalla Regia, senza toccare il codice.

## Se qualcosa non va

| Cosa vedi | Cosa vuol dire | Cosa fare |
| --- | --- | --- |
| "Connessione non riuscita: A2 …" | Mancano le tabelle | Rifai la parte A |
| "Connessione non riuscita: A1 …" | Mancano le chiavi Supabase su Vercel | Controlla che ci siano ancora `SUPABASE_URL` e `SUPABASE_SECRET_KEY` |
| Nella Regia: "Notifiche: non ancora configurate" | Mancano le chiavi VAPID | Rifai la parte B, compreso il **Redeploy** |
| Su iPhone non c'è il bottone "Attiva le notifiche" | L'app è aperta da Safari, non dall'icona | Rifai il passo 2 della parte C |
| Le notifiche non arrivano più | Il telefono le ha bloccate | Impostazioni del telefono → Notifiche → Coincidenze → attiva |

## Limiti del prototipo (voluti)

- Un solo viaggio, dati scritti a mano, ritardi decisi dalla Regia.
- Nessun accesso con password: chiunque abbia il link può scegliere qualsiasi ruolo, anche la Regia. Va bene per i test, non per un uso pubblico.
- Costo: 0 €. Le notifiche delle app installate dal sito sono gratuite.
