-- Conteos basicos
select count(*) from cat_projects;
select count(*) from cat_activities;
select count(*) from cat_subcategories;
select count(*) from cat_purposes;
select count(*) from cat_topics;
select count(*) from rel_activity_topics;
select count(*) from cat_results;
select count(*) from cat_attendees;
select count(*) from catalog_version where is_current = true;

-- Huerfanos (deberia ser 0)
select count(*) from cat_subcategories s
left join cat_activities a on a.activity_id = s.activity_id
where a.activity_id is null;

select count(*) from cat_purposes p
left join cat_activities a on a.activity_id = p.activity_id
where a.activity_id is null;

select count(*) from cat_purposes p
left join cat_subcategories s on s.subcategory_id = p.subcategory_id
where p.subcategory_id is not null and s.subcategory_id is null;

select count(*) from rel_activity_topics r
left join cat_activities a on a.activity_id = r.activity_id
where a.activity_id is null;

select count(*) from rel_activity_topics r
left join cat_topics t on t.topic_id = r.topic_id
where t.topic_id is null;

-- Duplicados logicos (deberia ser 0)
select count(*) from (
	select activity_id, topic_id
	from rel_activity_topics
	group by activity_id, topic_id
	having count(*) > 1
) dup;

-- Subcategoria debe corresponder a la misma actividad
select count(*) from cat_purposes p
join cat_subcategories s on s.subcategory_id = p.subcategory_id
where p.subcategory_id is not null and p.activity_id <> s.activity_id;
