-- Migração 006: imagem (ícone) dos itens.
-- Rode isso se você já tinha rodado uma versão anterior do schema.
-- Se você está instalando do zero, só rode o schema.sql — ele já
-- inclui essas mudanças.

alter table items add column if not exists image_url text;

-- Bucket de storage pra o ícone de cada item (upload feito pelo admin).
-- Leitura pública (pra aparecer no site), escrita só autenticada.
insert into storage.buckets (id, name, public)
values ('item-icons', 'item-icons', true)
on conflict (id) do nothing;

do $$ begin
  create policy "item_icons_public_read"
    on storage.objects for select
    using (bucket_id = 'item-icons');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create policy "item_icons_auth_write"
    on storage.objects for insert
    with check (bucket_id = 'item-icons' and auth.role() = 'authenticated');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create policy "item_icons_auth_update"
    on storage.objects for update
    using (bucket_id = 'item-icons' and auth.role() = 'authenticated');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create policy "item_icons_auth_delete"
    on storage.objects for delete
    using (bucket_id = 'item-icons' and auth.role() = 'authenticated');
exception
  when duplicate_object then null;
end $$;
