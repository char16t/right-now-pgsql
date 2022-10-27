insert into tasks(id, parent_id, expanded) values (1, null, true);
insert into task_info(id, title) values (1, 'A');

insert into tasks(id, parent_id, expanded, "task_type") values (2, 1, true, 'ORDERED');
insert into task_info(id, title) values (2, 'AA');

insert into tasks(id, parent_id, expanded) values (3, 2, true);
insert into task_info(id, title) values (3, 'AAA');

update tasks set "task_status" = 'DONE' where id = 3;

insert into tasks(id, parent_id, expanded) values (4, 2, true);
insert into task_info(id, title) values (4, 'AAB');

insert into tasks(id, parent_id, expanded) values (5, 2, true);
insert into task_info(id, title) values (5, 'AAC');

insert into tasks(id, parent_id, expanded) values (6, 1, false);
insert into task_info(id, title) values (6, 'AB');

insert into tasks(id, parent_id, expanded) values (7, 6, false);
insert into task_info(id, title) values (7, 'ABA');

insert into tasks(id, parent_id, expanded) values (8, 6, false);
insert into task_info(id, title) values (8, 'ABB');

insert into tasks(id, parent_id, expanded) values (9, 6, false);
insert into task_info(id, title) values (9, 'ABC');

insert into tasks(id, parent_id, expanded, "task_type") values (10, 1, true, 'ONE_OF');
insert into task_info(id, title) values (10, 'AC');

insert into tasks(id, parent_id, expanded) values (11, 10, false);
insert into task_info(id, title) values (11, 'ACA');

insert into tasks(id, parent_id, expanded) values (12, 10, false);
insert into task_info(id, title) values (12, 'ACB');

insert into tasks(id, parent_id, expanded) values (13, 10, false);
insert into task_info(id, title) values (13, 'ACC');

select * from todo_list(1);
