const fs = require('fs')
const neo4j = require('neo4j-driver')

const driver = new neo4j.driver('bolt://localhost:7687', neo4j.auth.basic('neo4j', 'neo'))
const session = driver.session()

const importDir = '/Users/adam/Library/Application Support/Neo4j Desktop/Application/neo4jDatabases/database-10dbcd9e-e408-4413-adbb-42dc7ad0460f/installation-4.1.1/import'
const path = `${importDir}/slack`

const cypher = `
    MATCH (c:Channel {name: $channel})
    CALL apoc.load.json('file://'+ $file) YIELD value
    WHERE value.user IS NOT NULL

    MERGE (u:User {id: value.user})

    MERGE (m:Message {id: value.ts})
    SET m += value {
        .type,
        .subtype,
        .text,
        createdAt: datetime({epochSeconds: toInteger(value.ts)})
    }
    MERGE (u)-[:POSTED]->(m)
    MERGE (m)-[:IN_CHANNEL]->(c)

    FOREACH (_ IN CASE WHEN value.edited IS NOT NULL THEN [1] ELSE [] END |
        MERGE (e:User {id: value.edited.user})
        MERGE (e)-[r:EDITED]->(m)
        SET r.ts = value.edited.ts,
            r.editedAt = toInteger(value.edited.ts)
    )

    FOREACH (_ IN CASE WHEN value.reactions IS NOT NULL THEN [1] ELSE [] END |
        FOREACH (reaction IN value.reactions |
            MERGE (e:Emoji {name: reaction.name})

            FOREACH (id IN reaction.users |
                MERGE (ru:User {id: id})
                MERGE (r:Reaction {id: value.ts+'--'+ reaction.name +'--'+ id})
                MERGE (ru)-[:REACTED]->(r)
                MERGE (r)-[:TO_MESSAGE]->(m)
                MERGE (r)-[:REACTION_TYPE]->(e)
            )
        )
    )

    FOREACH (_ IN CASE WHEN value.attachments IS NOT NULL THEN [1] ELSE [] END |
        FOREACH (attachment IN value.attachments |
            MERGE (a:Attachment {id: value.ts + '--'+ coalesce(attachment.id, 1)})
            SET a += attachment {
                .thumb_url,
                .thumb_width,
                .thumb_height,
                .title,
                .title_link,
                .text
                // TODO: Other info
            }

            MERGE (m)-[:HAS_ATTACHMENT]->(a)
        )
    )
`

const main = async () => {
    // Read directory to get a list of all directories in the path
    const files = fs.readdirSync(path)
        // Convert each channel name into a full path
        .map(channel => [ channel, `${path}/${channel}` ])
        // Filter the array so only directories are included
        .filter(([channel, path]) => fs.lstatSync(path).isDirectory())
        .map(([channel, path]) => {
            // Read directory to get the files for each day
            const files = fs.readdirSync(path)
                .map(file => `${path}/${file}`.replace(importDir, ''))

            return [channel, path, files]
        })
        // Run a reduction to produce an array of objects containing the channel and file location
        .reduce((acc, [channel, path, files]) => acc.concat(
            files.reduce((acc, file) => acc.concat({ channel, file }), [])
        ), [])


    // Get the total number to calculate the percentage
    const total = files.length

    // While there are items in the array, take the next item and execute the import cypher query
    while (files.length) {
        const next = files.splice(0, 1)[0]

        console.log(next, files.length, `${(100 - (files.length / total) * 100).toFixed(4)}%` );

        await session.run(cypher, next)
    }

    console.log('done');

    // Once all files have been processed, close the driver to exit the process
    await driver.close()
}


main()