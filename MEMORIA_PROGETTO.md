# Memoria del progetto DE CIA

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
- Schema tratto dall'intervista
- La catena decisionale
- Dove si rompe il viaggio
- Tre scoperte

## Strumenti

- **Sito:** pagina statica (index.html + style.css) pubblicata gratis su Vercel da main.
- **Database:** Supabase, piano gratuito, progetto "DE-CIA". Struttura, dati e guida nella cartella `supabase/` (vedi `supabase/GUIDA.md`); file originali nel bucket privato "ricerca".
- **Modulo contatti:** sezione "Racconta la tua coincidenza" sul sito. La funzione `api/contatto.js` (Vercel) salva ogni messaggio nella tabella `messaggi` di Supabase e manda un avviso via email con Resend (piano gratuito). Chiavi solo nelle Environment Variables di Vercel. Guida: `GUIDA_MODULO_CONTATTI.md`.
