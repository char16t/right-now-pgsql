drop table if exists tasks cascade;
drop table if exists task_info cascade;
drop type if exists task_status cascade;
drop type if exists task_type cascade;

create type task_status as enum('TODO', 'DONE');
create type task_type as enum('ORDERED', 'SET', 'ONE_OF');
create table tasks(
  id             bigserial    primary key,
  parent_id      bigint,
  task_status    task_status  not null default 'TODO',
  task_type      task_type    not null default 'SET',
  task_order     bigint       not null,
  due            timestamptz  not null default now(),
  available_from timestamptz  not null default now(),
  start_to       timestamptz  not null default now(),
  progress       bigint       not null default 0,
  estimate       float8       not null default 5,
  occ            uuid         not null default '00000000-0000-0000-0000-000000000000'::uuid,
  expanded       boolean      not null default true,
  constraint fk_parent_id foreign key (parent_id) 
    references tasks(id)
    on delete cascade 
    on update restrict,
  constraint id_no_cycle       check(id <> parent_id),
  --constraint check_dates       check (available_from <= due),
  constraint positive_estimate check (estimate > 0)
  --, constraint unique_task_order unique (parent_id, task_order)
);

create table task_info(
  id bigint primary key references tasks,
  title text not null,
  constraint title_non_empty check(length(title) > 0)
);

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
	with 
	original_task as (
	    select * from tasks t where t.id = task_id
	),
	calc_estimate as (
		select
			case
				when (select pt.task_type = 'ONE_OF'::task_type from tasks pt where pt.id = task_id limit 1)
				then coalesce(max(t.estimate), 0)::bigint
				else coalesce(sum(t.estimate), 0)::bigint
			end as res
		from tasks t 
		where t.parent_id = task_id
	),
	calc_progress as (
	  select 
	    case
		    when all_estimate.res <> 0
		    then ceil(done_estimate.res / all_estimate.res * 100)::bigint
		    else 100::bigint
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
			coalesce(max(t.due), (select t.due from original_task t)) as res 
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

create or replace function tasks_before_insert_trigger_function()
returns trigger 
as $$
declare
  max_task_order bigint;
begin
	if new.task_order is null then 
      select coalesce(max(task_order), 0) into max_task_order from tasks where parent_id = new.parent_id;
      new.task_order := max_task_order + 1;
    end if;
	if new.occ = '00000000-0000-0000-0000-000000000000'::uuid then
	  new.occ := gen_random_uuid();
	end if;
	return new;
end
$$ language plpgsql;
create or replace trigger tasks_before_insert_trigger before insert
  on tasks
  for each row
  execute procedure tasks_before_insert_trigger_function();

create or replace function tasks_after_insert_trigger_function()
returns trigger 
as $$
begin
	update tasks t 
	set 
		task_status = updated.st,
		estimate = updated.estimate,
		due = updated.duedate,
		progress = updated.progress,
		start_to = updated.start_to,
		occ = new.occ
	from (select * from t_recalc_task(new.parent_id)) as updated
    where t.id = updated.id and t.occ != new.occ;
	return new;
end
$$ language plpgsql;
create or replace trigger tasks_after_insert_trigger after insert
  on tasks
  for each row
  execute procedure tasks_after_insert_trigger_function();

create or replace function tasks_before_update_trigger_function()
returns trigger 
as $$
declare 
  descendant   record;
begin
	if old.occ = new.occ then
	  new.occ := gen_random_uuid();
	end if;
	if old.task_status = 'TODO'::"task_status" and new.task_status = 'DONE'::"task_status" then 
		new.progress := 100;
	end if;
	return new;
end
$$ language plpgsql;
create or replace trigger tasks_before_update_trigger before update
  on tasks
  for each row
  execute procedure tasks_before_update_trigger_function();

create or replace function tasks_after_update_trigger_function()
returns trigger 
as $$
declare 
  descendant   record;
begin	
--	raise warning 'call tasks_after_update_trigger_function (depth=%)', pg_trigger_depth();
--	raise warning 'old: %', old;
--	raise warning 'new: %', new;
--    raise warning '---';
   
    -- update old.parent_id
	update tasks t 
	set 
		task_status = updated.st,
		estimate = updated.estimate,
		due = updated.duedate,
		progress = updated.progress,
		start_to = updated.start_to,
		occ = new.occ
	from (select * from t_recalc_task(old.parent_id)) as updated
    where t.id = updated.id and t.occ != new.occ;
   
    -- update new.parent_id
   	update tasks t 
	set 
		task_status = updated.st,
		estimate = updated.estimate,
		due = updated.duedate,
		progress = updated.progress,
		start_to = updated.start_to,
		occ = new.occ
	from (select * from t_recalc_task(new.parent_id)) as updated
    where t.id = updated.id and t.occ != new.occ;
   
	for descendant in
		select * from tasks t where t.parent_id = new.id
	loop 
		update tasks 
		set 
		"task_status" = (case 
			when old.task_status = 'TODO'::"task_status" and new.task_status = 'DONE'::"task_status" 
			then 'DONE'::"task_status"
			when old.task_status = 'DONE'::"task_status" and new.task_status = 'TODO'::"task_status" 
			then 'TODO'::"task_status"
			else descendant.task_status
		end),
		progress = (case 
			when old.task_status = 'TODO'::"task_status" and new.task_status = 'DONE'::"task_status" 
			then 100
			when old.task_status = 'DONE'::"task_status" and new.task_status = 'TODO'::"task_status" 
			then 0
			else descendant.progress
		end),
		estimate = (case
			when old.estimate <> new.estimate 
			then new.estimate * descendant.estimate / (select coalesce(sum(t.estimate), 0) from tasks t where t.parent_id = new.id)
			else descendant.estimate
		end),
		due = (case 
			when old.due <> new.due 
			then descendant.due + (new.due - old.due)
			else descendant.due
		end),
		available_from = (case
			when (old.available_from <> new.available_from) and (descendant.available_from < new.available_from)
			then new.available_from
			else descendant.available_from
		end),
		occ = new.occ
		where id = descendant.id and descendant.occ != new.occ;
	end loop;
	return new;
end
$$ language plpgsql;
create or replace trigger tasks_after_update_trigger after update
  on tasks
  for each row
  execute procedure tasks_after_update_trigger_function();

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

-- Потомки
create or replace function t_descendants(root_id bigint)
returns table (id bigint) as $$
begin
  return query
  with recursive c as (
      select root_id as id
      union all
      select sa.id
      from tasks as sa
      join c ON c.id = sa.parent_id
  ) select * from c where c.id != root_id;
end;
$$ language plpgsql;

-- Потомки-листья
create or replace function t_descendant_leafs(root_id bigint)
returns table (id bigint) as $$
begin
  return query
    with recursive c as (
          select root_id as id, false as ex
          union all
          select sa.id, exists (select parent_id as id from tasks ttt where sa.id = parent_id)
          from tasks as sa
          join c ON c.id = sa.parent_id
    )
    select c.id from c where c.id != root_id and ex = false;
end;
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

--drop procedure insert_task(bigint, text);
create or replace procedure insert_task(parent bigint default 1, title text default 'Unnamed task', due timestamptz default now(), available_from timestamptz default now())
language plpgsql
as $$
declare
  max_task_order bigint;
  id_inserted bigint;
begin
  select coalesce(max(task_order), 0) into max_task_order from tasks where parent_id = parent;
  insert into tasks(parent_id, task_order, due, available_from) values (parent, max_task_order+1, due, available_from)
  returning id into id_inserted;
  insert into task_info(id, title) values(id_inserted, title);
  --call t_update_ancestors(id_inserted);
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

    -- update order
	update tasks t 
	set task_order = tmp.new_row_number
	from (select
	ROW_NUMBER () OVER (ORDER BY t.id) as new_row_number,
	t.*
	from tasks t where t.parent_id = task_parent_id order by t.task_order) as tmp
	where t.id = tmp.id;
end;
$$;

create or replace procedure reorder_task(task_id bigint, new_order bigint)
language plpgsql
as $$
declare 
  task           record;
  count_siblings bigint;
  range_from     bigint;
  range_to       bigint;
  sibling        record;
begin
	select * into task from tasks t where t.id = task_id; 
	select coalesce(count(*), 0) into count_siblings from tasks t where t.parent_id = task.parent_id;
	if task.task_order <> new_order and new_order >= 1 and new_order <= count_siblings then
		if new_order < task.task_order then
		  range_from := new_order;
		  range_to   := task.task_order - 1;
		else -- task.task_order < new_order 
		  range_from := task.task_order + 1;
		  range_to   := new_order;
		end if;
		update tasks t 
		set task_order = new_order
		where t.id = task_id;
	    for sibling in
	      select * 
	      from tasks t 
	      where 
	      	    t.id <> task_id 
	      	and t.parent_id = task.parent_id
	      	and t.task_order >= range_from
	      	and t.task_order <= range_to
	      order by t.task_order
	    loop
		  update tasks t 
		  set 
		  	task_order = (case 
			  when new_order < task.task_order 
			  then task_order + 1
			  -- task.task_order < new_order  
			  else task_order - 1 
			end),
			due = (case
			  when new_order < task.task_order
			  then due + (interval '1 minute' * estimate)
			  -- task.task_order < new_order
			  else due - (interval '1 minute' * estimate)
			end),
			available_from = (case
			  when new_order < task.task_order
			  then available_from + (interval '1 minute' * estimate)
			  -- task.task_order < new_order
			  else available_from - (interval '1 minute' * estimate)
			end),
			start_to = (case
			  when new_order < task.task_order
			  then start_to + (interval '1 minute' * estimate)
			  -- task.task_order < new_order
			  else start_to - (interval '1 minute' * estimate)
			end)
		  where t.id = sibling.id;
	    end loop;
	end if;
end;
$$;

create or replace function todo_list_internal(root_id bigint)
returns setof public.tasks
as $$
begin
  return query
	with recursive all_tasks as (
		select id, parent_id, expanded, array[expanded] as expanded_tasks, true as has_childs, 'SET'::"task_type" as task_type
		from tasks
		where id = root_id
		union all
		select c.id, c.parent_id, c.expanded, p.expanded_tasks||c.expanded, exists (select ttt.parent_id as id from tasks ttt where c.id = ttt.parent_id), c."task_type" 
		from tasks c
		join all_tasks p on (
			c.parent_id = p.id 
			and p.task_type != 'ONE_OF'::"task_type"
			and c."task_status" = 'TODO'::"task_status" 
		)
		where false <> all(p.expanded_tasks) 
	),
	not_ordered_tasks as (
		select id, parent_id, expanded, array[expanded] as expanded_tasks, true as has_childs, 'SET'::"task_type" as task_type
		from tasks
		where id = root_id
		union all
		select c.id, c.parent_id, c.expanded, p.expanded_tasks||c.expanded, exists (select ttt.parent_id as id from tasks ttt where c.id = ttt.parent_id), c."task_type" 
		from tasks c
		join all_tasks p on (
			c.parent_id = p.id 
			and p.task_type != 'ONE_OF'::"task_type"
			and c."task_status" = 'TODO'::"task_status" 
		)
		where false <> all(p.expanded_tasks) and c."task_type" != 'ORDERED'::"task_type" 
	),
	ordered_tasks as (
		select * from all_tasks 
		except all
		select * from not_ordered_tasks
	),
	first_descendants_of_ordered_childs as (
		select 
			distinct on (t.parent_id)
			t.*
		from all_tasks allt, tasks t
		where 
			allt.parent_id in (select id from ordered_tasks)
			and allt.id = t.id
		order by  t.parent_id, t.task_order asc
	),
	all_descendants_of_ordered_childs as (
		select
			t.*
		from all_tasks allt, tasks t
		where 
			allt.parent_id in (select id from ordered_tasks)
			and allt.id = t.id
		order by t.task_order asc
	),
	tail_descendants_of_ordered_childs as (
		select * from all_descendants_of_ordered_childs 
		except all
		select * from first_descendants_of_ordered_childs
	),
	res as (
		select id from all_tasks
		except all
		select id from tail_descendants_of_ordered_childs
	)
	select 
		--allt.*, 
		t.*
	from all_tasks allt, tasks t, res
	where 
		allt.id = t.id
		and t.id = res.id
		and t.id != root_id
		and ((allt.has_childs = true and t.expanded = false and allt.task_type != 'ONE_OF'::"task_type") 
		  or (allt.has_childs = false and allt.task_type != 'ONE_OF'::"task_type")
		  or  allt.task_type = 'ONE_OF'::"task_type");
end;
$$ language plpgsql;


create or replace function todo_list(root_id bigint)
returns table (
  id             bigint,
  parent_id      bigint,
  title          text,
  task_status    task_status,
  task_type      task_type,
  task_order     bigint,
  due            timestamptz,
  available_from timestamptz,
  start_to       timestamptz,
  progress       bigint,
  estimate       float8,
  occ            uuid,
  expanded       boolean
)
as $$
begin
  return query
  select 
    t.id, t.parent_id, ti.title, t.task_status, 
    t.task_type, t.task_order, t.due, t.available_from, 
    t.start_to, t.progress, t.estimate, t.occ, t.expanded
  from 
    todo_list_internal(1) as t, 
    task_info ti 
  where t.id = ti.id;
end;
$$ language plpgsql;
