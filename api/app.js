// DE CIA · Funzione del prototipo dell'app Coincidenze (Vercel)
//
// Una sola funzione per tutta l'app. L'azione si sceglie con ?azione=...
//
//   GET  ?azione=stato&vid=...   stato del viaggio, richieste attive, la mia richiesta
//   POST ?azione=richiesta       il viaggiatore avvisa il capotreno
//   POST ?azione=annulla         il viaggiatore annulla la sua richiesta
//   POST ?azione=rispondi        il capotreno risponde a tutte le richieste del cambio
//   POST ?azione=regia           la Regia cambia il ritardo o azzera la prova
//   POST ?azione=push-iscrivi    un telefono attiva le notifiche
//   POST ?azione=push-prova      manda una notifica di prova a questo telefono
//
// Variabili d'ambiente su Vercel:
//   SUPABASE_URL, SUPABASE_SECRET_KEY   già presenti (servono anche al modulo contatti)
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY per le notifiche (si generano da /app/chiavi.html)
// Senza le chiavi VAPID l'app funziona lo stesso, solo senza notifiche.

const VIAGGIO = 'bevilacqua-monselice-ferrara';
const CAMBIO_MIN = 9; // Monselice: arrivo 7.21, partenza 7.30
const ATTIVI = ['inviata', 'vista', 'stiamo_chiedendo', 'nessuna_risposta'];
const RISPOSTE = {
  // stato scelto dal capotreno → da quali stati si può passare
  vista: ['inviata'],
  stiamo_chiedendo: ['inviata', 'vista', 'nessuna_risposta'],
  confermata: ATTIVI,
  rifiutata: ATTIVI,
  non_serve_piu: ATTIVI,
};
const TESTI_PUSH = {
  vista: ['Il capotreno ha letto la tua richiesta', 'Ti aggiorniamo appena sa qualcosa.'],
  stiamo_chiedendo: ['Il capotreno sta chiedendo a Monselice', 'Sta parlando con il capostazione.'],
  confermata: ['Il treno per Ferrara ti aspetta', 'Scendi a Monselice e vai al binario 1.'],
  rifiutata: ['Il treno per Ferrara non può aspettare', 'Apri l\'app: ti mostriamo le alternative.'],
  non_serve_piu: ['Arrivi in tempo', 'Il treno ha recuperato: nessuna attesa necessaria.'],
  nessuna_risposta: ['Ancora nessuna risposta', 'Ti abbiamo preparato le alternative, per sicurezza.'],
};

let webpush = null;
try {
  webpush = require('web-push');
} catch (e) {
  webpush = null;
}

// ---------- Supabase ----------

function urlSupabase() {
  return (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '').replace(/\/rest\/v1$/, '');
}

async function sb(percorso, { method = 'GET', body, prefer } = {}) {
  const url = urlSupabase();
  const chiave = (process.env.SUPABASE_SECRET_KEY || '').trim();
  if (!url || !chiave) throw new Error('A1 · manca SUPABASE_URL o SUPABASE_SECRET_KEY su Vercel');
  const headers = { apikey: chiave, 'Content-Type': 'application/json' };
  if (chiave.startsWith('eyJ')) headers.Authorization = `Bearer ${chiave}`;
  if (prefer) headers.Prefer = prefer;
  const r = await fetch(`${url}/rest/v1/${percorso}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const testo = await r.text();
  if (!r.ok) {
    if (/PGRST205|42P01|does not exist|Could not find the table/i.test(testo)) {
      throw new Error('A2 · mancano le tabelle dell\'app: eseguire supabase/migrations/005_app.sql');
    }
    throw new Error(`A9 · Supabase ${r.status}: ${testo.slice(0, 200)}`);
  }
  return testo ? JSON.parse(testo) : null;
}

const enc = encodeURIComponent;
const lista = (arr) => `(${arr.join(',')})`;

async function leggiViaggio() {
  let [v] = await sb(`app_viaggio?id=eq.${VIAGGIO}&select=*`);
  if (!v) {
    [v] = await sb('app_viaggio', { method: 'POST', body: { id: VIAGGIO }, prefer: 'return=representation' });
  }
  return v;
}

// ---------- Notifiche ----------

function soggettoVapid() {
  if (process.env.VAPID_SUBJECT) return process.env.VAPID_SUBJECT.trim();
  const dominio = process.env.VERCEL_PROJECT_PRODUCTION_URL || process.env.VERCEL_URL;
  return dominio ? `https://${dominio}` : 'mailto:noreply@example.com';
}

function pushPronto() {
  return Boolean(webpush && process.env.VAPID_PUBLIC_KEY && process.env.VAPID_PRIVATE_KEY);
}

async function mandaPush(filtro, titolo, testo, link) {
  if (!pushPronto()) return 0;
  webpush.setVapidDetails(
    soggettoVapid(),
    process.env.VAPID_PUBLIC_KEY.trim(),
    process.env.VAPID_PRIVATE_KEY.trim()
  );
  const iscritti = await sb(`app_push?${filtro}&select=*`);
  const payload = JSON.stringify({ titolo, testo, link: link || '/app/' });
  let inviate = 0;
  await Promise.all(
    iscritti.map(async (s) => {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          payload,
          { TTL: 600, urgency: 'high' }
        );
        inviate++;
      } catch (e) {
        // Telefono che ha tolto il permesso o disinstallato l'app: lo togliamo
        if (e.statusCode === 404 || e.statusCode === 410) {
          await sb(`app_push?endpoint=eq.${enc(s.endpoint)}`, { method: 'DELETE' }).catch(() => {});
        } else {
          console.error('push', e.statusCode, e.body || e.message);
        }
      }
    })
  );
  return inviate;
}

