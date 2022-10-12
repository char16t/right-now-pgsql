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

call task_done(task_id := 2);
call delete_task(task_id := 5);

select * from todo_list();

select * from tasks;
