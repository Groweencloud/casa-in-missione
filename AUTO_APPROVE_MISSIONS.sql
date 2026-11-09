-- Completamento automatico delle nuove prove e accredito immediato dei punti.
-- Include anche le prove che erano già in attesa quando si applica la modifica.
create or replace function public.submit_proof(p_assignment uuid,p_path text,p_caption text default null)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; c public.chores; pid uuid; awarded integer;
begin
 select * into a from public.assignments where id=p_assignment for update;
 if a.id is null or a.assignee<>auth.uid() or a.state<>'open' then raise exception 'Assignment unavailable'; end if;
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
grant execute on function public.submit_proof(uuid,text,text) to authenticated;
revoke insert, update, delete on public.proofs from authenticated;
grant select on public.proofs to authenticated;

with pending as materialized (
 select p.id proof_id,p.assignment_id,a.household_id,a.assignee,c.points+a.bonus_points awarded
 from public.proofs p
 join public.assignments a on a.id=p.assignment_id
 join public.chores c on c.id=a.chore_id
 where p.state='pending'
 for update of p,a
),
approved as (
 update public.proofs p
 set state='approved',reviewed_at=coalesce(p.reviewed_at,now()),reviewed_by=null
 from pending x
 where p.id=x.proof_id
 returning x.assignment_id,x.household_id,x.assignee,x.awarded
),
completed as (
 update public.assignments a
 set state='done'
 from approved x
 where a.id=x.assignment_id
 returning a.id
)
insert into public.points_ledger(household_id,user_id,delta,reason,assignment_id)
select x.household_id,x.assignee,x.awarded,'Missione completata automaticamente',x.assignment_id
from approved x
join completed c on c.id=x.assignment_id
on conflict do nothing;
