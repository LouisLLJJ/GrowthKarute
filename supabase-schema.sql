-- Supabase SQL Editor に貼って実行してください。
-- 個人情報を守るため、許可したメールアドレスだけが共有カルテを閲覧・編集できます。
-- メールを追加するときは growth_karute_members に行を追加してください。

create table if not exists public.growth_karute_documents (
  id text primary key,
  people jsonb not null default '[]'::jsonb,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create table if not exists public.growth_karute_members (
  email text primary key,
  role text not null default 'member',
  created_at timestamptz not null default now()
);

alter table public.growth_karute_documents enable row level security;
alter table public.growth_karute_members enable row level security;

grant select, insert, update on public.growth_karute_documents to authenticated;

drop policy if exists "members can read karute" on public.growth_karute_documents;
drop policy if exists "members can insert karute" on public.growth_karute_documents;
drop policy if exists "members can update karute" on public.growth_karute_documents;
drop policy if exists "authenticated users can read karute" on public.growth_karute_documents;
drop policy if exists "authenticated users can insert karute" on public.growth_karute_documents;
drop policy if exists "authenticated users can update karute" on public.growth_karute_documents;

create or replace function public.is_growth_karute_member()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.growth_karute_members
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.is_growth_karute_member() from public;
grant execute on function public.is_growth_karute_member() to authenticated;

create policy "members can read karute"
on public.growth_karute_documents for select
to authenticated
using (public.is_growth_karute_member());

create policy "members can insert karute"
on public.growth_karute_documents for insert
to authenticated
with check (public.is_growth_karute_member());

create policy "members can update karute"
on public.growth_karute_documents for update
to authenticated
using (public.is_growth_karute_member())
with check (public.is_growth_karute_member());

alter table public.growth_karute_documents replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.growth_karute_documents;
exception
  when duplicate_object then null;
end $$;

insert into public.growth_karute_documents (id, people)
values ('default', '[]'::jsonb)
on conflict (id) do nothing;

-- まず自分のメールだけを許可します。院長のメールは本人の許可後に追加してください。
insert into public.growth_karute_members (email, role)
values ('s1a4e3k5i@gmail.com', 'owner')
on conflict (email) do update set role = excluded.role;
