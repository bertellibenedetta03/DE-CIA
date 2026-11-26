// DE CIA · Prototipo dell'app Coincidenze
// Tre schermate: viaggiatore, capotreno, regia. Il ruolo si sceglie all'inizio.
(function () {
  'use strict';

  const D = window.DATI;
  const API = '/api/app';
  const OGNI_MS = 4000;
  const schermo = document.getElementById('schermo');
  const erroreEl = document.getElementById('errore');
  const ruoloEl = document.getElementById('ruolo-attuale');

  const NOMI_RUOLO = { viaggiatore: 'Viaggiatore', capotreno: 'Capotreno', regia: 'Regia' };

  // ---------- Memoria del telefono (con riserva se è bloccata) ----------
  const memoria = {};
  function leggi(k) {
    try { return localStorage.getItem(k); } catch (e) { return memoria[k] || null; }
  }
  function scrivi(k, v) {
    memoria[k] = v;
    try { localStorage.setItem(k, v); } catch (e) { /* va bene lo stesso */ }
  }
  let vid = leggi('coinc_vid');
  if (!vid) {
    vid = (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2)).replace(/[^A-Za-z0-9-]/g, '');
    scrivi('coinc_vid', vid);
  }

  // ---------- Stato ----------
  let stato = null;
  let ultimaFirma = '';
  let foglioAperto = false;
  let inVolo = false;
  let segnaVistaInCorso = false;

  // ---------- Utilità ----------
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  function piuMinuti(hhmm, min) {
    const [h, m] = hhmm.split(':').map(Number);
    const t = h * 60 + m + min;
    return `${Math.floor(t / 60) % 24}.${String(t % 60).padStart(2, '0')}`;
  }
  const ora = (hhmm) => hhmm.replace(/^0/, '').replace(':', '.');
  const orario = (iso) => new Date(iso).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' }).replace(':', '.');
  function colore(m) { return m >= 3 ? 'verde' : m >= 0 ? 'giallo' : 'rosso'; }
  function mostraErrore(t) {
    if (!t) { erroreEl.hidden = true; return; }
    erroreEl.textContent = t;
    erroreEl.hidden = false;
  }

  async function chiama(azione, corpo) {
    const opz = corpo
      ? { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(corpo) }
      : {};
    const url = `${API}?azione=${azione}${corpo ? '' : `&vid=${encodeURIComponent(vid)}`}`;
    const r = await fetch(url, opz);
    let j = {};
    try { j = await r.json(); } catch (e) { /* risposta vuota */ }
    if (!r.ok || !j.ok) throw new Error(j.errore || `Errore ${r.status}`);
    return j;
  }

  async function aggiorna(forza) {
    if (inVolo) return;
    inVolo = true;
    try {
      stato = await chiama('stato');
      mostraErrore('');
      const firma = JSON.stringify([stato.viaggio, stato.richieste, stato.mia, stato.notifiche]);
      if (forza || firma !== ultimaFirma) {
        ultimaFirma = firma;
        if (disegna() === false) ultimaFirma = '';
      }
      if (rotta() === 'capotreno') segnaVista();
    } catch (e) {
      mostraErrore(`Connessione non riuscita: ${e.message}. Riprovo da solo.`);
      if (!stato) disegna();
    } finally {
      inVolo = false;
    }
  }

  // ---------- Rotte ----------
  function rotta() {
    const h = location.hash.replace('#', '');
    return ['viaggio', 'capotreno', 'regia', 'benvenuto'].includes(h) ? h : '';
  }
  function vai(r) {
    if (location.hash !== `#${r}`) location.hash = r;
    else disegna();
  }
  window.addEventListener('hashchange', () => { ultimaFirma = ''; disegna(); aggiorna(true); });

  function disegna() {
    if (foglioAperto) return false;
    // Non ridisegnare mentre si scrive in un campo
    if (document.activeElement && ['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) return false;
    let r = rotta();
    if (!r) {
      const salvato = leggi('coinc_ruolo');
      r = salvato === 'viaggiatore' ? 'viaggio' : salvato === 'capotreno' ? 'capotreno' : 'benvenuto';
      history.replaceState(null, '', `#${r}`);
    }
    const ruolo = r === 'viaggio' ? 'viaggiatore' : r === 'benvenuto' ? '' : r;
    ruoloEl.textContent = ruolo ? NOMI_RUOLO[ruolo] : '';
    if (r === 'benvenuto') return schermoBenvenuto();
    if (!stato) { schermo.innerHTML = '<p class="muto">Carico il viaggio…</p>'; return; }
    if (r === 'viaggio') return schermoViaggiatore();
    if (r === 'capotreno') return schermoCapotreno();
    if (r === 'regia') return schermoRegia();
  }

  // ---------- 1. Benvenuto ----------
  function schermoBenvenuto() {
    schermo.innerHTML = `
      <h1>Non perdere la coincidenza</h1>
      <p class="muto">Prototipo DE CIA, sul viaggio di prova ${esc(D.viaggio.titolo)}. Scegli chi sei.</p>
      <div class="scelta-ruolo">
        <button data-ruolo="viaggiatore">Viaggiatore<small>Vedi il margine del cambio e avvisi il capotreno</small></button>
        <button data-ruolo="capotreno">Capotreno<small>Vedi chi deve cambiare e rispondi</small></button>
        <button data-ruolo="regia">Regia<small>Solo per noi del gruppo: fai partire i ritardi</small></button>
      </div>
      <div class="card band" id="box-installa"></div>`;
    schermo.querySelectorAll('[data-ruolo]').forEach((b) =>
      b.addEventListener('click', () => {
        const ruolo = b.dataset.ruolo;
        if (ruolo !== 'regia') {
          scrivi('coinc_ruolo', ruolo);
          aggiornaIscrizione(ruolo);
        }
        vai(ruolo === 'viaggiatore' ? 'viaggio' : ruolo);
      })
    );
    const box = document.getElementById('box-installa');
    if (eStandalone()) {
      box.innerHTML = '<p class="piccolo" style="margin:0">App aperta dalla schermata Home.</p>';
    } else if (eIOS()) {
      box.innerHTML = `<h2>Mettila sulla schermata Home</h2>
        <p class="muto" style="margin:0">Su iPhone le notifiche funzionano solo così: tocca il tasto <b>Condividi</b> (il quadrato con la freccia in su), poi <b>Aggiungi alla schermata Home</b>, poi <b>Aggiungi</b>. Riapri l'app dall'icona.</p>`;
    } else {
      box.innerHTML = `<h2>Mettila sulla schermata Home</h2>
        <p class="muto" style="margin:0">Su Android: tocca i tre puntini in alto a destra di Chrome, poi <b>Aggiungi a schermata Home</b> (o <b>Installa app</b>).</p>`;
    }
  }

  // ---------- 4-7. Viaggiatore ----------
  function schermoViaggiatore() {
    const v = stato.viaggio;
    const [t1, t2] = D.viaggio.treni;
    const m = v.margine_reale;
    const c = colore(m);
    const mia = stato.mia;
    const attiva = mia && ['inviata', 'vista', 'stiamo_chiedendo', 'nessuna_risposta'].includes(mia.stato);
    const frase = {
      verde: 'Ce la fai con calma',
      giallo: 'Cambio stretto',
      rosso: 'Rischi di perdere il treno',
    }[c];

    let html = `
      <h1>Il mio viaggio</h1>
      <div class="semaforo ${c}" role="status">
        <span class="luce" aria-hidden="true"></span>
        <div>
          <div class="numero">${m >= 0 ? m : 0} min</div>
          <div><b>${frase}</b>${m < 0 ? `: ti ${m === -1 ? 'manca 1 minuto' : `mancano ${-m} minuti`}` : ''}</div>
        </div>
      </div>
      <p class="conto">Margine reale a ${esc(D.viaggio.cambio)}: ${v.cambio_min} minuti sulla carta, meno ${v.minuti_attraversamento} per andare dal binario ${esc(t1.binario_arrivo)} al binario ${esc(t2.binario_partenza)}${v.ritardo_min ? `, meno ${v.ritardo_min} di ritardo previsto` : ''}.</p>`;

    html += richiestaHtml(mia, c);

    html += `
      <div class="card">
        <ul class="tratta">
          <li><span class="ora">${ora(t1.partenza)}</span><span>${esc(t1.da)}<br><span class="piccolo">${esc(t1.nome)}</span></span></li>
          <li><span class="ora">${v.ritardo_min ? `<s>${ora(t1.arrivo)}</s>${piuMinuti(t1.arrivo, v.ritardo_min)}` : ora(t1.arrivo)}</span>
              <span>${esc(t1.a)}, binario ${esc(t1.binario_arrivo)}${v.ritardo_min ? `<br><span class="piccolo" style="color:var(--rosso)">+${v.ritardo_min} min previsti all'arrivo</span>` : ''}</span></li>
          <li class="cambio"><span></span><span>Cambio: binario ${esc(t1.binario_arrivo)} → binario ${esc(t2.binario_partenza)}</span></li>
          <li><span class="ora">${ora(t2.partenza)}</span><span>${esc(t2.da)}, binario ${esc(t2.binario_partenza)}<br><span class="piccolo">${esc(t2.nome)}</span></span></li>
          <li><span class="ora">${ora(t2.arrivo)}</span><span>${esc(t2.a)}</span></li>
        </ul>
      </div>
      <div class="card band">
        <h2>${esc(D.carrozza.titolo)}</h2>
        <p class="muto" style="margin:0">${esc(D.carrozza.testo)}</p>
      </div>`;

    if (!attiva && c === 'verde' && !(mia && ['rifiutata', 'confermata'].includes(mia.stato))) {
      html += '<p class="piccolo">Se il treno ritarda e il cambio diventa stretto, qui compare il bottone per avvisare il capotreno.</p>';
    }
    html += notificheHtml('viaggiatore');
    html += '<p class="piccolo"><a href="#benvenuto">Cambia ruolo</a></p>';
    schermo.innerHTML = html;

    const bAvvisa = document.getElementById('avvisa');
    if (bAvvisa) bAvvisa.addEventListener('click', apriConferma);
    const bAnnulla = document.getElementById('annulla');
    if (bAnnulla) bAnnulla.addEventListener('click', async () => {
      bAnnulla.disabled = true;
      try { await chiama('annulla', { vid }); } catch (e) { mostraErrore(e.message); }
      aggiorna(true);
    });
    collegaNotifiche('viaggiatore');
  }

  function richiestaHtml(mia, c) {
    const finale = mia && ['confermata', 'rifiutata', 'non_serve_piu'].includes(mia.stato);
    if (!mia || (!finale && !['inviata', 'vista', 'stiamo_chiedendo', 'nessuna_risposta'].includes(mia.stato))) {
      if (c === 'verde') return '';
      return '<button class="primario" id="avvisa">Avvisa il capotreno</button>';
    }
    const ordine = { inviata: 0, vista: 1, nessuna_risposta: 1, stiamo_chiedendo: 2, confermata: 3, rifiutata: 3, non_serve_piu: 3 };
    const n = ordine[mia.stato];
    const passi = [
      'Richiesta inviata al capotreno del treno delle 6.44',
      'Il capotreno ha letto la tua richiesta',
      `Il capotreno sta chiedendo alla stazione di ${D.viaggio.cambio}`,
      'Risposta',
    ];
    const li = passi
      .map((t, i) => {
        const cls = i < n ? 'fatto' : i === n ? (finale ? 'fatto' : 'ora') : '';
        return `<li class="${cls}">${esc(t)}${i === 0 ? ` <span class="piccolo">alle ${orario(mia.creata_il)}</span>` : ''}</li>`;
      })
      .join('');
    let esito = '';
    if (mia.stato === 'confermata') esito = `<div class="esito verde">Il treno delle ${ora(D.viaggio.treni[1].partenza)} ti aspetta. Scendi e vai al binario ${esc(D.viaggio.treni[1].binario_partenza)}.</div>`;
    if (mia.stato === 'rifiutata') esito = `<div class="esito rosso">Il treno delle ${ora(D.viaggio.treni[1].partenza)} non può aspettare. Ecco le alternative.</div>`;
    if (mia.stato === 'non_serve_piu') esito = '<div class="esito verde">Il treno ha recuperato: arrivi in tempo, nessuna attesa necessaria.</div>';
    if (mia.stato === 'nessuna_risposta') esito = `<div class="esito giallo">Nessuna risposta dopo ${stato.viaggio.minuti_timeout} minuti. Il capotreno può ancora rispondere; intanto ecco le alternative.</div>`;
    if (mia.stato === 'inviata') esito = '<p class="piccolo" style="margin:8px 0 0">In attesa di risposta. Puoi chiudere l\'app: se hai attivato le notifiche ti avvisiamo noi.</p>';

    let html = `<div class="card"><h2>La tua richiesta</h2><ol class="passi">${li}</ol>${esito}`;
    if (!finale) html += '<button class="secondario" id="annulla" style="margin-top:12px">Non mi serve più, annulla</button>';
    html += '</div>';
    if (mia.stato === 'rifiutata' || mia.stato === 'nessuna_risposta') html += alternativeHtml();
    return html;
  }

  function alternativeHtml() {
    return `<div class="card"><h2>Le alternative</h2>${D.alternative
      .map(
        (a) => `<div class="alternativa"><div><b>${esc(a.titolo)}</b><br><span class="muto">${esc(a.dettaglio)}</span>${a.nota ? `<br><span class="piccolo">${esc(a.nota)}</span>` : ''}</div>
        <div class="arrivo">${a.arrivo === '—' ? '' : `a ${esc(D.viaggio.treni[1].a)} alle `}${esc(ora(a.arrivo))}</div></div>`
      )
      .join('')}</div>`;
  }

  function apriConferma() {
    foglioAperto = true;
    const t2 = D.viaggio.treni[1];
    const f = document.createElement('div');
    f.className = 'foglio';
    f.innerHTML = `<div class="card" role="dialog" aria-modal="true" aria-labelledby="titolo-conferma">
        <h2 id="titolo-conferma">Avvisiamo il capotreno?</h2>
        <p class="muto">Gli diciamo che devi cambiare a ${esc(D.viaggio.cambio)} per il treno delle ${ora(t2.partenza)} per ${esc(t2.a)}. Lui chiede alla stazione se il treno può aspettarti.</p>
        <label for="nome">Il tuo nome (facoltativo)</label>
        <input type="text" id="nome" maxlength="60" autocomplete="given-name" value="${esc(leggi('coinc_nome') || '')}">
        <div style="height:12px"></div>
        <button class="primario" id="conferma">Sì, avvisa il capotreno</button>
        <button class="secondario" id="chiudi">Non ora</button>
      </div>`;
    document.body.appendChild(f);
    const chiudi = () => { f.remove(); foglioAperto = false; aggiorna(true); };
    f.querySelector('#chiudi').addEventListener('click', chiudi);
    f.addEventListener('click', (e) => { if (e.target === f) chiudi(); });
    f.querySelector('#conferma').addEventListener('click', async (e) => {
      e.target.disabled = true;
      const nome = f.querySelector('#nome').value.trim();
      scrivi('coinc_nome', nome);
      try {
        await chiama('richiesta', { vid, nome });
      } catch (err) {
        mostraErrore(err.message);
      }
      chiudi();
    });
  }

  // ---------- 8-10. Capotreno ----------
  function schermoCapotreno() {
    const v = stato.viaggio;
    const rich = stato.richieste;
    const [t1, t2] = D.viaggio.treni;
    const oggi = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato'][new Date().getDay()];
    const conta = (s) => rich.filter((r) => r.stato === s).length;

    let html = `<h1>Treno delle ${ora(t1.partenza)}</h1>
      <p class="muto">${esc(t1.da)} → ${esc(t1.a)}. Ritardo previsto all'arrivo: <b>${v.ritardo_min ? `${v.ritardo_min} minuti` : 'nessuno'}</b>.</p>
      <div class="card">
        <h2>${esc(D.viaggio.cambio)}, treno per ${esc(t2.a)} delle ${ora(t2.partenza)}</h2>
        <div class="conteggio">${rich.length}</div>
        <p class="muto">${rich.length === 1 ? 'persona deve' : 'persone devono'} cambiare e ti ${rich.length === 1 ? 'ha' : 'hanno'} avvisato.</p>`;
    if (rich.length) {
      html += `<ul class="persone">${rich
        .map((r) => `<li><span>${esc(r.nome || 'Viaggiatore')} <span class="piccolo">alle ${orario(r.creata_il)}</span></span><span class="etichetta">${esc(etichetta(r.stato))}</span></li>`)
        .join('')}</ul>
        <p class="piccolo" style="margin-top:10px">Chiama il capostazione di ${esc(D.viaggio.cambio)} come fai oggi, poi segna qui la risposta: ${rich.length === 1 ? 'arriva subito al viaggiatore' : `arriva a tutte le ${rich.length} persone insieme`}.</p>
        <button id="r-chiedo" ${conta('stiamo_chiedendo') === rich.length ? 'disabled' : ''}>Sto chiedendo al capostazione</button>
        <button class="verde" id="r-si">Confermata: il treno aspetta</button>
        <button class="rosso" id="r-no">Rifiutata: non può aspettare</button>
        <button id="r-inutile">Non serve più: abbiamo recuperato</button>`;
    } else {
      html += '<p class="piccolo" style="margin:0">Quando un viaggiatore preme "Avvisa il capotreno", lo vedi qui.</p>';
    }
    html += '</div>';

    html += `<div class="card"><h2>La mia agenda</h2><p class="piccolo">Turni inventati per il prototipo. Nella prova il treno in servizio è sempre il ${ora(t1.partenza)}.</p><ul class="agenda">${D.capotreno.turni
      .map((t) => `<li class="${t.giorno === oggi ? 'oggi' : ''}"><span class="giorno">${esc(t.giorno)}</span>, ${esc(t.orario)}${t.treni.length ? `<div class="treni">${t.treni.map(esc).join(' · ')}</div>` : ''}</li>`)
      .join('')}</ul></div>`;
    html += notificheHtml('capotreno');
    html += '<p class="piccolo"><a href="#benvenuto">Cambia ruolo</a></p>';
    schermo.innerHTML = html;

    const rispondi = (s) => async (e) => {
      e.target.disabled = true;
      try { await chiama('rispondi', { stato: s }); } catch (err) { mostraErrore(err.message); }
      aggiorna(true);
    };
    [['r-chiedo', 'stiamo_chiedendo'], ['r-si', 'confermata'], ['r-no', 'rifiutata'], ['r-inutile', 'non_serve_piu']].forEach(([id, s]) => {
      const b = document.getElementById(id);
      if (b) b.addEventListener('click', rispondi(s));
    });
    collegaNotifiche('capotreno');
  }

  function etichetta(s) {
    return { inviata: 'nuova', vista: 'letta', stiamo_chiedendo: 'stai chiedendo', nessuna_risposta: 'aspetta da molto' }[s] || s;
  }

  // Quando il capotreno ha lo schermo aperto, le richieste nuove diventano "vista"
  async function segnaVista() {
    if (segnaVistaInCorso || document.hidden || !stato) return;
    if (!stato.richieste.some((r) => r.stato === 'inviata')) return;
    segnaVistaInCorso = true;
    try {
      await chiama('rispondi', { stato: 'vista' });
    } catch (e) { /* riprova al prossimo giro */ }
    segnaVistaInCorso = false;
  }

  // ---------- 11. Regia ----------
  function schermoRegia() {
    const v = stato.viaggio;
    const scelte = [0, 2, 4, 6, 8, 12];
    let html = `<h1>Regia</h1>
      <p class="muto">Solo per i test. Quello che scegli qui lo vedono subito viaggiatore e capotreno, e arriva una notifica ai viaggiatori.</p>
      <div class="card">
        <h2>Ritardo previsto a ${esc(D.viaggio.cambio)}</h2>
        <div class="griglia">${scelte.map((s) => `<button data-ritardo="${s}" class="${s === v.ritardo_min ? 'scelto' : ''}">${s} min</button>`).join('')}</div>
        <div class="riga"><input type="number" id="ritardo" min="0" max="180" inputmode="numeric" placeholder="Altro"><button class="secondario" id="imposta" style="margin:0">Imposta</button></div>
        <p class="piccolo" style="margin-top:10px">Margine reale adesso: <b>${v.margine_reale} min</b> (verde da 3 in su, giallo 0-2, rosso sotto 0).</p>
        <p class="piccolo" id="esito-regia" style="margin:0"></p>
      </div>
      <div class="card">
        <h2>Impostazioni della prova</h2>
        <label for="attr">Minuti per andare dal binario 6 al binario 1</label>
        <input type="number" id="attr" min="0" max="30" value="${v.minuti_attraversamento}">
        <p class="piccolo">Ipotesi: 4. Stefano lo misura a Monselice.</p>
        <label for="timeout">Dopo quanti minuti senza risposta mostrare le alternative</label>
        <input type="number" id="timeout" min="1" max="60" value="${v.minuti_timeout}">
        <div style="height:12px"></div>
        <button class="secondario" id="salva">Salva le impostazioni</button>
      </div>
      <div class="card">
        <h2>Richieste attive: ${stato.richieste.length}</h2>
        ${stato.richieste.map((r) => `<p class="piccolo" style="margin:0">${esc(r.nome || 'Viaggiatore')} · ${esc(etichetta(r.stato))}</p>`).join('')}
        <div style="height:12px"></div>
        <button class="rosso" id="azzera">Ricomincia la prova da capo</button>
        <p class="piccolo" style="margin:0">Cancella tutte le richieste e rimette il ritardo a 0.</p>
      </div>
      <p class="piccolo">Notifiche: ${stato.notifiche.pronte ? 'configurate' : 'non ancora configurate (mancano le chiavi su Vercel, vedi la guida)'}.</p>
      <p class="piccolo"><a href="#benvenuto">Cambia ruolo</a></p>`;
    schermo.innerHTML = html;

    const esito = document.getElementById('esito-regia');
    const imposta = async (corpo) => {
      try {
        const r = await chiama('regia', corpo);
        if (r.notifiche_inviate !== undefined) esito.textContent = `Fatto. Notifiche inviate: ${r.notifiche_inviate}.`;
      } catch (e) { mostraErrore(e.message); }
      if (document.activeElement) document.activeElement.blur();
      aggiorna(true);
    };
    schermo.querySelectorAll('[data-ritardo]').forEach((b) =>
      b.addEventListener('click', () => imposta({ ritardo_min: Number(b.dataset.ritardo) }))
    );
    document.getElementById('imposta').addEventListener('click', () => {
      const n = Number(document.getElementById('ritardo').value);
      if (Number.isInteger(n) && n >= 0) imposta({ ritardo_min: n });
    });
    document.getElementById('salva').addEventListener('click', () =>
      imposta({
        minuti_attraversamento: Number(document.getElementById('attr').value),
        minuti_timeout: Number(document.getElementById('timeout').value),
      })
    );
    document.getElementById('azzera').addEventListener('click', () => imposta({ azzera: true }));
  }

  // ---------- Notifiche (flusso F) ----------
  const eIOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const eStandalone = () => window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const pushSupportato = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;

  function notificheHtml() {
    if (!stato.notifiche.pronte) return '';
    if (pushSupportato() && Notification.permission === 'granted' && leggi('coinc_push') === '1') {
      return '<p class="piccolo">Notifiche attive su questo telefono. <a href="#" id="prova-notifica">Mandami una prova</a></p>';
    }
    if (!pushSupportato()) {
      if (eIOS() && !eStandalone()) {
        return '<div class="card band"><h2>Vuoi le notifiche?</h2><p class="muto" style="margin:0">Su iPhone prima aggiungi l\'app alla schermata Home: tasto <b>Condividi</b>, poi <b>Aggiungi alla schermata Home</b>. Poi riaprila dall\'icona.</p></div>';
      }
      return '<p class="piccolo">Questo browser non può ricevere notifiche.</p>';
    }
    if (Notification.permission === 'denied') {
      return '<p class="piccolo">Le notifiche sono bloccate per questo sito. Si riattivano dalle impostazioni del browser.</p>';
    }
    return '<button class="secondario" id="attiva-notifiche">Attiva le notifiche</button>';
  }

  function collegaNotifiche(ruolo) {
    const b = document.getElementById('attiva-notifiche');
    if (b) b.addEventListener('click', async () => {
      b.disabled = true;
      try {
        const ok = await iscrivi(ruolo, true);
        if (!ok) mostraErrore('Notifiche non attivate: serve il permesso.');
      } catch (e) {
        mostraErrore(`Notifiche non attivate: ${e.message}`);
      }
      aggiorna(true);
    });
    const p = document.getElementById('prova-notifica');
    if (p) p.addEventListener('click', async (e) => {
      e.preventDefault();
      try {
        const reg = await navigator.serviceWorker.ready;
        const sub = await reg.pushManager.getSubscription();
        if (!sub) { scrivi('coinc_push', '0'); return aggiorna(true); }
        await iscrivi(ruolo, false);
        await chiama('push-prova', { endpoint: sub.endpoint });
      } catch (err) { mostraErrore(err.message); }
    });
  }

  function chiaveInByte(b64) {
    const pad = '='.repeat((4 - (b64.length % 4)) % 4);
    const raw = atob((b64 + pad).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  async function iscrivi(ruolo, chiediPermesso) {
    if (!pushSupportato() || !stato || !stato.notifiche.chiave) return false;
    if (Notification.permission !== 'granted') {
      if (!chiediPermesso) return false;
      const p = await Notification.requestPermission();
      if (p !== 'granted') return false;
    }
    const reg = await navigator.serviceWorker.ready;
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: chiaveInByte(stato.notifiche.chiave) });
    }
    await chiama('push-iscrivi', { subscription: sub.toJSON(), ruolo, vid });
    scrivi('coinc_push', '1');
    if (chiediPermesso) await chiama('push-prova', { endpoint: sub.endpoint }).catch(() => {});
    return true;
  }

  // Se il ruolo cambia, il telefono riceve le notifiche giuste
  function aggiornaIscrizione(ruolo) {
    if (leggi('coinc_push') === '1') iscrivi(ruolo, false).catch(() => {});
  }

  // ---------- Avvio ----------
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/app/sw.js', { scope: '/app/' }).catch(() => {});
  }
  document.querySelector('[data-vai="benvenuto"]').addEventListener('click', (e) => { e.preventDefault(); vai('benvenuto'); });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) aggiorna(true); });
  disegna();
  aggiorna(true);
  setInterval(() => { if (!document.hidden) aggiorna(false); }, OGNI_MS);
})();
