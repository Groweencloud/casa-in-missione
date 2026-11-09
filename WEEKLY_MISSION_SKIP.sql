-- Pausa una singola assegnazione della settimana corrente.
alter table public.assignments add column if not exists is_skipped boolean not null default false;

create or replace function public.admin_skip_assignment(p_assignment uuid,p_skip boolean)
returns void language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments;
begin
 select * into a from public.assignments where id=p_assignment for update;
 if auth.uid() is null or a.id is null or not public.is_house_owner(a.household_id) then raise exception 'Solo l’admin può modificare le missioni'; end if;
 if p_skip is null then raise exception 'Stato di sospensione non valido'; end if;
 if a.state<>'open' then raise exception 'Puoi sospendere solo una missione ancora aperta'; end if;
 if p_skip then
  update public.assignment_swaps set status='cancelled',responded_at=now()
  where status='pending' and (from_assignment=a.id or to_assignment=a.id);
 end if;
 update public.assignments set is_skipped=p_skip where id=a.id;
end $$;
revoke all on function public.admin_skip_assignment(uuid,boolean) from public,anon;
grant execute on function public.admin_skip_assignment(uuid,boolean) to authenticated;

create or replace function public.submit_proof(p_assignment uuid,p_path text,p_caption text default null)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; c public.chores; pid uuid; awarded integer;
begin
 select * into a from public.assignments where id=p_assignment for update;
 if a.id is null or a.assignee<>auth.uid() or a.state<>'open' or a.is_skipped then raise exception 'Missione non disponibile'; end if;
 if p_caption is not null and length(p_caption)>500 then raise exception 'La didascalia è troppo lunga'; end if;
 select * into c from public.chores where id=a.chore_id;
 awarded:=c.points+a.bonus_points;
 insert into public.proofs(assignment_id,submitted_by,storage_path,caption,state,reviewed_at)
 values(p_assignment,auth.uid(),p_path,nullif(trim(p_caption),''),'approved',now()) returning id into pid;
 update public.assignments set state='done' where id=p_assignment;
 insert into public.points_ledger(household_id,user_id,delta,reason,assignment_id)
 values(a.household_id,a.assignee,awarded,
   case when a.bonus_points>0 then 'Missione completata automaticamente (include +'||a.bonus_points||' punti bonus per lo scambio)' else 'Missione completata automaticamente' end,
   a.id)
 on conflict do nothing;
 return pid;
end $$;
revoke all on function public.submit_proof(uuid,text,text) from public,anon;
grant execute on function public.submit_proof(uuid,text,text) to authenticated;

create or replace function public.propose_assignment_swap(p_assignment uuid,p_target_assignment uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; b public.assignments; target_role text; sid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into a from public.assignments where id=p_assignment for update;
 select * into b from public.assignments where id=p_target_assignment for update;
 if a.id is null or b.id is null or a.id=b.id then raise exception 'Missione non disponibile'; end if;
 if a.assignee<>auth.uid() or a.state<>'open' or b.state<>'open' or a.is_skipped or b.is_skipped or a.household_id<>b.household_id or a.week_start<>b.week_start then raise exception 'Puoi proporre solo uno scambio tra missioni attive della stessa settimana'; end if;
 if not public.is_house_member(a.household_id) then raise exception 'Non sei membro della casa'; end if;
 select role into target_role from public.memberships where household_id=a.household_id and user_id=b.assignee;
 if target_role is distinct from 'member' or b.assignee=auth.uid() then raise exception 'Destinatario non valido'; end if;
 if exists(select 1 from public.assignment_swaps s where s.status='pending' and (s.from_assignment in (a.id,b.id) or s.to_assignment in (a.id,b.id))) then raise exception 'Una delle missioni ha già uno scambio in attesa'; end if;
 insert into public.assignment_swaps(household_id,from_assignment,to_assignment,proposed_by,target_user)
 values(a.household_id,a.id,b.id,auth.uid(),b.assignee) returning id into sid;
 return sid;
end $$;

create or replace function public.admin_reassign_assignment(p_assignment uuid,p_assignee uuid)
returns void language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; role_for_user text;
begin
 select * into a from public.assignments where id=p_assignment for update;
 if a.id is null or not public.is_house_owner(a.household_id) then raise exception 'Solo l’admin può riassegnare le missioni'; end if;
 if a.state<>'open' or a.is_skipped then raise exception 'Puoi riassegnare solo missioni attive e ancora aperte'; end if;
 select role into role_for_user from public.memberships where household_id=a.household_id and user_id=p_assignee;
 if role_for_user is distinct from 'member' then raise exception 'Scegli un coinquilino della casa'; end if;
 update public.assignment_swaps set status='cancelled',responded_at=now() where status='pending' and (from_assignment=a.id or to_assignment=a.id);
 update public.assignments set assignee=p_assignee,bonus_points=0 where id=a.id;
end $$;
revoke all on function public.admin_reassign_assignment(uuid,uuid) from public,anon;
grant execute on function public.admin_reassign_assignment(uuid,uuid) to authenticated;
