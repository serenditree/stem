import {Httpx} from 'https://jslib.k6.io/httpx/0.1.0/index.js';
import {check, fail, group, sleep} from 'k6';
import faker from 'k6/x/faker';
import {randomOption, randomSeed, randomUser, SeedFilter, ST_HEADERS, ST_SORTING} from './data.js';

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// INIT
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
const userClient = new Httpx({
    baseURL: `http://${__ENV.BRANCH_USER}/api/v1/user`,
    timeout: 4000
});

const seedClient = new Httpx({
    baseURL: `http://${__ENV.BRANCH_SEED}/api/v1/seed`,
    timeout: 2000
});

const pollClient = new Httpx({
    baseURL: `http://${__ENV.BRANCH_POLL}/api/v1/poll`,
    timeout: 2000
});

export const options = {
    stages: [
        {target: 10, duration: '30s'},
        {target: 50, duration: '1m'},
        {target: 10, duration: '30s'},
    ],
    thresholds: {
        http_req_failed: ['rate<0.001'],
        http_req_duration: ['p(99)<420']
    }
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UTILS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function assert(response, status) {
    if (response.status !== status) {
        console.error(status)
        console.error(response);
    }
    check(response, {'OK': r => r.status === status});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SETUP
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
export function setup() {
    const user = randomUser();
    const signUpResponse = userClient.post('/sign-up', null, user);

    if (signUpResponse.status !== 201) {
        fail('Setup failed');
    }

    const userId = signUpResponse.headers[ST_HEADERS.id];
    const username = user.headers[ST_HEADERS.username];
    const password = user.headers[ST_HEADERS.password];
    console.log(`Created user [${username}] with ID [${userId}] and password [${password}]`);

    return {
        authorization: signUpResponse.headers['Authorization'],
        userId: userId,
        username: username,
        password: password
    };
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TEST
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
export default function (data) {
    userClient.addHeader('Authorization', data.authorization);
    seedClient.addHeader('Authorization', data.authorization);
    pollClient.addHeader('Authorization', data.authorization);
    const groupTag = 'name';
    let tag;
    let seedId;
    let hasPoll;
    let pollId;
    let optionId;

    tag = '/seed/create';
    seedClient.addTag(groupTag, tag);
    group(tag, () => {
        const createSeedResponse = seedClient.post('/create', randomSeed());
        assert(createSeedResponse, 201);
        seedId = createSeedResponse.json('id');
        hasPoll = createSeedResponse.json('poll');
    });
    sleep(faker.numbers.float32Range(0, 1));

    tag = '/seed/{id}';
    seedClient.addTag(groupTag, tag);
    group(tag, () => {
        const seedGetResponse = seedClient.get(`/${seedId}`);
        assert(seedGetResponse, 200);
    });

    if (hasPoll) {
        tag = '/poll/seed/{id}';
        pollClient.addTag(groupTag, tag);
        group(tag, () => {
            const pollBySeedResponse = pollClient.get(`/seed/${seedId}`);
            assert(pollBySeedResponse, 200);
            const option = randomOption(pollBySeedResponse);
            pollId = pollBySeedResponse.json(`${option.poll}.id`);
            optionId = pollBySeedResponse.json(`${option.poll}.options.${option.option}.id`);
        });

        tag = '/poll/vote/{pollId}/{optionId}';
        pollClient.addTag(groupTag, tag);
        group(tag, () => {
            const voteResponse = pollClient.get(`/vote/${pollId}/${optionId}`);
            assert(voteResponse, 200);
        });
    }

    tag = '/seed/auth/{userId}/{entityId}/{action}';
    seedClient.addTag(groupTag, tag);
    group(tag, () => {
        const action = faker.strings.randomString(['water', 'nubit', 'prune']);
        const seedAuthResponse = seedClient.get(`/auth/${data.userId}/${seedId}/${action}`);
        assert(seedAuthResponse, 200);
    });

    tag = '/seed/retrieve';
    seedClient.addTag(groupTag, tag);
    group(tag, () => {
        const seedRetrieveByBoundsByWaterResponse = seedClient.post(
            '/retrieve',
            new SeedFilter()
                .setBounds()
                .setSort(ST_SORTING.water)
                .build()
        );
        assert(seedRetrieveByBoundsByWaterResponse, 200);
        const seedRetrieveByBoundsByDateResponse = seedClient.post(
            '/retrieve',
            new SeedFilter()
                .setBounds()
                .setSort(ST_SORTING.date)
                .build()
        );
        assert(seedRetrieveByBoundsByDateResponse, 200);
    });
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TEARDOWN
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
export function teardown(data) {
    userClient.addHeader('Authorization', data.authorization);
    const deleteResponse = userClient.delete(`/${data.userId}/true`);

    if (deleteResponse.status === 200) {
        console.log(`Removed all data for user [${data.username}] with ID [${data.userId}]`);
    } else {
        console.error(deleteResponse);
    }
}
