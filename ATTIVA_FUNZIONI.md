# Attivare scambi, feed e riassegnazioni

La migrazione è per la casa già esistente e non cancella dati. Dopo aver aperto il progetto Supabase con l'account che ne è proprietario:

1. Apri **SQL Editor** e crea una nuova query.
2. Apri il file `MISSION_SOCIAL_FEATURES.sql` di questa cartella, copia tutto il contenuto e incollalo nella query.
3. Premi **Run** e attendi il messaggio di completamento.
4. Pubblica i file aggiornati dell'app (`features.js`, `index.html` e `styles.css`) nel repository collegato a Vercel, oppure carica `vercel-upload.zip` secondo la procedura già usata.

Le modifiche aggiungono le didascalie alle prove, le funzioni sicure per scambi e riassegnazioni e il campo bonus alle missioni. Con l’accredito automatico, il bonus viene assegnato una sola volta insieme ai punti appena viene caricata la foto.

Per attivare il completamento automatico, esegui anche `AUTO_APPROVE_MISSIONS.sql`. Da quel momento la foto completa la missione e assegna subito punti e bonus; le prove già in attesa vengono approvate e accreditate una sola volta.

Per la sospensione settimanale, esegui infine `WEEKLY_MISSION_SKIP.sql`. L’admin può sospendere o riattivare una missione ancora aperta; la sospensione vale solo per quella settimana.
