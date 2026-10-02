-- Player-reported payments are separate from verified payment records.
create table public.membership_payment_submissions (
 id uuid primary key default gen_random_uuid(),
 player_id uuid not null references public.players(id) on delete cascade,
 user_id uuid not null references auth.users(id),
 period_start date not null check (extract(day from period_start)=1),
 amount numeric(10,2) not null check (amount>0 and amount<=10000),
 payment_date date not null,
 method text not null check (length(trim(method)) between 1 and 100),
 transaction_reference text not null check (length(trim(transaction_reference)) between 1 and 200),
 notes text check (length(notes)<=1000),
 status text not null default 'Pending' check (status in ('Pending','Approved','Returned')),
 admin_note text check (length(admin_note)<=1000),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 check ((status='Pending' and reviewed_by is null and reviewed_at is null and admin_note is null) or (status in ('Approved','Returned') and reviewed_by is not null and reviewed_at is not null)),
 check (status<>'Returned' or length(trim(admin_note))>0)
);
create unique index membership_submissions_one_active_period on public.membership_payment_submissions(player_id,period_start) where status in ('Pending','Approved');
create index membership_submissions_user on public.membership_payment_submissions(user_id);
alter table public.membership_payment_submissions enable row level security;
grant select,insert,update on public.membership_payment_submissions to authenticated;
revoke all on public.membership_payment_submissions from anon;
create policy "Members read own payment submissions" on public.membership_payment_submissions for select to authenticated using (
 user_id=(select auth.uid()) or exists(select 1 from public.profiles where id=(select auth.uid()) and role in ('admin','manager'))
);
create policy "Members submit own pending payment" on public.membership_payment_submissions for insert to authenticated with check (
 user_id=(select auth.uid()) and status='Pending' and reviewed_by is null and reviewed_at is null and admin_note is null
 and payment_date <= (now() at time zone 'America/Chicago')::date
 and exists(select 1 from public.players where id=player_id and user_id=(select auth.uid()) and player_category='Member' and deleted_at is null)
);
create policy "Administrators review payments" on public.membership_payment_submissions for update to authenticated
 using (exists(select 1 from public.profiles where id=(select auth.uid()) and role in ('admin','manager')))
 with check (exists(select 1 from public.profiles where id=(select auth.uid()) and role in ('admin','manager')));

create function public.submit_membership_payment(p_period date,p_amount numeric,p_payment_date date,p_method text,p_reference text,p_notes text default '')
returns uuid language plpgsql security invoker set search_path='' as $$
declare player_uuid uuid; submission_uuid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in to submit a payment'; end if;
 select id into player_uuid from public.players where user_id=auth.uid() and player_category='Member' and deleted_at is null;
 if player_uuid is null then raise exception 'A club member profile is required'; end if;
 if p_payment_date is null or p_payment_date>(now() at time zone 'America/Chicago')::date then raise exception 'Choose the date you actually paid'; end if;
 if exists(select 1 from public.membership_payment_submissions where player_id=player_uuid and period_start=p_period and status in ('Pending','Approved')) then raise exception 'You already have a pending or approved submission for this month'; end if;
 insert into public.membership_payment_submissions(player_id,user_id,period_start,amount,payment_date,method,transaction_reference,notes)
 values(player_uuid,auth.uid(),p_period,p_amount,p_payment_date,trim(p_method),trim(p_reference),nullif(trim(p_notes),'')) returning id into submission_uuid;
 return submission_uuid;
exception when unique_violation then raise exception 'You already have a pending or approved submission for this month';
end; $$;
revoke all on function public.submit_membership_payment(date,numeric,date,text,text,text) from public,anon;
grant execute on function public.submit_membership_payment(date,numeric,date,text,text,text) to authenticated;

create function public.review_membership_payment(p_submission_id uuid,p_decision text,p_note text default '')
returns void language plpgsql security invoker set search_path='' as $$
declare item public.membership_payment_submissions;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','manager')) then raise exception 'Only an admin or manager can review payments'; end if;
 if p_decision not in ('Approved','Returned') or p_decision is null then raise exception 'Invalid review decision'; end if;
 if p_decision='Returned' and nullif(trim(p_note),'') is null then raise exception 'Add a note explaining what needs correcting'; end if;
 select * into item from public.membership_payment_submissions where id=p_submission_id for update;
 if item.id is null or item.status<>'Pending' then raise exception 'This submission is no longer awaiting review'; end if;
 if not exists(select 1 from public.players where id=item.player_id and player_category='Member' and deleted_at is null) then raise exception 'This member profile is no longer available'; end if;
 update public.membership_payment_submissions set status=p_decision,admin_note=nullif(trim(p_note),''),reviewed_by=auth.uid(),reviewed_at=now() where id=item.id;
 if p_decision='Approved' then
  insert into public.membership_payments(player_id,period,amount,payment_date,method,status,notes,created_by)
  values(item.player_id,to_char(item.period_start,'FMMonth YYYY'),item.amount,item.payment_date,item.method,'Paid',concat('Reference: ',item.transaction_reference,case when item.notes is not null then E'\nPlayer note: '||item.notes else '' end,case when nullif(trim(p_note),'') is not null then E'\nAdmin note: '||trim(p_note) else '' end),auth.uid());
  update public.players set membership_status='Paid' where id=item.player_id;
 end if;
end; $$;
revoke all on function public.review_membership_payment(uuid,text,text) from public,anon;
grant execute on function public.review_membership_payment(uuid,text,text) to authenticated;

-- Membership approval cannot be bypassed by editing one's own profile.
create function public.guard_membership_status() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if (tg_op='INSERT' and coalesce(new.membership_status,'Unpaid')<>'Unpaid') or (tg_op='UPDATE' and new.membership_status is distinct from old.membership_status) then
  if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and role in ('admin','manager')) then raise exception 'Only club administrators can change membership payment status'; end if;
 end if;
 return new;
end; $$;
create trigger guard_membership_payment_status before insert or update on public.players for each row execute function public.guard_membership_status();
