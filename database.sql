drop table if exists tasks cascade;
drop type if exists task_status cascade;
drop type if exists task_type cascade;

create type task_status as enum('TODO', 'DONE');
create type task_type as enum('ORDERED', 'SET', 'ONE_OF');
create table tasks(
  id             bigserial    primary key,
  parent_id      bigint,
  title          text         not null,
  status         task_status  not null default 'TODO',
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

create or replace function todo_list()
returns table (status task_status, title text)
as $$
begin
  return query
  select t.status, t.title from tasks t where t.parent_id = 1 and t.status = 'TODO';
end;
$$ language plpgsql;


insert into tasks(parent_id, task_order, title) values (null, 1, 'Meta task');

call insert_task(title := 'Make a init-sql in Spring Boot-1.4.1-RELEASE');
call insert_task(title := 'Configure port for a Spring Boot application');
call insert_task(title := 'Running code after Spring Boot starts');
call insert_task(title := 'Write result of a differentiation in terms of dependent variable');
call insert_task(title := 'Use of the subjunctive in a quod-clause in Renaissance Latin');
call insert_task(title := 'Finding duplicate blocks of text within a file using shell script');

select * from todo_list();
