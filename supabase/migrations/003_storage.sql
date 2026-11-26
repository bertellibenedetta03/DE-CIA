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
