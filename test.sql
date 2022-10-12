call insert_task(parent := 1, title := 'AA');
call insert_task(parent := 1, title := 'AB');
call insert_task(parent := 1, title := 'AC');
call insert_task(parent := 1, title := 'AD');
call insert_task(parent := 1, title := 'AE');
call insert_task(parent := 1, title := 'AF');

call reorder_task(task_id := 5, new_order := 2);
call task_done(task_id := 2);

select * from todo_list();


-- Traverse tree
-- -------------

-- ESTIMATE(task_id=1)
select coalesce(sum(estimate), 0) from tasks where parent_id = 1;

-- STATUS(task_id=1)
with counts as (
    select t.task_status, count(*)
    from tasks t 
    where parent_id = 1
    group by t.task_status
),
sumall as (
  select sum(c.count) from counts c
)
select 
	case when sumall.sum = counts.count and sumall.sum != 0
	     then 'DONE'::"task_status"
	     else 'TODO'::"task_status" 
	end as "task_status"
from counts, sumall
where counts.task_status = 'DONE';

-- DUE(task_id=1)
select max(due) from tasks t where t.parent_id = 1;

-- ALL(task_id=1)
-- Update from leafs to root
with calc_estimate as (
	select coalesce(sum(estimate), 0) as res from tasks where parent_id = 1
),
calc_progress as (
  select 
    case
	    when all_estimate.res <> 0
	    then ceil(done_estimate.res / all_estimate.res * 100)
	    else 0
	end as res
  from 
    calc_estimate as all_estimate,
   (select coalesce(sum(estimate), 0) as res from tasks where parent_id = 1 and "task_status" = 'DONE') as done_estimate
),
count_statuses as (
	    select t.task_status, count(*)
	    from tasks t 
	    where parent_id = 1
	    group by t.task_status
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
	select max(due) as res from tasks t where t.parent_id = 1
),
calc_start_to as (
	select (calc_due.res - (interval '1 minute' * calc_estimate.res)) as res from calc_due, calc_estimate
)
select 
	1::bigint as id, 
	calc_status.res as task_status, 
	calc_estimate.res as estimate,
	calc_start_to.res as start_to, 
	calc_due.res as due,
	calc_progress.res as res
from 
	calc_status, 
	calc_estimate,
	calc_start_to,
	calc_due,
    calc_progress;

