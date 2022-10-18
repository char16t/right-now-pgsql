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