function pushAiViaggiatori(vids, stato) {
  const unici = [...new Set(vids)].filter(validoVid);
  if (!unici.length || !TESTI_PUSH[stato]) return Promise.resolve(0);
  const [titolo, testo] = TESTI_PUSH[stato];
  return mandaPush(
    `ruolo=eq.viaggiatore&viaggiatore_id=in.${lista(unici.map(enc))}`,
    titolo,
    testo,
    '/app/#viaggio'
  );
}

// ---------- Utilità ----------

function validoVid(v) {
  return typeof v === 'string' && /^[A-Za-z0-9-]{8,64}$/.test(v);
}

function intero(v, min, max) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < min || n > max) return null;
  return n;
}

function margine(v) {
  return CAMBIO_MIN - v.minuti_attraversamento - v.ritardo_min;
}

// Le richieste rimaste senza risposta oltre il limite diventano "nessuna_risposta"
async function controllaTimeout(v) {
  const limite = new Date(Date.now() - v.minuti_timeout * 60000).toISOString();
  const scadute = await sb(
    `app_richieste?viaggio_id=eq.${VIAGGIO}&stato=in.(inviata,vista)&aggiornata_il=lt.${enc(limite)}`,
    {
      method: 'PATCH',
      body: { stato: 'nessuna_risposta', aggiornata_il: new Date().toISOString() },
      prefer: 'return=representation',
    }
  );
  if (scadute && scadute.length) {
    await pushAiViaggiatori(scadute.map((r) => r.viaggiatore_id), 'nessuna_risposta');
  }
}

// ---------- Azioni ----------

async function stato(req) {
  const vid = req.query.vid;
  let v = await leggiViaggio();
  await controllaTimeout(v);
  const richieste = await sb(
    `app_richieste?viaggio_id=eq.${VIAGGIO}&stato=in.${lista(ATTIVI)}&select=id,nome,stato,creata_il,aggiornata_il&order=creata_il.asc`
  );
  let mia = null;
  if (validoVid(vid)) {
    [mia] = await sb(
      `app_richieste?viaggiatore_id=eq.${enc(vid)}&viaggio_id=eq.${VIAGGIO}&stato=neq.annullata&select=id,stato,creata_il,aggiornata_il&order=creata_il.desc&limit=1`
    );
  }
  return {
    ok: true,
    ora: new Date().toISOString(),
    viaggio: {
      ritardo_min: v.ritardo_min,
      minuti_attraversamento: v.minuti_attraversamento,
      minuti_timeout: v.minuti_timeout,
      cambio_min: CAMBIO_MIN,
      margine_reale: margine(v),
      aggiornato_il: v.aggiornato_il,
    },
    richieste,
    mia: mia || null,
    notifiche: { pronte: pushPronto(), chiave: (process.env.VAPID_PUBLIC_KEY || '').trim() || null },
  };
}

async function nuovaRichiesta(b) {
  if (!validoVid(b.vid)) throw new Error('V1 · identificativo non valido');
  const nome = typeof b.nome === 'string' ? b.nome.trim().slice(0, 60) : '';
  const [esistente] = await sb(
    `app_richieste?viaggiatore_id=eq.${enc(b.vid)}&viaggio_id=eq.${VIAGGIO}&stato=in.${lista(ATTIVI)}&select=*&limit=1`
  );
  if (esistente) return { ok: true, richiesta: esistente };
  const [r] = await sb('app_richieste', {
    method: 'POST',
    body: { viaggio_id: VIAGGIO, viaggiatore_id: b.vid, nome: nome || null },
    prefer: 'return=representation',
  });
  const attive = await sb(`app_richieste?viaggio_id=eq.${VIAGGIO}&stato=in.${lista(ATTIVI)}&select=id`);
  await mandaPush(
    'ruolo=eq.capotreno',
    'Nuova richiesta di coincidenza',
    `Monselice, treno per Ferrara 7.30: ${attive.length} ${attive.length === 1 ? 'persona' : 'persone'}.`,
    '/app/#capotreno'
  );
  return { ok: true, richiesta: r };
}

async function annulla(b) {
  if (!validoVid(b.vid)) throw new Error('V1 · identificativo non valido');
  await sb(`app_richieste?viaggiatore_id=eq.${enc(b.vid)}&viaggio_id=eq.${VIAGGIO}`, {
    method: 'PATCH',
    body: { stato: 'annullata', aggiornata_il: new Date().toISOString() },
  });
  return { ok: true };
}

