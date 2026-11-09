-- Funzioni sociali: riassegnazioni admin, scambi, bonus e didascalie foto.
-- Eseguire una volta nel SQL Editor Supabase. Non modifica gli account esistenti.
alter table public.proofs add column if not exists caption text;
alter table public.proofs drop constraint if exists proofs_caption_length;
alter table public.proofs add constraint proofs_caption_length check (caption is null or length(caption) <= 500);

alter table public.assignments add column if not exists bonus_points integer not null default 0 check (bonus_points between 0 and 10000);

create table if not exists public.assignment_swaps (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  from_assignment uuid not null references public.assignments(id) on delete cascade,
  to_assignment uuid not null references public.assignments(id) on delete cascade,
  proposed_by uuid not null references auth.users(id) on delete cascade,
  target_user uuid not null references auth.users(id) on delete cascade,
  bonus_points integer not null default 0 check (bonus_points >= 0),
  bonus_user uuid references auth.users(id) on delete cascade,
  bonus_assignment uuid references public.assignments(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (from_assignment <> to_assignment)
);
create index if not exists assignment_swaps_household_created on public.assignment_swaps(household_id, created_at desc);
alter table public.assignment_swaps enable row level security;
drop policy if exists "house members read swaps" on public.assignment_swaps;
create policy "house members read swaps" on public.assignment_swaps for select to authenticated using (public.is_house_member(household_id));
revoke insert, update, delete on public.assignment_swaps from authenticated;
grant select on public.assignment_swaps to authenticated;

create or replace function public.propose_assignment_swap(p_assignment uuid,p_target_assignment uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; b public.assignments; ca public.chores; cb public.chores; target_role text; sid uuid;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select * into a from public.assignments where id=p_assignment for update;
 select * into b from public.assignments where id=p_target_assignment for update;
 if a.id is null or b.id is null or a.id=b.id then raise exception 'Missione non disponibile'; end if;
 if a.assignee<>auth.uid() or a.state<>'open' or b.state<>'open' or a.household_id<>b.household_id or a.week_start<>b.week_start then raise exception 'Puoi proporre solo uno scambio tra missioni aperte della stessa settimana'; end if;
 if not public.is_house_member(a.household_id) then raise exception 'Non sei membro della casa'; end if;
 select role into target_role from public.memberships where household_id=a.household_id and user_id=b.assignee;
 if target_role is distinct from 'member' or b.assignee=auth.uid() then raise exception 'Destinatario non valido'; end if;
 if exists(select 1 from public.assignment_swaps s where s.status='pending' and (s.from_assignment in (a.id,b.id) or s.to_assignment in (a.id,b.id))) then raise exception 'Una delle missioni ha già uno scambio in attesa'; end if;
 select * into ca from public.chores where id=a.chore_id;
 select * into cb from public.chores where id=b.chore_id;
 insert into public.assignment_swaps(household_id,from_assignment,to_assignment,proposed_by,target_user)
 values(a.household_id,a.id,b.id,auth.uid(),b.assignee) returning id into sid;
 return sid;
end $$;

create or replace function public.respond_assignment_swap(p_swap uuid,p_accept boolean)
returns void language plpgsql security definer set search_path=public,auth as $$
declare s public.assignment_swaps; a public.assignments; b public.assignments; ca public.chores; cb public.chores; difference integer;
begin
 select * into s from public.assignment_swaps where id=p_swap for update;
 if s.id is null or s.status<>'pending' or s.target_user<>auth.uid() then raise exception 'Scambio non disponibile'; end if;
 select * into a from public.assignments where id=s.from_assignment for update;
 select * into b from public.assignments where id=s.to_assignment for update;
 if a.state<>'open' or b.state<>'open' or a.household_id<>s.household_id or b.household_id<>s.household_id then raise exception 'Le missioni non sono più disponibili'; end if;
 update public.assignment_swaps set status=case when p_accept then 'accepted' else 'rejected' end,responded_at=now() where id=s.id;
 if not p_accept then return; end if;
 select * into ca from public.chores where id=a.chore_id;
 select * into cb from public.chores where id=b.chore_id;
 difference:=abs(ca.points-cb.points);
 update public.assignments set assignee=b.assignee,bonus_points=0 where id=a.id;
 update public.assignments set assignee=a.assignee,bonus_points=0 where id=b.id;
 if ca.points>cb.points then
   update public.assignments set bonus_points=difference where id=a.id;
   update public.assignment_swaps set bonus_points=difference,bonus_user=b.assignee,bonus_assignment=a.id where id=s.id;
 elsif cb.points>ca.points then
   update public.assignments set bonus_points=difference where id=b.id;
   update public.assignment_swaps set bonus_points=difference,bonus_user=a.assignee,bonus_assignment=b.id where id=s.id;
 end if;
end $$;

create or replace function public.admin_reassign_assignment(p_assignment uuid,p_assignee uuid)
returns void language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; role_for_user text;
begin
 select * into a from public.assignments where id=p_assignment for update;
 if a.id is null or not public.is_house_owner(a.household_id) then raise exception 'Solo l’admin può riassegnare le missioni'; end if;
 if a.state<>'open' then raise exception 'Puoi riassegnare solo missioni non ancora inviate'; end if;
 select role into role_for_user from public.memberships where household_id=a.household_id and user_id=p_assignee;
 if role_for_user is distinct from 'member' then raise exception 'Scegli un coinquilino della casa'; end if;
 update public.assignment_swaps set status='cancelled',responded_at=now() where status='pending' and (from_assignment=a.id or to_assignment=a.id);
 update public.assignments set assignee=p_assignee,bonus_points=0 where id=a.id;
end $$;

drop function if exists public.submit_proof(uuid,text);
create or replace function public.submit_proof(p_assignment uuid,p_path text,p_caption text default null)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare a public.assignments; pid uuid;
begin
 select * into a from public.assignments where id=p_assignment for update;
 if a.assignee<>auth.uid() or a.state<>'open' then raise exception 'Assignment unavailable'; end if;
 if p_caption is not null and length(p_caption)>500 then raise exception 'La didascalia è troppo lunga'; end if;
 insert into public.proofs(assignment_id,submitted_by,storage_path,caption)
 values(p_assignment,auth.uid(),p_path,nullif(trim(p_caption),'')) returning id into pid;
 update public.assignments set state='pending' where id=p_assignment;
 return pid;
end $$;

create or replace function public.review_proof(p_proof uuid,p_approve boolean)
returns void language plpgsql security definer set search_path=public,auth as $$
declare p public.proofs; a public.assignments; c public.chores; awarded integer;
begin
 select * into p from public.proofs where id=p_proof for update;
 select * into a from public.assignments where id=p.assignment_id for update;
 if p.id is null or p.state<>'pending' or p.submitted_by=auth.uid() or not public.is_house_member(a.household_id) then raise exception 'Not authorized'; end if;
 update public.proofs set state=case when p_approve then 'approved' else 'rejected' end,reviewed_by=auth.uid(),reviewed_at=now() where id=p.id;
 update public.assignments set state=case when p_approve then 'done' else 'open' end where id=a.id;
 if p_approve then
  select * into c from public.chores where id=a.chore_id;
  awarded:=c.points+a.bonus_points;
  insert into public.points_ledger(household_id,user_id,delta,reason,assignment_id)
  values(a.household_id,a.assignee,awarded,case when a.bonus_points>0 then 'Missione completata (include +'||a.bonus_points||' punti bonus per lo scambio)' else 'Missione completata' end,a.id)
  on conflict do nothing;
 end if;
end $$;

grant execute on function public.propose_assignment_swap(uuid,uuid) to authenticated;
grant execute on function public.respond_assignment_swap(uuid,boolean) to authenticated;
grant execute on function public.admin_reassign_assignment(uuid,uuid) to authenticated;
grant execute on function public.submit_proof(uuid,text,text) to authenticated;
grant execute on function public.review_proof(uuid,boolean) to authenticated;
