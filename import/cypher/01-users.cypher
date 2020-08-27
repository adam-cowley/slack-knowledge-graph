// Load users.cypher
CALL apoc.load.json("file:///slack/users.json")
YIELD value

// Map projections don't work on sub-properties so I've extracted `value.profile` into it's own variable
WITH value, value.profile AS profile

MERGE (u:User {id: value.id})

// Set basic information about the User
SET u += value {
    .color,
    .real_name,
    .name,
    .title
}

// Set Additional information from the profile
SET u += profile {
    .avatar_hash,
    .display_name,
    .display_name_normalized,
    .first_name,
    .image_1024,
    .image_192,
    .image_24,
    .image_32, .image_48, .image_512, .image_72,
    .image_original,
    .is_custom_image,
    .last_name,
    .phone,
    .real_name,
    .real_name_normalized,
    .skype,
    .status_emoji,
    .status_expiration,
    .status_text,
    .status_text_canonical,
    .title
}

// Foreach hack to assign labels for quick lookups
FOREACH (_ IN CASE WHEN value.is_owner THEN [1] ELSE [] END | SET u:Owner)
FOREACH (_ IN CASE WHEN value.is_primary_owner THEN [1] ELSE [] END | SET u:PrimaryOwner)
FOREACH (_ IN CASE WHEN value.is_restricted THEN [1] ELSE [] END | SET u:Restricted)
FOREACH (_ IN CASE WHEN value.is_ultra_restricted THEN [1] ELSE [] END | SET u:UltraRestricted)
FOREACH (_ IN CASE WHEN value.is_owner THEN [1] ELSE [] END | SET u:Owner)
FOREACH (_ IN CASE WHEN value.is_admin THEN [1] ELSE [] END | SET u:Admin)
FOREACH (_ IN CASE WHEN value.is_app_user THEN [1] ELSE [] END | SET u:AppUser)
FOREACH (_ IN CASE WHEN value.is_bot THEN [1] ELSE [] END | SET u:Bot)
FOREACH (_ IN CASE WHEN value.deleted THEN [1] ELSE [] END | SET u:Deleted)

// If team exists then merge the node + relationship
FOREACH (_ IN CASE WHEN value.team_id IS NOT NULL THEN [1] ELSE [] END |
    MERGE (t:Team {id: value.team_id})
    MERGE (u)-[:MEMBER_OF]->(t)
)

// If a timezone is listed
FOREACH (_ IN CASE WHEN value.tz IS NOT NULL THEN [1] ELSE [] END |
    MERGE (t:TimeZone {id: value.tz})
    ON CREATE SET t.offset = value.offset, t.label = value.tz_label
    MERGE (u)-[:IN_TIMEZONE]->(t)
);

