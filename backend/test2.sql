insert into tasks(id, parent_id, title, expanded) 
	values (1, null, 'A', true);

insert into tasks(id, parent_id, title, expanded, "task_type") 
	values (2, 1, 'AA', true, 'ORDERED');
insert into tasks(id, parent_id, title, expanded) 
	values (3, 2, 'AAA', true);
update tasks set "task_status" = 'DONE' where id = 3;
insert into tasks(id, parent_id, title, expanded) 
	values (4, 2, 'AAB', true);
insert into tasks(id, parent_id, title, expanded) 
	values (5, 2, 'AAC', true);

insert into tasks(id, parent_id, title, expanded) 
	values (6, 1, 'AB', false);
insert into tasks(id, parent_id, title, expanded) 
	values (7, 6, 'ABA', false);
insert into tasks(id, parent_id, title, expanded) 
	values (8, 6, 'ABB', false);
insert into tasks(id, parent_id, title, expanded) 
	values (9, 6, 'ABC', false);


insert into tasks(id, parent_id, title, expanded, "task_type") 
	values (10, 1, 'AC', true, 'ONE_OF');
insert into tasks(id, parent_id, title, expanded) 
	values (11, 10, 'ACA', false);
insert into tasks(id, parent_id, title, expanded) 
	values (12, 10, 'ACB', false);
insert into tasks(id, parent_id, title, expanded) 
	values (13, 10, 'ACC', false);
