create role web_anon nologin;
grant all on schema public to web_anon;
grant select, insert, update, delete on ALL TABLES in schema public to web_anon;
