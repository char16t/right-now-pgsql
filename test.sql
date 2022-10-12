insert into tasks(parent_id, task_order, title) values (null, 1, 'Meta task');

call insert_task(parent := 1, title := 'AA');
call insert_task(parent := 2, title := 'AAA');
call insert_task(parent := 2, title := 'AAB');
call insert_task(parent := 2, title := 'AAC');
call insert_task(parent := 5, title := 'AACA');

call insert_task(parent := 1, title := 'AB');
call insert_task(parent := 1, title := 'AC');
call insert_task(parent := 1, title := 'AD');
call insert_task(parent := 1, title := 'AE');
call insert_task(parent := 1, title := 'AF');


update tasks t set "task_status" = 'DONE'::"task_status" where t.id = 2;
update tasks t set "task_status" = 'DONE'::"task_status" where t.id = 9;
--update tasks t set "task_status" = 'TODO'::"task_status" where t.id = 2;
call delete_task(task_id := 5);
select * from tasks;
select * from todo_list();
