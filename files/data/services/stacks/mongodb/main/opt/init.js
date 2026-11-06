// Initiate rs set
const admin = db.getSiblingDB('admin');
try {
    admin.runCommand({ replSetGetStatus: 1 });
    print('Replica set is already initialized');
} catch (error) {
    if (error.code !== 94) throw error;

    const result = admin.runCommand({
        replSetInitiate: {
            _id: 'rs0',
            members: [
                {
                    _id: 0,
                    host: 'mongodb-main:27017',
                },
            ],
        },
    });

    if (result.ok !== 1) throw new Error(`Replica set initialization failed: ${JSON.stringify(result)}`);
    print('Initialized single-node replica set rs0');
}

const deadline = Date.now() + 60_000;
while (!admin.runCommand({ hello: 1 }).isWritablePrimary) {
    if (Date.now() >= deadline) throw new Error('Timed out waiting for replica set PRIMARY');
    sleep(500);
}

print('Single-node replica set is PRIMARY');

// auto upgrade fcv
const { versionArray } = admin.runCommand({ buildInfo: 1 });
if (versionArray[0] !== 9 || versionArray[1] !== 0) throw new Error('Automatic FCV upgrade requires MongoDB 9.0');
// MongoDB command names must be the first key; do not sort command documents.
const { featureCompatibilityVersion: fcv } = admin.runCommand({
    getParameter: 1,
    featureCompatibilityVersion: 1,
});

if (fcv.targetVersion || fcv.previousVersion) {
    throw new Error(`FCV transition is already in progress: ${JSON.stringify(fcv)}`);
}

if (fcv.version === '8.3') {
    const result = admin.runCommand({
        setFeatureCompatibilityVersion: '9.0',
        confirm: true,
    });

    if (result.ok !== 1) throw new Error(`FCV upgrade failed: ${JSON.stringify(result)}`);

    const { featureCompatibilityVersion: upgraded } = admin.runCommand({
        getParameter: 1,
        featureCompatibilityVersion: 1,
    });

    if (upgraded.version !== '9.0' || upgraded.targetVersion || upgraded.previousVersion) {
        throw new Error(`FCV upgrade did not complete: ${JSON.stringify(upgraded)}`);
    }

    print('Upgraded FCV from 8.3 to 9.0');
} else if (fcv.version === '9.0') {
    print('FCV is already 9.0');
} else {
    print(`Warning: Unsupported FCV for automatic upgrade; leaving it unchanged: ${JSON.stringify(fcv)}`);
}
