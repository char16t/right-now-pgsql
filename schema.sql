drop table if exists tasks cascade;
drop type if exists task_status cascade;
drop type if exists task_type cascade;

create type task_status as enum('TODO', 'DONE');
create type task_type as enum('ORDERED', 'SET', 'ONE_OF');
create table tasks(
  id             bigserial    primary key,
  parent_id      bigint,
  title          text         not null,
  task_status    task_status  not null default 'TODO',
  task_type      task_type    not null default 'SET',
  task_order     bigint       not null,
  due            timestamptz  not null default now(),
  available_from timestamptz  not null default now(),
  estimate       bigint       not null default 5,
  constraint fk_parent_id foreign key (parent_id) 
    references tasks(id)
    on delete restrict 
    on update restrict,
  constraint id_no_cycle       check(id <> parent_id),
  constraint title_non_empty   check(length(title) > 0),
  constraint check_dates       check (available_from <= due),
  constraint positive_estimate check (estimate > 0),
  constraint unique_task_order unique (parent_id, task_order)
);

create or replace procedure insert_task(title text)
language plpgsql
as $$
declare
  max_task_order bigint;
begin
  select coalesce(max(task_order), 1) into max_task_order from tasks where parent_id = 1;
  insert into tasks(parent_id, task_order, title) values (1, max_task_order+1, title);
end;
$$;

create or replace procedure reorder_task(task_id bigint, new_order bigint)
language plpgsql
as $$
begin
  update tasks ut
  set task_order = ut.task_order + 1
  from (
    select * from tasks t where t.task_order >= new_order order by t.task_order desc
  ) as candidates
  where candidates.id = ut.id;
 
  update tasks ut
  set task_order = new_order
  where ut.id = task_id;
end;
$$;

create or replace function todo_list()
returns table (task_status task_status, title text)
as $$
begin
  return query
  select t.task_status, t.title from tasks t where t.parent_id = 1 and t.task_status = 'TODO';
end;
$$ language plpgsql;

insert into tasks(parent_id, task_order, title) values (null, 1, 'Meta task');
