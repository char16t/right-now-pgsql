Pure PgSQL implementation of [Right Now Task Engine](https://github.com/char16t/right-now). It's too difficult for support and improvements, so I had to switch to Neo4J. Read the details of the problem and solutions here: https://github.com/char16t/right-now


### Use with [PostgREST](https://postgrest.org)

Install:

1. Create database `tasks`
2. Execute `backend/schema.sql` in `tasks` database
3. Execute `backend/postgrest.sql` in `tasks` database

Run:

```
postgrest backend/postgrest.conf
```

Open:

```
http://localhost:3000/
```

```
http://localhost:3000/rpc/todo_list
```

### Use with PostgreSQL

```sql
insert into tasks(parent_id, task_order, title) values (null, 1, 'Meta task');

call insert_task(parent := 1, title := 'AA', available_from := '2022-02-02 00:00:00'::timestamp, due := '2022-02-03 00:00:00'::timestamp);
call insert_task(parent := 2, title := 'AAA');
call insert_task(parent := 2, title := 'AAB');
call insert_task(parent := 2, title := 'AAC');
call insert_task(parent := 5, title := 'AACA');

call insert_task(parent := 1, title := 'AB', available_from := '2022-02-04 00:00:00'::timestamp , due := '2022-02-05 00:00:00'::timestamp);
call insert_task(parent := 1, title := 'AC', available_from := '2022-02-06 00:00:00'::timestamp, due := '2022-02-07 00:00:00'::timestamp);
call insert_task(parent := 1, title := 'AD', available_from := '2022-02-08 00:00:00'::timestamp, due := '2022-02-09 00:00:00'::timestamp);
call insert_task(parent := 1, title := 'AE', available_from := '2022-02-10 00:00:00'::timestamp, due := '2022-02-11 00:00:00'::timestamp);
call insert_task(parent := 1, title := 'AF', available_from := '2022-02-12 00:00:00'::timestamp, due := '2022-02-13 00:00:00'::timestamp);

-- AD: 4 => 1
call reorder_task(task_id := 9, new_order := 1);

-- AA: 1 => 6
call reorder_task(task_id := 2, new_order := 5);

update tasks t set "task_status" = 'DONE'::"task_status" where t.id = 2;
update tasks t set "task_status" = 'DONE'::"task_status" where t.id = 9;
update tasks t set "task_status" = 'TODO'::"task_status" where t.id = 2;
call delete_task(task_id := 5);
select * from tasks;
select * from todo_list();
```
