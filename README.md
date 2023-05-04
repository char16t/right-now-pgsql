Pure PgSQL implementation of [Right Now Task Engine](https://github.com/char16t/right-now). It's too difficult for support and improvements, so I had to switch to Neo4J. Read the details of the problem and solutions here: https://github.com/char16t/right-now

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
