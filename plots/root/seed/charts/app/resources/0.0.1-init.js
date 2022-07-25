////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// INDICES
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const locationIndex = [
    {
        location: "2dsphere",
    },
    {
        name: "LocationIndex"
    }
];

const textIndex = [
    {
        title: "text",
        text: "text",
        tags: "text",
        username: "text"
    },
    {
        weights: {
            tags: 4,
            title: 2,
        },
        name: "TextIndex"
    }
];

const genericSeedIndex = [
    {
        username: 1,
        parent: 1,
        localAlignment: 1,
        anonymous: 1,
        trail: 1,
        garden: 1,
        poll: 1,
        created: -1,
        modified: -1,
        "water.added": -1
    },
    {
        name: "GenericSeedIndex"
    }
]
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CREATE
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const results = [
    {
        name: `Seed.${locationIndex[1]['name']}`,
        result: db.Seed.createIndex(...locationIndex)
    },
    {
        name: `Seed.${textIndex[1]['name']}`,
        result: db.Seed.createIndex(...textIndex)
    },
    {
        name: `Seed.${genericSeedIndex[1]['name']}`,
        result: db.Seed.createIndex(...genericSeedIndex)
    },
    {
        name: `Garden.${locationIndex[1]['name']}`,
        result: db.Garden.createIndex(...locationIndex)
    },
    {
        name: `Garden.${textIndex[1]['name']}`,
        result: db.Garden.createIndex(...textIndex)
    },
    {
        name: `Garden.${genericSeedIndex[1]['name']}`,
        result: db.Garden.createIndex(...genericSeedIndex)
    }
];
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CHECK
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// const success = results.reduce(
//     (acc, curr) => acc && curr.result.ok === 1,
//     true
// );

printjson(results);
// print(`Success: ${success}`);
//
// success || quit(1);
