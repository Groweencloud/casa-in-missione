# Admin: email e cancellazione account

Nel pannello admin, la sezione **Account della casa** mostra le email dei coinquilini. L’eliminazione cancella definitivamente l’account Supabase e richiede conferma.

## Configurazione Vercel

Apri **Project Settings → Environment Variables** e aggiungi:

- `SUPABASE_URL` — URL del progetto Supabase.
- `SUPABASE_ANON_KEY` — chiave anon/pubblicabile usata dall’app.
- `SUPABASE_SERVICE_ROLE_KEY` — chiave segreta service role del progetto Supabase.

Inserisci la chiave service role solo in Vercel: non nel repository, nel sito o in chat. Poi esegui un nuovo deployment Production.

La funzione `/api/admin-house-users` verifica la sessione Supabase e controlla che la persona che la chiama sia admin della casa. Le operazioni privilegiate restano sul server Vercel.

## Protezioni per cancellazioni

La cancellazione globale è bloccata per account proprietari di case o collegati a più case o a dati esterni. In questo modo non vengono eliminati per errore dati appartenenti ad altri gruppi.
