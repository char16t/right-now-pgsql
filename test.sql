call insert_task(title := 'Make a init-sql in Spring Boot-1.4.1-RELEASE');
call insert_task(title := 'Configure port for a Spring Boot application');
call insert_task(title := 'Running code after Spring Boot starts');
call insert_task(title := 'Write result of a differentiation in terms of dependent variable');
call insert_task(title := 'Use of the subjunctive in a quod-clause in Renaissance Latin');
call insert_task(title := 'Finding duplicate blocks of text within a file using shell script');

call reorder_task(task_id := 5, new_order := 2);
call task_done(task_id := 2);

select * from todo_list();
