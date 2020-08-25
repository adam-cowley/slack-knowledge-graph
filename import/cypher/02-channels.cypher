// Load channel objects from channels.json
CALL apoc.load.json("file:///slack/channels.json") YIELD value

// Merge a Channel node by it's ID
MERGE (c:Channel {id: value.id})

// Use Map projection to extract interesting properties from `
SET c += value {
  .name,
  .is_archived,
  .is_general,
  createdAt: datetime({epochSeconds: value.created}),
  topic: value.topic.value,
  purpose: value.purpose.value
}

// Merge a relationship to the creator of the channel
MERGE (u:User {id: value.creator})
MERGE (u)-[:CREATED]->(c)

// Find users by their ID and merge a `MEMBER_OF` relationship
FOREACH (id IN value.members |
    MERGE (m:User {id: id})
    MERGE (m)-[:MEMBER_OF]->(c)
)
