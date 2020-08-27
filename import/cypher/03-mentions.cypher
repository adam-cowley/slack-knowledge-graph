

CALL apoc.periodic.iterate(
    "MATCH (n:MentionsUser) RETURN n",
    "
    REMOVE n:MentionsUser
    WITH n

    UNWIND apoc.text.regexGroups(n.text, '<@(\\\\w+)(>|\\\\|)') AS row

    MERGE (u:User {id: row[1]})
    MERGE (n)-[:MENTIONS_USER]->(u)
    ",
    {batchSize: 1000}
);


CALL apoc.periodic.iterate(
    "MATCH (n:MentionsChannel) RETURN n",
    "
        REMOVE n:MentionsChannel
        WITH n

        UNWIND apoc.text.regexGroups(n.text, '<#(\\\\w+)') AS row

        MERGE (c:Channel {id: row[1]})
        MERGE (n)-[:MENTIONS_CHANNEL]->(c)
    ",
    {batchSize: 1000}
);
