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
  start_to       timestamptz  not null default now(),
  progress       bigint       not null default 0,
  estimate       bigint       not null default 5,
  constraint fk_parent_id foreign key (parent_id) 
    references tasks(id)
    on delete cascade 
    on update cascade,
  constraint id_no_cycle       check(id <> parent_id),
  constraint title_non_empty   check(length(title) > 0),
  constraint check_dates       check (available_from <= due),
  constraint positive_estimate check (estimate > 0),
  constraint unique_task_order unique (parent_id, task_order)
);

create or replace function t_ancestors(root_id bigint)
returns table (id bigint) as $$
begin
  return query
  with recursive c as (
    select root_id as parent_id
    union all
    select sa.parent_id
    from tasks as sa
    join c ON c.parent_id = sa.id
  ) select * from c where c.parent_id != root_id;
end;
$$ language plpgsql;

create or replace function t_recalc_task(task_id bigint)
returns table (
  id bigint,
  st task_status,
  estimate bigint,
  start_to timestamptz,
  duedate timestamptz,
  progress bigint
) as $$
begin
	return query
	with calc_estimate as (
		select coalesce(sum(t.estimate), 0)::bigint as res from tasks t where t.parent_id = task_id
	),
	calc_progress as (
	  select 
	    case
		    when all_estimate.res <> 0
		    then ceil(done_estimate.res / all_estimate.res * 100)::bigint
		    else 0::bigint
		end as res
	  from 
	    calc_estimate as all_estimate,
	   (select coalesce(sum(t.estimate), 0) as res from tasks t where t.parent_id = task_id and "task_status" = 'DONE') as done_estimate
	),
	count_statuses as (
		select v.ts as "task_status", count(t."task_status") as count
		from 
			(values ('TODO'::task_status), ('DONE'::task_status)) v("ts") 
			left join tasks t on (t."task_status" = v."ts" and t.parent_id = task_id)
		group by v.ts
	),
	sumall_statuses as (
		  select sum(c.count) from count_statuses c
	),
	calc_status as (
		select 
			case when sumall_statuses.sum = count_statuses.count and sumall_statuses.sum != 0
			     then 'DONE'::"task_status"
			     else 'TODO'::"task_status" 
			end as res
		from count_statuses, sumall_statuses
		where count_statuses.task_status = 'DONE'
	),
	calc_due as (
		select 
			coalesce(max(t.due), (select t.due from tasks t where t.id = task_id)) as res 
		from tasks t where t.parent_id = task_id
	),
	calc_start_to as (
		select (calc_due.res - (interval '1 minute' * calc_estimate.res)) as res from calc_due, calc_estimate
	)
	select 
		task_id as id, 
		calc_status.res as "st", 
		calc_estimate.res as "estimate",
		calc_start_to.res as "start_to", 
		calc_due.res as "duedate",
		calc_progress.res as "progress"
	from 
		calc_status, 
		calc_estimate,
		calc_start_to,
		calc_due,
	    calc_progress;
end
$$ language plpgsql;

create or replace procedure t_update_ancestors(task_id bigint)
language plpgsql
as $$
begin
	update tasks t 
	set 
		task_status = updated.st,
		estimate = updated.estimate,
		due = updated.duedate,
		progress = updated.progress,
		start_to = updated.start_to
	from (
		SELECT t.*
		FROM t_ancestors(task_id) a
		CROSS  JOIN LATERAL (
		   SELECT 
		   	--a, 
		   	t.*
		   FROM (select * from t_recalc_task(a.id) t) t
		   where t.id = a.id
		   ) t
	) as updated
	where updated.id = t.id;
end;
$$;

create or replace procedure insert_task(parent bigint default 1, title text default 'Unnamed task')
language plpgsql
as $$
declare
  max_task_order bigint;
  id_inserted bigint;
begin
  select coalesce(max(task_order), 1) into max_task_order from tasks where parent_id = parent;
  insert into tasks(parent_id, task_order, title) values (parent, max_task_order+1, title)
  returning id into id_inserted;
  call t_update_ancestors(id_inserted);
end;
$$;

create or replace procedure delete_task(task_id bigint)
language plpgsql
as $$
declare
  task_parent_id bigint;
begin
  select t.parent_id into task_parent_id from tasks t where t.id = task_id;
  delete from tasks t where t.id = task_id;
 update tasks t 
	set 
		task_status = updated.st,
		estimate = updated.estimate,
		due = updated.duedate,
		progress = updated.progress,
		start_to = updated.start_to
	from (
		SELECT t.*
		FROM (select task_parent_id as id union all select * from t_ancestors(task_parent_id)) a
		CROSS  JOIN LATERAL (
		   SELECT 
		   	--a, 
		   	t.*
		   FROM (select * from t_recalc_task(a.id) t) t
		   where t.id = a.id
		   ) t
	) as updated
	where updated.id = t.id;
end;
$$;

-- Works correct only for leafs
create or replace procedure task_done(task_id bigint)
language plpgsql
as $$
begin
  update tasks ut
  set task_status = 'DONE'
  where ut.id = task_id;
  call t_update_ancestors(task_id);
end;
$$;

create or replace function todo_list()
returns table (task_status task_status, title text)
as $$
begin
  return query
  select t.task_status, t.title from tasks t where t.parent_id = 1 and t.task_status = 'TODO' order by t.task_order;
end;
$$ language plpgsql;

insert into tasks(parent_id, task_order, title) values (null, 1, 'Meta task');