async function rispondi(b) {
  const da = RISPOSTE[b.stato];
  if (!da) throw new Error('V2 · risposta non valida');
  const cambiate = await sb(`app_richieste?viaggio_id=eq.${VIAGGIO}&stato=in.${lista(da)}`, {
    method: 'PATCH',
    body: { stato: b.stato, aggiornata_il: new Date().toISOString() },
    prefer: 'return=representation',
  });
  await pushAiViaggiatori(cambiate.map((r) => r.viaggiatore_id), b.stato);
  return { ok: true, cambiate: cambiate.length };
}

async function regia(b) {
  if (b.azzera) {
    await sb(`app_richieste?viaggio_id=eq.${VIAGGIO}`, { method: 'DELETE' });
    await sb(`app_viaggio?id=eq.${VIAGGIO}`, {
      method: 'PATCH',
      body: { ritardo_min: 0, aggiornato_il: new Date().toISOString() },
    });
    return { ok: true, azzerata: true };
  }
  const prima = await leggiViaggio();
  const modifiche = {};
  const r = intero(b.ritardo_min, 0, 180);
  const a = intero(b.minuti_attraversamento, 0, 30);
  const t = intero(b.minuti_timeout, 1, 60);
  if (r !== null) modifiche.ritardo_min = r;
  if (a !== null) modifiche.minuti_attraversamento = a;
  if (t !== null) modifiche.minuti_timeout = t;
  if (!Object.keys(modifiche).length) throw new Error('V3 · nessun valore valido');
  modifiche.aggiornato_il = new Date().toISOString();
  const [dopo] = await sb(`app_viaggio?id=eq.${VIAGGIO}`, {
    method: 'PATCH',
    body: modifiche,
    prefer: 'return=representation',
  });

  let inviate = 0;
  if (r !== null && r !== prima.ritardo_min) {
    const m = margine(dopo);
    const titolo = r === 0 ? 'Il 6.44 è in orario' : `Il 6.44 ha ${r} minuti di ritardo previsto a Monselice`;
    const testo =
      m >= 3 ? 'Il cambio è tranquillo.' : m >= 0 ? `Cambio stretto: ti restano ${m} minuti.` : 'Cambio a rischio. Apri l\'app per avvisare il capotreno.';
    inviate = await mandaPush('ruolo=eq.viaggiatore', titolo, testo, '/app/#viaggio');
  }
  return { ok: true, viaggio: dopo, notifiche_inviate: inviate };
}

async function pushIscrivi(b) {
  const s = b.subscription || {};
  const keys = s.keys || {};
  if (typeof s.endpoint !== 'string' || !/^https:\/\//.test(s.endpoint) || s.endpoint.length > 1000) {
    throw new Error('V4 · iscrizione non valida');
  }
  if (typeof keys.p256dh !== 'string' || typeof keys.auth !== 'string') throw new Error('V4 · iscrizione non valida');
  const ruolo = b.ruolo === 'capotreno' ? 'capotreno' : 'viaggiatore';
  await sb('app_push?on_conflict=endpoint', {
    method: 'POST',
    body: {
      endpoint: s.endpoint,
      p256dh: keys.p256dh.slice(0, 200),
      auth: keys.auth.slice(0, 100),
      ruolo,
      viaggiatore_id: validoVid(b.vid) ? b.vid : null,
    },
    prefer: 'resolution=merge-duplicates',
  });
  return { ok: true };
}

async function pushProva(b) {
  if (typeof b.endpoint !== 'string') throw new Error('V4 · iscrizione non valida');
  const n = await mandaPush(
    `endpoint=eq.${enc(b.endpoint)}`,
    'Notifiche attive',
    'Da ora ti avvisiamo se il tuo treno ritarda o se il capotreno risponde.',
    '/app/'
  );
  return { ok: true, inviate: n };
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  const azione = req.query.azione;
  try {
    if (req.method === 'GET' && azione === 'stato') return res.status(200).json(await stato(req));
    if (req.method !== 'POST') return res.status(405).json({ ok: false, errore: 'Metodo non permesso' });
    const b = req.body && typeof req.body === 'object' ? req.body : {};
    const azioni = {
      richiesta: nuovaRichiesta,
      annulla,
      rispondi,
      regia,
      'push-iscrivi': pushIscrivi,
      'push-prova': pushProva,
    };
    if (!azioni[azione]) return res.status(404).json({ ok: false, errore: 'Azione sconosciuta' });
    return res.status(200).json(await azioni[azione](b));
  } catch (e) {
    console.error('app', azione, e.message);
    const codice = (e.message.match(/^([AV]\d)/) || [])[1] || 'A9';
    const status = codice.startsWith('V') ? 400 : 500;
    return res.status(status).json({ ok: false, errore: e.message.split(':')[0], codice });
  }
};

