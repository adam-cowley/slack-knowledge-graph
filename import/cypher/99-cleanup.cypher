MATCH (u:User)
DELETE u.phone, u.skype, u.real_name, u.first_name, u.last_name;

match (n) unwind keys(n) as k
with * where n[k] = ""
call apoc.create.removeProperties(n,[k]) yield node
return count(*);